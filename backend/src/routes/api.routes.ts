import { Router } from 'express';
import { run } from '@openai/agents';
import { z } from 'zod';
import OpenAI from 'openai';

import { orchestratorAgent } from '../agents/orchestrator.agent';
import { discoveryAgent } from '../agents/discovery.agent';
import { pricingAgent } from '../agents/pricing.agent';
import { bookingAgent } from '../agents/booking.agent';
import { feedbackAgent } from '../agents/feedback.agent';
import { disputeAgent } from '../agents/dispute.agent';

import { ChatOutputSchema } from '../agents/schemas';
import { sessionService } from '../services/session.service';
import { bookingStore } from '../store/booking.store';
import { applyProviderPenalty as applyPenaltyTool } from '../tools/provider.tools';

import { sendPushNotification, getProviderFcmToken, getClientFcmToken } from '../services/fcm.service';

import fs from 'fs';
import path from 'path';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const router = Router();

// ─── Helper: detect user message language ────────────────────────────────────
function detectMessageLanguage(text: string): 'english' | 'roman_urdu' | 'urdu' | 'roman_urdu_mixed' | 'urdu_mixed' {
  // Check for Arabic/Urdu Unicode block (U+0600–U+06FF)
  const hasUrduScript = /[؀-ۿ]/.test(text);

  // Roman Urdu grammar/function words — these only appear in Urdu, not English
  const romanUrduGrammar = /\b(mujhe|mujhy|mujhey|chahiye|chahiyay|chahte|hain|hun|hoon|tha|thi|the|kyun|kyunke|kahan|kab|kaise|aur|ya|bhi|sirf|abhi|kal|parso|subah|sham|dopahar|raat|phir|lekin|agar|jab|jahan|woh|yeh|inhe|unhe|mera|meri|apna|apni|bilkul|zaroor|shukriya|meherbani|achha|acha|theek|nahi|nahin|ko|se|ne|ka|ki|ke)\b/i;
  const hasRomanUrdu = romanUrduGrammar.test(text);

  // English-only function words (not used in Roman Urdu)
  const englishFunctionWords = /\b(i'm|i've|i'd|i'll|you're|we're|they're|the|a\b|an\b|is\b|are\b|was\b|were\b|have|has|had|would|should|could|my|your|our|their|this|that|please|hello|hey|thank|thanks|don't|can't|won't|doesn't|didn't|it's|there's|what's)\b/i;
  const hasEnglishFunctionWords = englishFunctionWords.test(text);

  // If any Urdu script present
  if (hasUrduScript) {
    return hasEnglishFunctionWords ? 'urdu_mixed' : 'urdu';
  }

  // Latin-only text
  const latinOnly = /^[a-zA-Z0-9\s.,?!'"()\-:/@#]+$/.test(text.trim());
  if (!latinOnly) return 'roman_urdu'; // contains other non-Latin script

  // Both Roman Urdu grammar AND English function words → mixed, default roman_urdu
  if (hasRomanUrdu) return 'roman_urdu';
  if (hasEnglishFunctionWords) return 'english';

  // Heuristic: short all-caps or numbers-heavy → likely English context (sector names like G-11)
  // Fall back to English if text has mostly English-looking word patterns
  const wordCount = text.trim().split(/\s+/).length;
  const englishLookingWords = text.match(/\b(need|want|book|hire|fix|repair|help|call|send|get|find|looking|looking for|available|available|asap|urgent|today|tomorrow|morning|evening|afternoon|night)\b/i);
  if (englishLookingWords && wordCount <= 10) return 'english';

  return 'roman_urdu'; // default for unrecognized Latin text
}

// ─── Helper: check if reply is already in the target language ────────────────
function isReplyInCorrectLanguage(reply: string, lang: string): boolean {
  const hasUrduScript = /[؀-ۿ]/.test(reply);
  // Roman Urdu markers in the reply
  const romanUrduMarkers = /\b(bilkul|zaroor|ji\b|haan|nahi|nahin|chahiye|zaroorat|hain|hun|kal|aaj|subah|sham|dopahar|aap\b|tum|hum|kya|kahan|kab|kaise|theek|acha|achha|shukriya|meherbani|mujhe|mein\b|ka\b|ki\b|ke\b|ko\b|se\b|ne\b)\b/i;
  const hasRomanUrdu = romanUrduMarkers.test(reply);

  if (lang === 'english') {
    // Correct if no Urdu script AND no Roman Urdu grammar markers
    return !hasUrduScript && !hasRomanUrdu;
  }
  if (lang === 'urdu') return hasUrduScript;
  // roman_urdu, roman_urdu_mixed, urdu_mixed — accept Latin replies (translation not attempted)
  return true;
}

// ─── Helper: translate reply to target language ───────────────────────────────
async function translateReply(reply: string, targetLang: string): Promise<string> {
  const instruction =
    targetLang === 'english'
      ? 'Translate the following text to natural, friendly English. Keep it concise. Output ONLY the translated text, nothing else.'
      : targetLang === 'urdu'
      ? 'اس متن کو اردو رسم الخط میں ترجمہ کریں۔ صرف ترجمہ لکھیں، کچھ اور نہیں۔'
      : null;

  if (!instruction) return reply;

  try {
    const resp = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: instruction },
        { role: 'user', content: reply },
      ],
      max_tokens: 200,
      temperature: 0.3,
    });
    return resp.choices[0]?.message?.content?.trim() || reply;
  } catch {
    return reply;
  }
}

// ─── Helper: convert agent ChatOutput → Flutter-compatible format ────────────
function toFlutterChatResponse(output: z.infer<typeof ChatOutputSchema>, rawMessage: string) {
  const nlu = {
    language_detected: output.language_detected,
    intent: output.status === 'complete' ? 'book_service' : output.status === 'off_topic' ? 'unclear' : 'book_service',
    confidence: output.confidence,
    user_emotion: output.user_emotion,
    raw_input: rawMessage,
    normalized: output.reply,
    requires_clarification: output.status !== 'complete',
    entities: {
      service_type: output.collected_info.service_type,
      location: {
        area: output.collected_info.area,
        city: output.collected_info.city || 'Islamabad',
        coordinates: null,
      },
      urgency: output.collected_info.urgency || 'medium',
      preferred_time: output.collected_info.datetime_iso
        ? { date: output.collected_info.datetime_iso.split('T')[0], slot: null, flexible: false, raw_text: null }
        : null,
      budget: { sensitivity: output.collected_info.budget_sensitive ? 'high' : 'medium', max_amount: null, raw_text: null },
      complexity_hints: [],
      additional_details: null,
      job_complexity: output.collected_info.job_complexity,
    },
  };

  const isComplete = output.status === 'complete';

  const intent = isComplete
    ? {
        status: 'complete',
        follow_up_needed: false,
        follow_up_question: null,
        confirmed_intent: {
          service_type: output.collected_info.service_type!,
          location: {
            area: output.collected_info.area!,
            city: output.collected_info.city || 'Islamabad',
          },
          datetime: output.collected_info.datetime_iso!,
          urgency: output.collected_info.urgency || 'medium',
          budget_sensitive: output.collected_info.budget_sensitive,
          job_complexity: output.collected_info.job_complexity || 'basic',
          confidence: output.confidence,
          language_detected: output.language_detected,
        },
      }
    : {
        status: 'incomplete',
        follow_up_needed: true,
        follow_up_question: output.reply,
        missing_fields: [],
        partial_intent: output.collected_info,
      };

  return { nlu, intent };
}

// ─── 1. CHAT (Orchestrator with Memory) ─────────────────────────────────────
router.post('/chat', async (req, res) => {
  try {
    const { message, session_id } = req.body;
    if (!message || !session_id) {
      return res.status(400).json({ error: 'message and session_id are required' });
    }

    const detectedLang = detectMessageLanguage(message);
    const langLabel: Record<string, string> = {
      english: 'ENGLISH',
      roman_urdu: 'ROMAN URDU',
      urdu: 'URDU SCRIPT',
      roman_urdu_mixed: 'ROMAN URDU MIXED',
      urdu_mixed: 'URDU MIXED',
    };
    const promptWithLang = `[LANGUAGE OF THIS USER MESSAGE: ${langLabel[detectedLang]} — REPLY IN ${langLabel[detectedLang]} ONLY]\n${message}`;

    const session = sessionService.getOrCreate(session_id);
    const result = await run(orchestratorAgent, promptWithLang, { session, maxTurns: 30 });
    const rawOutput = result.finalOutput as z.infer<typeof ChatOutputSchema>;

    // Build a mutable copy and override language with our reliable server-side detection
    let finalReply = rawOutput.reply;
    if (!isReplyInCorrectLanguage(finalReply, detectedLang)) {
      finalReply = await translateReply(finalReply, detectedLang);
    }

    const output: z.infer<typeof ChatOutputSchema> = {
      ...rawOutput,
      reply: finalReply,
      language_detected: detectedLang as z.infer<typeof ChatOutputSchema>['language_detected'],
    };

    const flutterResponse = toFlutterChatResponse(output, message);
    res.json(flutterResponse);
  } catch (error: any) {
    console.error('[/chat]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 2. DISCOVERY ────────────────────────────────────────────────────────────
router.post('/discovery', async (req, res) => {
  try {
    const { intent } = req.body;
    if (!intent) return res.status(400).json({ error: 'intent is required' });

    const prompt = `Find and rank the best available service providers for this confirmed booking request:

SERVICE TYPE: ${intent.service_type}
AREA: ${intent.location?.area}, ${intent.location?.city || 'Islamabad'}
URGENCY: ${intent.urgency || 'medium'}
JOB COMPLEXITY: ${intent.job_complexity || 'basic'}
BUDGET SENSITIVE: ${intent.budget_sensitive || false}
LANGUAGE: ${intent.language_detected || 'roman_urdu'}
DATE/TIME: ${intent.datetime || 'flexible'}

Use the search_providers tool to find providers, then rank them and return the top 3 with detailed reasoning.`;

    const result = await run(discoveryAgent, prompt, { maxTurns: 30 });
    res.json(result.finalOutput);
  } catch (error: any) {
    console.error('[/discovery]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 3. PRICING ──────────────────────────────────────────────────────────────
router.post('/pricing', async (req, res) => {
  try {
    const { provider, intent, is_returning_user } = req.body;

    const prompt = `Calculate the complete price quote for this service booking:

PROVIDER:
- Name: ${provider.name}
- Area: ${provider.area}
- Base Hourly Rate: Rs.${provider.hourly_rate}
- Experience: ${provider.experience_years} years
- NADRA Verified: ${provider.blue_tick}

BOOKING:
- Service: ${intent.service_type}
- Customer Area: ${intent.location?.area}
- Same area as provider: ${provider.area?.toLowerCase() === intent.location?.area?.toLowerCase()}
- Job Complexity: ${intent.job_complexity || 'basic'}
- Urgency: ${intent.urgency || 'medium'}
- Budget Sensitive: ${intent.budget_sensitive || false}
- Requested Time: ${intent.datetime}
- Returning Customer: ${is_returning_user || false}
- Language: ${intent.language_detected || 'roman_urdu'}

Call compute_price_components first, then format the complete price breakdown.`;

    const result = await run(pricingAgent, prompt, { maxTurns: 20 });
    res.json(result.finalOutput);
  } catch (error: any) {
    console.error('[/pricing]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 4. BOOKING ──────────────────────────────────────────────────────────────
router.post('/booking', async (req, res) => {
  try {
    const { provider, intent, pricing, all_ranked_providers, is_returning_user, client_session_id, mock_action } = req.body;

    const prompt = `Process this service booking request:

PROVIDER: ${JSON.stringify({
  id: provider.id,
  name: provider.name,
  area: provider.area,
  blue_tick: provider.blue_tick,
  hourly_rate: provider.hourly_rate,
  availability: provider.availability,
  ranking_reason: provider.ranking_reason,
})}

INTENT: ${JSON.stringify({
  service_type: intent.service_type,
  location: intent.location,
  datetime: intent.datetime,
  urgency: intent.urgency,
  language_detected: intent.language_detected,
})}

PRICING TOTAL: Rs.${pricing?.total || 0}

ALL RANKED PROVIDERS COUNT: ${(all_ranked_providers || []).length}
IS RETURNING USER: ${is_returning_user || false}
CLIENT SESSION ID: ${client_session_id || 'none'}
MOCK ACTION: ${mock_action || 'accept'}

${mock_action === 'decline' ? 'NOTE: The provider will decline this booking (mock_action=decline). Return status=provider_declined.' : ''}

Follow these steps:
1. Call check_booking_conflict for provider.id and intent.datetime
2. If no conflict: call create_booking and return pending status
3. If conflict: call find_next_free_slot and return conflict_waitlist status`;

    const result = await run(bookingAgent, prompt, { maxTurns: 20 });
    const bookingOutput = result.finalOutput as any;

    // Fire push notification to provider (fire-and-forget)
    if (bookingOutput.status === 'pending' && bookingOutput.provider_id) {
      const serviceLabel = (intent.service_type || '').replace(/_/g, ' ');
      const area = intent.location?.area || '';
      getProviderFcmToken(bookingOutput.provider_id).then(token => {
        if (token) {
          sendPushNotification({
            token,
            title: 'Nayi Booking Request!',
            body: `${serviceLabel} ki request aayi hai — ${area}. Accept ya decline karein.`,
            data: {
              type: 'new_booking',
              booking_id: bookingOutput.booking_id,
              provider_id: bookingOutput.provider_id,
              screen: 'provider_notification',
            },
          });
        }
      });

      if (client_session_id) {
        getClientFcmToken(client_session_id).then(token => {
          if (token) {
            sendPushNotification({
              token,
              title: 'Request Bheji Gayi',
              body: `${bookingOutput.provider_name} ko notification mili — jawab ka intezaar karein.`,
              data: { type: 'booking_pending', booking_id: bookingOutput.booking_id },
            });
          }
        });
      }
    }

    res.json(bookingOutput);
  } catch (error: any) {
    console.error('[/booking]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 5. FEEDBACK ─────────────────────────────────────────────────────────────
router.post('/feedback', async (req, res) => {
  try {
    const { provider, mock_action, feedback } = req.body;

    const prompt = `Process post-job feedback for this completed booking:

PROVIDER:
- ID: ${provider.id}
- Name: ${provider.name}
- Current Rating: ${provider.rating}/5
- Total Reviews: ${provider.total_reviews}
- On-Time Score: ${provider.on_time_score}%

OUTCOME: ${mock_action}
${feedback ? `CUSTOMER FEEDBACK:
- Stars: ${feedback.stars}/5
- Comment: ${feedback.comment || 'No comment'}` : 'No feedback provided (no_show case)'}

Process this feedback according to your instructions.`;

    const result = await run(feedbackAgent, prompt, { maxTurns: 20 });
    res.json(result.finalOutput);
  } catch (error: any) {
    console.error('[/feedback]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 6. DISPUTE ──────────────────────────────────────────────────────────────
router.post('/dispute', async (req, res) => {
  try {
    const {
      dispute_type,
      provider,
      original_price,
      overcharged_amount,
      extra_charge_amount,
      hours_before_job,
      language_detected,
    } = req.body;

    const prompt = `Resolve this customer dispute:

DISPUTE TYPE: ${dispute_type}

PROVIDER:
- ID: ${provider?.id}
- Name: ${provider?.name}
- Current Strikes: ${provider?.strikes || 0}

FINANCIAL DETAILS:
- Original Booking Price: Rs.${original_price || 0}
${dispute_type === 'price_disagreement' ? `- Amount Overcharged: Rs.${overcharged_amount || 0}` : ''}
${dispute_type === 'overrun' ? `- Extra Charge Requested: Rs.${extra_charge_amount || 0}` : ''}
${dispute_type === 'cancellation' ? `- Hours Before Job When Cancelled: ${hours_before_job || 0}` : ''}

LANGUAGE: ${language_detected || 'roman_urdu'}

Follow these steps:
1. Call get_dispute_policy for ${dispute_type}
2. Apply any required system actions (strike/penalty tools)
3. Calculate the exact refund amount
4. Write a clear, empathetic resolution in ${language_detected || 'Roman Urdu'}`;

    const result = await run(disputeAgent, prompt, { maxTurns: 20 });
    res.json(result.finalOutput);
  } catch (error: any) {
    console.error('[/dispute]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 7. REGISTER PROVIDER ────────────────────────────────────────────────────
router.post('/provider/register', async (req, res) => {
  try {
    const { name, service_types, area, hourly_rate, experience_years, nic, availability } = req.body;

    let blue_tick = false;
    let nadra_status = 'no_nic';
    if (nic) {
      const clean = nic.replace(/[-\s]/g, '');
      if (clean.length !== 13 || !/^\d+$/.test(clean)) {
        nadra_status = 'format_invalid';
      } else {
        blue_tick = parseInt(clean[12]) % 2 !== 0;
        nadra_status = blue_tick ? 'mock_verified' : 'mock_rejected';
      }
    }

    const newProvider = {
      id: 'PRV-' + Math.random().toString(36).substring(2, 10).toUpperCase(),
      name, area, service_types, hourly_rate, experience_years, blue_tick,
      rating: 0, total_reviews: 0, review_sentiment: 'unrated',
      on_time_score: 100, cancellation_rate: 0, capacity_today: 3,
      risk_score: 'low', strikes: 0, user_preference_score: 0,
      registered_at: new Date().toISOString(),
      availability: availability || {
        monday: ['09:00','11:00','14:00','16:00'],
        tuesday: ['09:00','11:00','14:00','16:00'],
        wednesday: ['09:00','11:00','14:00','16:00'],
        thursday: ['09:00','11:00','14:00','16:00'],
        friday: ['09:00','11:00','14:00'],
        saturday: ['10:00','12:00'],
        sunday: [],
      },
    };

    const dataPath = path.resolve(__dirname, '../../data/providers.json');
    const providers = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));
    providers.push(newProvider);
    fs.writeFileSync(dataPath, JSON.stringify(providers, null, 2));

    const messages: Record<string, string> = {
      mock_verified: `NIC verified! Blue tick mil gaya.`,
      mock_rejected: 'Yeh NIC number registered nahi hai. Blue tick nahi mila.',
      format_invalid: 'NIC format galat hai. Blue tick nahi mila.',
      no_nic: 'NIC nahi diya — Blue tick nahi mila.',
    };

    res.json({ status: 'success', provider: newProvider, nadra_status, message: messages[nadra_status] });
  } catch (error: any) {
    console.error('[/provider/register]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 8. PENDING BOOKINGS FOR PROVIDER ────────────────────────────────────────
router.get('/provider/:id/pending-bookings', (req, res) => {
  try {
    const pending = bookingStore.getPendingByProvider(req.params.id);
    res.json(pending);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ─── 9. PROVIDER RESPOND TO BOOKING ──────────────────────────────────────────
router.post('/booking/respond', async (req, res) => {
  try {
    const { booking_id, provider_id, action, reason, client_session_id } = req.body;

    const found = bookingStore.findById(booking_id);
    if (!found) return res.status(404).json({ error: 'Booking not found' });
    if (found.booking.status !== 'pending') {
      return res.status(400).json({ error: `Cannot respond — booking is ${found.booking.status}` });
    }

    if (action === 'accept') {
      bookingStore.updateStatus(booking_id, 'confirmed');
    } else {
      bookingStore.updateStatus(booking_id, 'provider_declined');
    }

    if (client_session_id) {
      getClientFcmToken(client_session_id).then(token => {
        if (!token) return;
        if (action === 'accept') {
          sendPushNotification({
            token,
            title: 'Booking Confirm Ho Gayi!',
            body: 'Provider ne aapki request accept kar li. Waqt par aa jayenge.',
            data: { type: 'booking_confirmed', booking_id, screen: 'booking_status' },
          });
        } else {
          sendPushNotification({
            token,
            title: 'Provider Busy Hai',
            body: `Wajah: ${reason || 'provider unavailable'}. Apke liye aur provider dhundha ja raha hai.`,
            data: { type: 'booking_declined', booking_id, screen: 'booking_status' },
          });
        }
      });
    }

    const result = { status: action === 'accept' ? 'success' : 'declined', booking_status: action === 'accept' ? 'confirmed' : 'provider_declined' };

    // Auto-reschedule on decline
    if (action === 'decline') {
      const allCandidates = found.booking.all_ranked_providers || [];
      const nextProvider = allCandidates.find((p: any) => p.id !== provider_id);
      if (nextProvider) {
        return res.json({ ...result, auto_rescheduled: true, next_provider: nextProvider });
      }
      return res.json({ ...result, auto_rescheduled: false });
    }

    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ─── 10. CANCEL AFTER ACCEPT ──────────────────────────────────────────────────
router.post('/booking/cancel-after-accept', async (req, res) => {
  try {
    const { booking_id } = req.body;
    const found = bookingStore.findById(booking_id);
    if (!found) return res.status(404).json({ error: 'Booking not found' });

    bookingStore.updateStatus(booking_id, 'cancelled_with_penalty');
    bookingStore.applyPenaltyToProvider(found.provider_id);

    const allCandidates = found.booking.all_ranked_providers || [];
    const nextProvider = allCandidates.find((p: any) => p.id !== found.provider_id) || null;

    res.json({ status: 'cancelled', next_provider: nextProvider });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ─── 11. APPLY PENALTY BY PROVIDER ID ────────────────────────────────────────
router.post('/providers/:id/apply-penalty', (req, res) => {
  try {
    bookingStore.applyPenaltyToProvider(req.params.id);
    res.json({ status: 'ok', message: `Penalty applied to ${req.params.id}` });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ─── 12. SAVE FCM TOKEN ───────────────────────────────────────────────────────
router.post('/fcm/save-token', async (req, res) => {
  try {
    const { token, role, id } = req.body;
    if (!token || !role || !id) return res.status(400).json({ error: 'token, role, id are required' });

    const admin = require('firebase-admin');
    if (admin.apps.length > 0) {
      const db = admin.firestore();
      await db.collection('fcm_tokens').doc(`${role}_${id}`).set({
        token, role, id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    res.json({ status: 'ok' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ─── 13. RATE PROVIDER ────────────────────────────────────────────────────────
router.post('/providers/:id/rate', async (req, res) => {
  try {
    const providerId = req.params.id;
    const { stars, review_text, client_name, booking_id } = req.body;

    if (!stars || stars < 1 || stars > 5) {
      return res.status(400).json({ error: 'stars must be 1-5' });
    }

    const dataPath = path.resolve(__dirname, '../../data/providers.json');
    const providers = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));
    const idx = providers.findIndex((p: any) => p.id === providerId);
    if (idx === -1) return res.status(404).json({ error: 'Provider not found' });

    const oldRating = providers[idx].rating || 0;
    const oldTotal = providers[idx].total_reviews || 0;
    const newTotal = oldTotal + 1;
    const newRating = Number(((oldRating * oldTotal + stars) / newTotal).toFixed(2));

    let sentiment = 'unrated';
    if (newRating >= 4.5) sentiment = 'positive';
    else if (newRating >= 3.5) sentiment = 'mostly_positive';
    else if (newRating >= 2.5) sentiment = 'mixed';
    else sentiment = 'negative';

    providers[idx].rating = newRating;
    providers[idx].total_reviews = newTotal;
    providers[idx].review_sentiment = sentiment;
    fs.writeFileSync(dataPath, JSON.stringify(providers, null, 2));

    res.json({
      status: 'success',
      provider_id: providerId,
      new_rating: newRating,
      total_reviews: newTotal,
      review_sentiment: sentiment,
      review: { booking_id, client_name: client_name || 'Anonymous', stars, review_text: review_text || '', created_at: new Date().toISOString() },
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ─── 14. GET BOOKED SLOTS ─────────────────────────────────────────────────────
router.get('/providers/:id/booked-slots', (req, res) => {
  try {
    res.json({ provider_id: req.params.id, booked_slots: bookingStore.getConfirmedDatetimes(req.params.id) });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ─── 15. TEST FCM NOTIFICATION ───────────────────────────────────────────────
router.post('/fcm/test', async (req, res) => {
  try {
    const { to, id, token: rawToken } = req.body as { to?: string; id?: string; token?: string };
    let token: string | null = rawToken || null;
    if (!token) {
      if (to === 'provider' && id) token = await getProviderFcmToken(id);
      else if (to === 'client' && id) token = await getClientFcmToken(id);
    }
    if (!token) return res.status(404).json({ error: 'Token nahi mila.' });

    const isProvider = to === 'provider';
    const ok = await sendPushNotification({
      token,
      title: isProvider ? 'Nai Booking Request!' : 'Booking Confirm Ho Gayi!',
      body: isProvider
        ? 'Ek client ne aapki service book ki hai — accept ya decline karein.'
        : 'Provider ne aapki request qubool kar li.',
      data: isProvider
        ? { type: 'new_booking', provider_id: id || 'test', booking_id: 'TEST-001' }
        : { type: 'booking_confirmed', booking_id: 'TEST-001' },
    });
    res.json({ success: ok, token_preview: token.substring(0, 30) + '...' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
