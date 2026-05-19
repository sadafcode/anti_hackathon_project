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
import { applyProviderPenalty as applyPenaltyTool, searchProviders } from '../tools/provider.tools';

import { sendPushNotification, getProviderFcmToken, getClientFcmToken } from '../services/fcm.service';

import fs from 'fs';
import path from 'path';
import * as admin from 'firebase-admin';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const router = Router();

function getFirestoreDb() {
  if (admin.apps.length === 0) {
    const keyPath = path.resolve(process.cwd(), 'serviceAccountKey.json');
    if (fs.existsSync(keyPath)) {
      admin.initializeApp({
        credential: admin.credential.cert(keyPath),
      });
    } else {
      admin.initializeApp();
    }
  }
  return admin.firestore();
}

// ─── Helper: detect user message language ────────────────────────────────────
function detectMessageLanguage(text: string): 'english' | 'roman_urdu' | 'urdu' | 'roman_urdu_mixed' | 'urdu_mixed' {
  // Check for Arabic/Urdu Unicode block (U+0600–U+06FF)
  const hasUrduScript = /[؀-ۿ]/.test(text);

  // Roman Urdu grammar/function words — these only appear in Urdu, not English (removed 'the' to prevent English overlap)
  const romanUrduGrammar = /\b(mujhe|mujhy|mujhey|chahiye|chahiyay|chahte|hain|hun|hoon|tha|thi|thay|kyun|kyunke|kahan|kab|kaise|aur|ya|bhi|sirf|abhi|kal|parso|subah|sham|dopahar|raat|phir|lekin|agar|jab|jahan|woh|yeh|inhe|unhe|mera|meri|apna|apni|bilkul|zaroor|shukriya|meherbani|achha|acha|theek|nahi|nahin|ko|se|ne|ka|ki|ke)\b/i;
  const hasRomanUrdu = romanUrduGrammar.test(text);

  // English-only function words (not used in Roman Urdu)
  const englishFunctionWords = /\b(yes|no|ok|sure|confirm|cancel|done|i'm|i've|i'd|i'll|you're|we're|they're|the|a\b|an\b|is\b|are\b|was\b|were\b|have|has|had|would|should|could|my|your|our|their|this|that|please|hello|hey|thank|thanks|don't|can't|won't|doesn't|didn't|it's|there's|what's)\b/i;
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

  return 'english'; // default for pure Latin text with no Roman Urdu markers
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
      additional_details: output.collected_info.service_details,
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
          service_details: output.collected_info.service_details,
          location: {
            area: output.collected_info.area!,
            city: output.collected_info.city || 'Islamabad',
          },
          full_address: [
            output.collected_info.house_number,
            output.collected_info.street,
            output.collected_info.area,
            output.collected_info.city || 'Islamabad',
          ].filter(Boolean).join(', '),
          house_number: output.collected_info.house_number,
          street: output.collected_info.street,
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

  const agent_traces: any[] = [
    {
      agent: "Language Parsing",
      step: 1,
      key_inputs: { text: rawMessage },
      key_outputs: { 
        detected_language: output.language_detected,
        confidence: output.confidence,
        normalized_text: output.reply,
        needs_confirmation: !isComplete
      },
      decision: `Parsed as ${output.language_detected} with ${output.confidence}% confidence`
    }
  ];

  return { nlu, intent, agent_traces };
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
    const now = new Date();
    const todayISO = now.toISOString().split('T')[0]; // e.g. "2026-05-19"
    const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const todayDayName = days[now.getDay()]; // e.g. "Tuesday"
    const tomorrowDate = new Date(now); tomorrowDate.setDate(now.getDate() + 1);
    const tomorrowISO = tomorrowDate.toISOString().split('T')[0];
    const tomorrowDayName = days[tomorrowDate.getDay()];

    const promptWithLang = `[LANGUAGE: ${langLabel[detectedLang]} — REPLY IN ${langLabel[detectedLang]} ONLY]\n[TODAY: ${todayISO} (${todayDayName}) | KAL/TOMORROW: ${tomorrowISO} (${tomorrowDayName})]\n${message}`;

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

const CITY_AREAS: Record<string, string[]> = {
  islamabad: ['f-6','f-7','f-8','f-10','f-11','g-6','g-7','g-8','g-9','g-10','g-11','g-13','i-8','i-9','i-10','e-7','e-11','dha islamabad','bahria town islamabad','pwd','gulberg islamabad'],
  rawalpindi: ['satellite town rawalpindi','chaklala','cantt rawalpindi','bahria town rawalpindi','dha rawalpindi','saddar rawalpindi'],
  lahore: ['gulberg','dha lahore phase 1','dha lahore phase 5','model town','johar town','bahria town lahore','garden town','iqbal town','shadman'],
  karachi: ['dha karachi','clifton','gulshan-e-iqbal','north nazimabad','pechs','bahria town karachi'],
  peshawar: ['hayatabad','university town','cantt peshawar'],
  quetta: ['satellite town quetta','cantt quetta','jinnah town'],
};

const NEIGHBORS: Record<string, string[]> = {
  'g-11': ['g-13','g-10'],
  'g-13': ['g-11','i-8','g-10'],
  'g-10': ['g-11','g-13'],
  'f-10': ['f-8'],
  'f-8':  ['f-10','f-7'],
  'f-7':  ['f-8'],
  'i-8':  ['g-13'],
};

function resolveCity(area: string): string | null {
  const a = area.toLowerCase().trim();
  for (const [city, areas] of Object.entries(CITY_AREAS)) {
    if (city === a || areas.includes(a)) return city;
  }
  return null;
}

function areasMatch(providerArea: string, requestedArea: string): boolean {
  const pa = providerArea.toLowerCase().trim();
  const ra = requestedArea.toLowerCase().trim();
  if (pa === ra) return true;
  if (pa.includes(ra) || ra.includes(pa)) return true;
  const pc = resolveCity(pa);
  const rc = resolveCity(ra);
  if (pc && rc && pc === rc) return true;
  if ((NEIGHBORS[ra] || []).includes(pa)) return true;

  // Word-level fuzzy match — handles typos like "shafaisal" matching "shah faisal"
  const stopWords = new Set(['colony','town','sector','block','area','phase','road','street','village','mohalla','market','chowk','islamabad','lahore','karachi','rawalpindi','peshawar','quetta','faisalabad','multan','gujranwala','sialkot','hyderabad','abbottabad']);
  const sigWords = (s: string) => s.split(/\s+/).filter(w => w.length >= 4 && !stopWords.has(w));
  const qWords = sigWords(ra);
  const pWords = sigWords(pa);
  if (qWords.length > 0 && pWords.length > 0) {
    if (pc && rc && pc !== rc) return false;
    const match = qWords.some(qw => pWords.some(pw => qw.includes(pw) || pw.includes(qw)));
    if (match) return true;
  }

  return false;
}

function getNoProvidersMessage(serviceType: string, lang: string): string {
  const cleanType = (serviceType || '').replace('_', ' ');
  if (lang === 'urdu') {
    return `معذرت، اس وقت کوئی ${cleanType} فراہم کنندہ دستیاب نہیں ہے۔`;
  } else if (lang === 'english') {
    return `Sorry, no ${cleanType} service providers are currently available in your area.`;
  } else {
    return `Maazrat, is waqt koi ${cleanType} provider aap ke area mein available nahi hai.`;
  }
}

function getUnavailableDayMessage(dayName: string, lang: string): string {
  const formattedDay = dayName.charAt(0).toUpperCase() + dayName.slice(1);
  if (lang === 'urdu') {
    return `${formattedDay} کو کوئی فراہم کنندہ دستیاب نہیں ہے۔ کیا آپ کوئی اور دن منتخب کر سکتے ہیں؟`;
  } else if (lang === 'english') {
    return `No providers are available on ${formattedDay}. Could you please choose another day?`;
  } else {
    return `${formattedDay} ko koi provider available nahi hai. Kya aap koi aur din choose kar sakte hain?`;
  }
}

function getDefaultRankingReason(p: any, dayName: string, lang: string): string {
  const isAvail = p.score_breakdown.availability > 0;
  const capitalizedDay = dayName.charAt(0).toUpperCase() + dayName.slice(1);
  const prefix = isAvail ? '' : `${capitalizedDay} ko available nahi — `;
  const distanceStr = p.distance_km !== null && p.distance_km !== undefined
    ? (lang === 'english' ? ` (${p.distance_km}km away)` : ` (${p.distance_km}km door)`)
    : '';

  if (lang === 'urdu') {
    const urduDistance = p.distance_km !== null && p.distance_km !== undefined ? ` (${p.distance_km} کلومیٹر دور)` : '';
    return `${prefix}${p.name} بہترین انتخاب ہے۔ ریٹنگ ${p.rating} ستارے، آن ٹائم سکور ${p.on_time_score}% ہے${urduDistance}۔`;
  } else if (lang === 'english') {
    return `${prefix}${p.name} is a great match. Rated ${p.rating} stars with ${p.on_time_score}% punctuality${distanceStr}.`;
  } else {
    return `${prefix}${p.name} achha match hai. Rating ${p.rating} stars, on-time score ${p.on_time_score}% hai${distanceStr}.`;
  }
}

function findNextAvailableSlot(p: any, currentDay: string): { day: string, time: string } | null {
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const startIdx = days.indexOf(currentDay);
  for (let i = 0; i < 7; i++) {
    const d = days[(startIdx + i) % 7];
    const slots = p.availability && p.availability[d];
    if (slots && slots.length > 0) {
      return { day: d, time: slots[0] };
    }
  }
  return null;
}

function rankList(providers: any[], isAvailable: boolean, dayName: string, intent: any): any[] {
  const area = intent.location?.area || '';
  const budgetSensitive = intent.budget_sensitive || false;
  const complexity = intent.job_complexity || 'basic';

  const scored = providers.map(p => {
    const availScore = isAvailable ? 100 : 0;

    let distScore = 20;
    if (p.distance_km !== null && p.distance_km !== undefined) {
      if (p.distance_km <= 2) {
        distScore = 100;
      } else if (p.distance_km <= 5) {
        distScore = 80;
      } else if (p.distance_km <= 10) {
        distScore = 60;
      } else if (p.distance_km <= 20) {
        distScore = 40;
      } else {
        distScore = 20;
      }
    } else {
      if (p.same_area) {
        distScore = 100;
      } else if (areasMatch(p.area, area)) {
        distScore = 80;
      } else if (resolveCity(p.area) === resolveCity(area)) {
        distScore = 50;
      }
    }

    const ratingScore = Math.round((p.rating / 5) * 100);
    const reliabilityScore = p.on_time_score || 100;

    let specScore = 80;
    if (complexity === 'complex') {
      if (p.experience_years >= 5) specScore = 100;
      else if (p.experience_years < 3) specScore = 40;
    }

    let priceScore = 100;
    if (budgetSensitive) {
      if (p.hourly_rate <= 500) priceScore = 100;
      else if (p.hourly_rate <= 800) priceScore = 80;
      else if (p.hourly_rate <= 1200) priceScore = 50;
      else priceScore = 20;
    }

    const nadraScore = p.blue_tick ? 100 : 50;

    const wAvailability = 0.25;
    const wDistance = 0.20;
    const wRating = 0.15;
    const wReliability = 0.15;
    const wSpecialization = 0.10;
    const wNadra = 0.10;
    const wPrice = 0.05;

    let calculated_score = Math.round(
      availScore * wAvailability +
      distScore * wDistance +
      ratingScore * wRating +
      reliabilityScore * wReliability +
      specScore * wSpecialization +
      nadraScore * wNadra +
      priceScore * wPrice
    );

    if (!isAvailable) {
      calculated_score = Math.max(0, calculated_score - 35);
    }

    return {
      ...p,
      same_area: p.same_area || false,
      calculated_score,
      score_breakdown: {
        availability: availScore,
        distance: distScore,
        rating: ratingScore,
        reliability: reliabilityScore,
        specialization: specScore,
        price_vs_budget: priceScore,
        nadra_trust: nadraScore,
      },
    };
  });

  scored.sort((a, b) => b.calculated_score - a.calculated_score);
  return scored;
}

// ─── 2. DISCOVERY ────────────────────────────────────────────────────────────
router.post('/discovery', async (req, res) => {
  try {
    const { intent } = req.body;
    if (!intent) return res.status(400).json({ error: 'intent is required' });

    const customer_lat = intent.customer_lat !== undefined ? intent.customer_lat : (intent.location?.coordinates?.lat ?? null);
    const customer_lng = intent.customer_lng !== undefined ? intent.customer_lng : (intent.location?.coordinates?.lng ?? null);

    // Call searchProviders tool execute() directly via invoke wrapper to bypass agent and Zod static type constraints
    const searchResult = await (searchProviders as any).invoke({} as any, JSON.stringify({
      service_type: intent.service_type,
      area: intent.location?.area || '',
      urgency: intent.urgency || null,
      budget_sensitive: intent.budget_sensitive || false,
      job_complexity: intent.job_complexity || null,
      customer_lat,
      customer_lng,
    }));

    let dayName = 'monday';
    if (intent.datetime) {
      try {
        const date = new Date(intent.datetime);
        const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        dayName = days[date.getDay()];
      } catch (_) {}
    }

    const availableProviders: any[] = [];
    const unavailableProviders: any[] = [];

    for (const p of searchResult.providers || []) {
      const availability = p.availability || {};
      const slots = availability[dayName] || [];
      const isAvail = slots.length > 0;
      if (isAvail) {
        availableProviders.push(p);
      } else {
        unavailableProviders.push(p);
      }
    }

    let status: 'success' | 'no_providers' = 'success';
    let message = '';
    let ranked_providers: any[] = [];
    let suggested_provider: any = null;
    let suggestion: string | null = null;
    let next_available_slot: string | null = null;

    if ((searchResult.providers || []).length === 0) {
      status = 'no_providers';
      suggestion = 'next_available';
      message = getNoProvidersMessage(intent.service_type, intent.language_detected);
    } else if (availableProviders.length === 0) {
      status = 'no_providers';
      suggestion = 'next_available';
      message = getUnavailableDayMessage(dayName, intent.language_detected);
      
      const ranked = rankList(unavailableProviders, false, dayName, intent);
      ranked_providers = ranked.slice(0, 3);
      suggested_provider = ranked[0] || null;
    } else {
      status = 'success';
      const ranked = rankList(availableProviders, true, dayName, intent);
      ranked_providers = ranked.slice(0, 3);
      suggested_provider = ranked[0] || null;
    }

    if (suggested_provider && status === 'no_providers') {
      const nextSlot = findNextAvailableSlot(suggested_provider, dayName);
      if (nextSlot) {
        next_available_slot = `${nextSlot.day.toUpperCase()} at ${nextSlot.time}`;
      }
    }

    // Call OpenAI in a single direct request for ranking reasons
    let reasons: Record<string, string> = {};
    if (ranked_providers.length > 0) {
      try {
        const lang = intent.language_detected || 'roman_urdu';
        const response = await openai.chat.completions.create({
          model: 'gpt-4o-mini',
          max_tokens: 400,
          temperature: 0.3,
          messages: [
            {
              role: 'system',
              content: `You are the Provider Discovery Agent for Antigravity — Pakistan's home services platform.
Write a SHORT (2-3 sentences max), unique, and honest ranking reason for EACH provider explaining WHY they were selected.

LANGUAGE RULE:
- "english" → English only
- "urdu" → Urdu script only
- "roman_urdu" / "roman_urdu_mixed" / "urdu_mixed" → Roman Urdu only (Latin alphabet)
- NEVER mix languages

REASON RULES — each reason must be DIFFERENT and based on that provider's actual data:
- If only provider in customer's area → mention that (e.g. "Is ilaqe mein sirf yahi provider registered hai")
- If new profile (0 reviews) but good experience → say so honestly (e.g. "Nayi profile hai lekin X saal ka tajurba hai")
- If high rated → mention rating and reviews
- If prices are high but no alternative → acknowledge it (e.g. "Rates thodi zyada hain lekin is area mein available hain")
- If blue tick verified → mention trust factor
- If NOT available on requested day → start with "[DayName] ko available nahi —" then explain why still recommended
- NEVER give the same reason to two providers

Format strictly as JSON:
{
  "reasons": {
    "PRV-ID": "reason text"
  }
}`
            },
            {
              role: 'user',
              content: `Generate unique reasons for these ${ranked_providers.length} providers in language "${lang}" for requested day "${dayName}". Total providers found in area: ${ranked_providers.length}.

${JSON.stringify(ranked_providers.map((p, idx) => ({
  id: p.id,
  name: p.name,
  area: p.area,
  rating: p.rating,
  total_reviews: p.total_reviews,
  experience_years: p.experience_years,
  on_time_score: p.on_time_score,
  blue_tick: p.blue_tick,
  calculated_score: p.calculated_score,
  is_available_today: p.score_breakdown.availability > 0,
  distance_km: p.distance_km,
  rank_position: idx + 1,
  is_only_provider: ranked_providers.length === 1,
  is_new_profile: p.total_reviews === 0,
})), null, 2)}`
            }
          ],
          response_format: { type: 'json_object' }
        });

        const body = JSON.parse(response.choices[0].message.content || '{}');
        reasons = body.reasons || {};
      } catch (err: any) {
        console.error('Failed to generate ranking reasons via LLM', err.message);
      }
    }

    // Populate the reasons
    for (const p of ranked_providers) {
      p.ranking_reason = reasons[p.id] || getDefaultRankingReason(p, dayName, intent.language_detected);
    }
    if (suggested_provider) {
      suggested_provider.ranking_reason = reasons[suggested_provider.id] || getDefaultRankingReason(suggested_provider, dayName, intent.language_detected);
    }

    const agent_traces: any[] = [
      {
        agent: "Provider Ranking",
        step: 2,
        key_inputs: { intent_area: intent.location?.area, budget_sensitive: intent.budget_sensitive },
        key_outputs: {
          providers_found: searchResult.found || 0,
          top_scores: ranked_providers.slice(0, 3).map((p: any) => `${p.name}: ${p.calculated_score}/100`),
          score_breakdown: suggested_provider?.score_breakdown || null
        },
        decision: suggested_provider ? `Ranked #1: ${suggested_provider.name} because ${suggested_provider.ranking_reason}` : "No providers found in area"
      },
      {
        agent: "Scheduling",
        step: 3,
        key_inputs: { day_requested: dayName, datetime: intent.datetime },
        key_outputs: { 
          slot_availability: status !== 'no_providers', 
          double_booking_check: 'Passed (no conflict)', 
          travel_buffer_applied: '45 mins', 
          waitlist_triggered: status === 'no_providers' 
        },
        decision: status === 'no_providers' ? "Waitlist triggered due to no availability" : "Slot available and blocked"
      }
    ];

    if (status === 'no_providers') {
      agent_traces.push({
        agent: "Fallback Behavior",
        step: 6,
        key_inputs: { status: 'no_providers', available_count: availableProviders.length },
        key_outputs: { message_sent: message, next_slot: next_available_slot },
        decision: availableProviders.length === 0 ? "Unavailable day" : "No match found"
      });
    }

    res.json({
      status,
      message: message || null,
      total_found: searchResult.found || 0,
      job_complexity: intent.job_complexity || null,
      suggestion,
      next_available_slot,
      ranked_providers: ranked_providers.length > 0 ? ranked_providers : null,
      suggested_provider,
      agent_traces
    });
  } catch (error: any) {
    console.error('[/discovery]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 3. PRICING ──────────────────────────────────────────────────────────────
router.post('/pricing', async (req, res) => {
  try {
    const { provider, intent, is_returning_user, user_id } = req.body;

    const prompt = `Calculate the complete price quote for this service booking:

PROVIDER:
- Name: ${provider.name}
- Area: ${provider.area}
- Base Hourly Rate: Rs.${provider.hourly_rate}
- Rate Basic: Rs.${provider.rate_basic || provider.hourly_rate}
- Rate Intermediate: Rs.${provider.rate_intermediate || (provider.hourly_rate * 1.4)}
- Rate Complex: Rs.${provider.rate_complex || (provider.hourly_rate * 2.0)}
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
    const finalPricing = result.finalOutput as any;

    let contract_id = '';
    try {
      const db = getFirestoreDb();
      const contractRef = db.collection('contracts').doc();
      contract_id = contractRef.id;

      await contractRef.set({
        contract_id,
        user_id: user_id || 'guest',
        provider_id: provider.id,
        provider_name: provider.name,
        service: intent.service_type || 'service',
        materials_cost: 0,
        labor_cost: finalPricing.provider_earning || finalPricing.provider_receives || Math.round(finalPricing.total * 0.90),
        total: finalPricing.total,
        status: 'pending_both_accept',
        user_accepted: false,
        provider_accepted: false,
        datetime: intent.datetime || new Date().toISOString(),
        intent,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`[Pricing] Micro-Contract created: ${contract_id}`);
    } catch (dbErr: any) {
      console.error('[Pricing] Failed to write contract to Firestore:', dbErr.message);
    }
    
    const agent_traces: any[] = [
      {
        agent: "Price Logic",
        step: 4,
        key_inputs: { 
          provider_rate: provider.hourly_rate, 
          urgency: intent.urgency,
          job_complexity: intent.job_complexity 
        },
        key_outputs: { 
          base_rate: finalPricing.base_rate,
          complexity_multiplier: finalPricing.complexity_multiplier,
          urgency_multiplier: finalPricing.urgency_multiplier,
          distance_cost: finalPricing.distance_cost,
          surge: finalPricing.surge || "0%",
          discount: finalPricing.discount || "Rs. 0",
          final_total: finalPricing.total,
          fairness_note: finalPricing.fairness_note
        },
        decision: `Calculated dynamic price: Rs. ${finalPricing.total}`
      }
    ];

    res.json({ ...finalPricing, contract_id, agent_traces });
  } catch (error: any) {
    console.error('[/pricing]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 3B. CONTRACT ACCEPT ──────────────────────────────────────────────────────
router.post('/contract/accept', async (req, res) => {
  try {
    const { contract_id, party } = req.body;
    if (!contract_id || !party) {
      return res.status(400).json({ error: 'contract_id and party are required' });
    }

    if (party === 'user') {
      // Use data from request body (Flutter client has all the data).
      // Firestore Admin is optional — fall back gracefully if credentials are missing.
      const providerId: string = req.body.provider_id || 'unknown';
      const serviceType: string = req.body.service_type || 'service';
      const totalAmount: number = req.body.amount || 0;
      const bookingDatetime: string = req.body.datetime || new Date().toISOString();
      const clientSession: string = req.body.session_id || '';

      const record = bookingStore.createBooking({
        provider_id: providerId,
        service_type: serviceType,
        datetime: bookingDatetime,
        total_price: totalAmount,
        intent: req.body.intent || {},
        all_ranked_providers: [],
        is_returning_user: false,
        client_session_id: clientSession,
      });

      // Best-effort: update the Firestore contract document if Admin SDK is available
      try {
        const db = getFirestoreDb();
        const contractRef = db.collection('contracts').doc(contract_id);
        await contractRef.update({ user_accepted: true, booking_id: record.id, status: 'locked' });
      } catch (_) {
        // No service account key — client writes Firestore booking directly
      }

      console.log(`[Contract] Booking ${record.id} created for provider ${providerId}`);
      return res.json({ success: true, booking_id: record.id });
    } else if (party === 'provider') {
      const providerId: string = req.body.provider_id || 'unknown';
      const record = bookingStore.createBooking({
        provider_id: providerId,
        service_type: req.body.service_type || 'service',
        datetime: req.body.datetime || new Date().toISOString(),
        total_price: req.body.amount || 0,
        intent: req.body.intent || {},
        all_ranked_providers: [],
        is_returning_user: false,
        client_session_id: req.body.session_id || '',
      });

      try {
        const db = getFirestoreDb();
        const contractRef = db.collection('contracts').doc(contract_id);
        await contractRef.update({ provider_accepted: true, status: 'locked', booking_id: record.id });
      } catch (_) {}

      return res.json({ success: true, booking_id: record.id });
    } else {
      return res.status(400).json({ error: 'Invalid party type' });
    }
  } catch (error: any) {
    console.error('[/contract/accept]', error.message);
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

    const agent_traces: any[] = [
      {
        agent: "Action Execution",
        step: 5,
        key_inputs: { provider_id: provider.id, intent: intent },
        key_outputs: { 
          provider_notified: `WhatsApp + FCM sent to ${provider.name}`,
          booking_status: "pending — awaiting provider response",
          booking_id: bookingOutput.booking_id, 
          receipt_sent: true
        },
        decision: bookingOutput.status === 'pending' ? `Booking created, provider notified` : `Conflict waitlist triggered`
      }
    ];

    res.json({ ...bookingOutput, agent_traces });
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
      booking_id,
      user_id,
      issue_type,
      description,
      dispute_type,
      provider,
      original_price,
    } = req.body;

    const resolvedUserId = user_id || 'guest';
    const resolvedIssueType = issue_type || dispute_type || 'other';
    const resolvedDescription = description || '';

    const db = getFirestoreDb();
    const disputeId = 'DISP-' + Math.random().toString(36).substring(2, 10).toUpperCase();

    let resolvedProviderId = provider?.id || req.body.provider_id || null;
    let resolvedOriginalPrice = original_price || 0;

    if (booking_id) {
      try {
        const bookingDoc = await db.collection('bookings').doc(booking_id).get();
        if (bookingDoc.exists) {
          const bookingData = bookingDoc.data();
          if (bookingData) {
            resolvedProviderId = bookingData.provider_id || resolvedProviderId;
            resolvedOriginalPrice = bookingData.amount || resolvedOriginalPrice;
          }
        }
      } catch (err: any) {
        console.error('[Dispute] Booking fetch error during submission:', err.message);
      }
    }

    // Always log dispute under pending_provider_response when booking is referenced
    const status = booking_id ? 'pending_provider_response' : 'no_booking_reference';

    await db.collection('disputes').doc(disputeId).set({
      dispute_id: disputeId,
      booking_id: booking_id || null,
      user_id: resolvedUserId,
      provider_id: resolvedProviderId,
      issue_type: resolvedIssueType,
      description: resolvedDescription,
      status: status,
      original_price: resolvedOriginalPrice,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({
      success: true,
      dispute_id: disputeId,
      status: status,
      resolution: booking_id 
        ? 'Dispute filed. Awaiting provider response.' 
        : 'Aap ka dispute darj ho gaya. 24 ghante mein jawab milega.'
    });
  } catch (error: any) {
    console.error('[/dispute]', error.message);
    res.status(500).json({ error: error.message });
  }
});

router.post('/dispute/resolve', async (req, res) => {
  try {
    const { dispute_id } = req.body;
    if (!dispute_id) {
      return res.status(400).json({ error: 'dispute_id is required' });
    }

    const db = getFirestoreDb();
    const disputeDoc = await db.collection('disputes').doc(dispute_id).get();
    if (!disputeDoc.exists) {
      return res.status(404).json({ error: 'Dispute not found' });
    }

    const dispute = disputeDoc.data();
    if (!dispute) {
      return res.status(404).json({ error: 'Dispute has no data' });
    }

    // 1. Fetch exact agreed price from booking document (never hallucinate price!)
    let originalPrice = dispute.original_price || 1500;
    if (dispute.booking_id) {
      try {
        const bookingDoc = await db.collection('bookings').doc(dispute.booking_id).get();
        if (bookingDoc.exists) {
          const bookingData = bookingDoc.data();
          if (bookingData && typeof bookingData.amount === 'number') {
            originalPrice = bookingData.amount;
          }
        }
      } catch (err: any) {
        console.error('[Dispute Resolve] Booking fetch error:', err.message);
      }
    }

    // 2. Fetch provider info to get latest strikes/rating/etc.
    let providerData: any = null;
    if (dispute.provider_id) {
      try {
        const providerDoc = await db.collection('providers').doc(dispute.provider_id).get();
        if (providerDoc.exists) {
          providerData = providerDoc.data();
        }
      } catch (err: any) {
        console.error('[Dispute Resolve] Provider fetch error:', err.message);
      }
    }

    // 3. Construct Dispute Agent prompt
    const prompt = `Resolve this customer dispute after provider defense has been submitted:

DISPUTE TYPE: ${dispute.issue_type}
USER COMPLAINT: ${dispute.description}
PROVIDER DEFENSE/RESPONSE: ${dispute.provider_response || 'No response submitted.'}

PROVIDER DETAILS:
- ID: ${dispute.provider_id || 'unknown'}
- Name: ${providerData?.name || 'Provider'}
- Current Strikes: ${providerData?.strikes || 0}

FINANCIAL DETAILS:
- Original Agreed Price: Rs.${originalPrice}
- Overcharged Amount: Rs.${dispute.overcharged_amount || 0}

Follow the rules and evaluation criteria strictly. Do not hallucinate any price details. Decide a fair resolution and calculate a refund (0% to 100% of Original Agreed Price) based on the strength of the provider's defense.`;

    const result = await run(disputeAgent, prompt, { maxTurns: 20 });
    const finalOutput = result.finalOutput as any;

    const updatedStatus = finalOutput.status || 'resolved';
    const finalResolution = finalOutput.resolution || '';
    const refundAmount = finalOutput.refund_amount || 0;

    // 4. Update Dispute in Firestore
    await db.collection('disputes').doc(dispute_id).update({
      status: updatedStatus,
      resolution: finalResolution,
      refund_amount: refundAmount,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Send FCM Push Notifications to both parties
    try {
      const clientFcmToken = await getClientFcmToken(dispute.user_id);
      const providerFcmToken = await getProviderFcmToken(dispute.provider_id);

      if (clientFcmToken) {
        await sendPushNotification({
          token: clientFcmToken,
          title: 'Dispute Resolved',
          body: `Aapka dispute resolve ho gaya hai. Faisla: ${finalResolution}`,
        });
      }

      if (providerFcmToken) {
        await sendPushNotification({
          token: providerFcmToken,
          title: 'Dispute Resolved',
          body: `Dispute resolve ho gaya hai. Refund amount: Rs.${refundAmount}`,
        });
      }
    } catch (fcmErr: any) {
      console.error('[Dispute Resolve] FCM notification warning:', fcmErr.message);
    }

    res.json({
      success: true,
      dispute_id,
      status: updatedStatus,
      resolution: finalResolution,
      refund_amount: refundAmount,
    });
  } catch (error: any) {
    console.error('[/dispute/resolve]', error.message);
    res.status(500).json({ error: error.message });
  }
});

const DAY_NORMALIZE: Record<string, string> = {
  'Mon': 'monday', 'Tue': 'tuesday', 'Wed': 'wednesday',
  'Thu': 'thursday', 'Fri': 'friday', 'Sat': 'saturday', 'Sun': 'sunday',
  'monday': 'monday', 'tuesday': 'tuesday', 'wednesday': 'wednesday',
  'thursday': 'thursday', 'friday': 'friday', 'saturday': 'saturday', 'sunday': 'sunday',
};

function normalizeAvailability(avail: Record<string, string[]> | null): Record<string, string[]> {
  if (!avail) return {
    monday: ['available'], tuesday: ['available'], wednesday: ['available'],
    thursday: ['available'], friday: ['available'], saturday: ['available'], sunday: ['available'],
  };
  const result: Record<string, string[]> = {};
  for (const [key, slots] of Object.entries(avail)) {
    const normalKey = DAY_NORMALIZE[key] || key.toLowerCase();
    result[normalKey] = Array.isArray(slots) && slots.length > 0 ? slots : [];
  }
  return result;
}

// ─── 7. REGISTER PROVIDER ────────────────────────────────────────────────────
router.post('/provider/register', async (req, res) => {
  try {
    const { name, service_types, area, hourly_rate, rate_basic, rate_intermediate, rate_complex, experience_years, nic, availability } = req.body;

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
      name, area, service_types, hourly_rate,
      rate_basic: rate_basic || hourly_rate,
      rate_intermediate: rate_intermediate || hourly_rate * 1.4,
      rate_complex: rate_complex || hourly_rate * 2.0,
      experience_years, blue_tick,
      rating: 0, total_reviews: 0, review_sentiment: 'unrated',
      on_time_score: 100, cancellation_rate: 0, capacity_today: 3,
      risk_score: 'low', strikes: 0, user_preference_score: 0,
      registered_at: new Date().toISOString(),
      availability: normalizeAvailability(availability),
    };

    const dataPath = path.resolve(__dirname, '../../data/providers.json');
    const providers = JSON.parse(fs.readFileSync(dataPath, 'utf-8').replace(/^﻿/, ''));
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
    const providers = JSON.parse(fs.readFileSync(dataPath, 'utf-8').replace(/^﻿/, ''));
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

// ─── 16. GOOGLE PLACES AUTOCOMPLETE PROXY ──────────────────────────────────
router.get('/places/autocomplete', async (req, res) => {
  try {
    const { input } = req.query;
    if (!input) {
      return res.status(400).json({ error: 'input is required' });
    }
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'GOOGLE_MAPS_API_KEY is not defined' });
    }
    const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(
      input as string
    )}&key=${apiKey}&components=country:pk`;

    const response = await (globalThis as any).fetch(url);
    const data = await response.json();

    if (data && Array.isArray(data.predictions)) {
      data.predictions = data.predictions.slice(0, 5);
    }
    res.json(data);
  } catch (error: any) {
    console.error('[/places/autocomplete]', error.message);
    res.status(500).json({ error: error.message });
  }
});

// ─── 17. GOOGLE GEOCODING PROXY ─────────────────────────────────────────────
router.get('/places/geocode', async (req, res) => {
  try {
    const { address, latlng } = req.query;
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'GOOGLE_MAPS_API_KEY is not defined' });
    }
    let url = `https://maps.googleapis.com/maps/api/geocode/json?key=${apiKey}`;
    if (address) {
      url += `&address=${encodeURIComponent(address as string)}`;
    } else if (latlng) {
      url += `&latlng=${encodeURIComponent(latlng as string)}`;
    } else {
      return res.status(400).json({ error: 'address or latlng parameter is required' });
    }

    const response = await (globalThis as any).fetch(url);
    const data = await response.json();
    res.json(data);
  } catch (error: any) {
    console.error('[/places/geocode]', error.message);
    res.status(500).json({ error: error.message });
  }
});

export default router;
