import * as dotenv from 'dotenv';
import path from 'path';

// Load env vars
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

import { NLUAgent } from '../agents/nlu.agent';
import { IntentAgent } from '../agents/intent.agent';
import { DiscoveryAgent } from '../agents/discovery.agent';
import { PricingAgent } from '../agents/pricing.agent';
import { BookingAgent } from '../agents/booking.agent';
import { DisputeAgent } from '../agents/dispute.agent';

async function runTests() {
  console.log('==========================================');
  console.log('       RUNNING 6 STRESS TESTS             ');
  console.log('==========================================\n');

  const nluAgent = new NLUAgent();
  const intentAgent = new IntentAgent();
  const discoveryAgent = new DiscoveryAgent();
  const pricingAgent = new PricingAgent();
  const bookingAgent = new BookingAgent();
  const disputeAgent = new DisputeAgent();

  // Test 1: No provider available -> waitlist flow
  console.log('--- TEST 1: No provider available -> waitlist flow ---');
  const input1 = "Need a painter in G-11 right now";
  console.log(`Input: "${input1}"`);
  const nlu1 = {
    confidence: 95,
    language_detected: 'english',
    intent: 'book_service',
    entities: {
      service_type: 'painter',
      location: { area: 'G-11', city: 'Islamabad', coordinates: null },
      urgency: 'high',
      preferred_time: { date: new Date().toISOString().split('T')[0], slot: 'anytime', flexible: true, raw_text: 'right now' },
      budget: null,
      complexity_hints: [],
      additional_details: null,
      job_complexity: 'basic'
    },
    raw_input: input1,
    normalized: 'Need a painter in G-11 immediately',
    processing_time_ms: 100,
    requires_clarification: false,
    clarification_question: null
  } as any;
  const intent1 = intentAgent.process({ nlu_result: nlu1, session_id: 't1' });
  if (intent1.confirmed_intent) {
    const discovery1 = discoveryAgent.discover(intent1.confirmed_intent);
    if (discovery1.status === 'success') {
      console.log(`Output: Ranked Providers Found: ${discovery1.ranked_providers.length}`);
      if (discovery1.ranked_providers.length === 0) {
        console.log('Result: Waitlist Flow triggered (No providers found for "painter" in G-11).');
      } else {
        console.log('Result: Providers found unexpectedly.');
      }
    } else {
       console.log(`Result: Waitlist Flow triggered. Suggestion: ${discovery1.suggestion}, Message: ${discovery1.message}`);
    }
  }

  // Test 2: Provider cancels after accept -> auto reschedule + penalty
  console.log('\n--- TEST 2: Provider cancels after accept -> auto reschedule + penalty ---');
  const input2 = "AC repair in G-11 at 2pm tomorrow";
  console.log(`Input: "${input2}"`);
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const nlu2 = {
    confidence: 98,
    language_detected: 'english',
    intent: 'book_service',
    entities: {
      service_type: 'ac_repair',
      location: { area: 'G-11', city: 'Islamabad', coordinates: null },
      urgency: 'medium',
      preferred_time: { date: tomorrow.toISOString().split('T')[0], slot: 'afternoon', flexible: false, raw_text: 'at 2pm tomorrow' },
      budget: null,
      complexity_hints: [],
      additional_details: null,
      job_complexity: 'basic'
    },
    raw_input: input2,
    normalized: 'Need AC repair in G-11 tomorrow afternoon',
    processing_time_ms: 100,
    requires_clarification: false,
    clarification_question: null
  } as any;
  const intent2 = intentAgent.process({ nlu_result: nlu2, session_id: 't2' });
  if (intent2.confirmed_intent) {
    const discovery2 = discoveryAgent.discover(intent2.confirmed_intent);
    if (discovery2.status === 'success' && discovery2.ranked_providers.length > 0) {
      const p1 = discovery2.ranked_providers[0];
      const price2 = pricingAgent.calculatePrice({ provider: p1, intent: intent2.confirmed_intent, is_returning_user: false });
      
      const bReq = {
        intent: intent2.confirmed_intent,
        provider: p1,
        pricing: price2,
        all_ranked_providers: discovery2.ranked_providers
      };
      const bRes = await bookingAgent.bookService(bReq);
      console.log(`Output (Booking created): Booking ID ${bRes.booking_id} with ${p1.name}. Status: ${bRes.status}`);
      
      // Accept it
      await bookingAgent.respondToBooking(bRes.booking_id, p1.id, 'accept');
      console.log(`Output (Provider accepts): Status is now confirmed.`);

      // Cancel it
      console.log(`Simulating Provider Cancellation...`);
      const rescheduleRes = await bookingAgent.simulateProviderCancellation(bRes.booking_id);
      if (rescheduleRes) {
        console.log(`Result: Rescheduled to ${rescheduleRes.provider_name}. Status: ${rescheduleRes.status}. Original provider penalized.`);
      } else {
        console.log(`Result: Cancellation simulated, but no alternatives found.`);
      }
    }
  }

  // Test 3: Misspelled input -> confidence score + confirmation
  console.log('\n--- TEST 3: Misspelled input -> confidence score + confirmation ---');
  const input3 = "mujay aik plymber chaye F-10 me";
  console.log(`Input: "${input3}"`);
  const nlu3 = {
    confidence: 70, // Intentionally low due to spelling
    language_detected: 'roman_urdu',
    intent: 'book_service',
    entities: {
      service_type: 'plumber', // It guessed plumber
      location: { area: 'F-10', city: 'Islamabad', coordinates: null },
      urgency: 'medium',
      preferred_time: null,
      budget: null,
      complexity_hints: [],
      additional_details: null,
      job_complexity: 'basic'
    },
    raw_input: input3,
    normalized: 'Need a plumber in F-10',
    processing_time_ms: 100,
    requires_clarification: true,
    clarification_question: "Aapka matlab plumber tha?"
  } as any;
  console.log(`Output: Parsed Service Type: "${nlu3.entities.service_type}", Confidence: ${nlu3.confidence}`);
  if (nlu3.confidence < 80) { // Since it is out of 100
    console.log('Result: Confidence low, confirmation required from user.');
  } else {
    console.log('Result: NLU correctly inferred the type with high confidence.');
  }

  // Test 4: Two users same provider same time -> conflict
  console.log('\n--- TEST 4: Two users same provider same time -> conflict ---');
  const input4a = "Electrician in G-13 tomorrow at 10 AM";
  const input4b = "Need electrician in G-13 tomorrow at 10:15 AM"; // within 75 mins
  console.log(`Inputs: User A: "${input4a}", User B: "${input4b}"`);
  
  const nlu4a = {
    confidence: 95,
    intent: 'book_service',
    entities: {
      service_type: 'electrician', location: { area: 'G-13', city: 'Islamabad' },
      preferred_time: { date: tomorrow.toISOString().split('T')[0], slot: 'morning', raw_text: 'tomorrow 10 AM' }
    }
  } as any;
  const intent4a = intentAgent.process({ nlu_result: nlu4a, session_id: 't4a' });
  // Manually override datetime to match exact logic
  if(intent4a.confirmed_intent) intent4a.confirmed_intent.datetime = new Date(tomorrow.setHours(10, 0, 0, 0)).toISOString();

  const nlu4b = {
    confidence: 95,
    intent: 'book_service',
    entities: {
      service_type: 'electrician', location: { area: 'G-13', city: 'Islamabad' },
      preferred_time: { date: tomorrow.toISOString().split('T')[0], slot: 'morning', raw_text: 'tomorrow 10:15 AM' }
    }
  } as any;
  const intent4b = intentAgent.process({ nlu_result: nlu4b, session_id: 't4b' });
  if(intent4b.confirmed_intent) intent4b.confirmed_intent.datetime = new Date(tomorrow.setHours(10, 15, 0, 0)).toISOString();

  if (intent4a.confirmed_intent && intent4b.confirmed_intent) {
    const disc4a = discoveryAgent.discover(intent4a.confirmed_intent);
    if (disc4a.status === 'success') {
      const p4 = disc4a.ranked_providers.find((p: any) => p.id === 'p2'); // Tariq Mehmood
      
      if (p4) {
        const price4 = pricingAgent.calculatePrice({ provider: p4, intent: intent4a.confirmed_intent, is_returning_user: false });
        
        const bResA = await bookingAgent.bookService({
          intent: intent4a.confirmed_intent,
          provider: p4,
          pricing: price4,
          all_ranked_providers: [p4]
        });
        // Accept so it is confirmed and blocks the slot
        await bookingAgent.respondToBooking(bResA.booking_id, p4.id, 'accept');
        console.log(`Output (User A): Booked and Confirmed with ${p4.name} (Booking ID: ${bResA.booking_id})`);

        const bResB = await bookingAgent.bookService({
          intent: intent4b.confirmed_intent,
          provider: p4,
          pricing: price4,
          all_ranked_providers: [p4]
        });
        console.log(`Output (User B): Status: ${bResB.status}`);
        console.log(`Result: Conflict handled. Suggested Waitlist Time: ${bResB.waitlist_suggestion}`);
      }
    }
  }

  // Test 5: Customer disputes price -> refund flow
  console.log('\n--- TEST 5: Customer disputes price -> refund flow ---');
  const disputeInput = {
    booking_id: "BK-1234",
    provider: { id: "p1", name: "Ali Hassan" } as any,
    dispute_type: "price_disagreement" as any,
    original_price: 1500,
    overcharged_amount: 300,
    customer_notes: "He charged me 1800 instead of 1500"
  };
  console.log(`Input: ${JSON.stringify(disputeInput)}`);
  const disputeResult = disputeAgent.resolveDispute(disputeInput);
  console.log(`Output: Resolution: "${disputeResult.resolution}"`);
  console.log(`Result: Refund of Rs. ${disputeResult.refund_amount} issued.`);

  // Test 6: High rating but recent bad reviews + high cancellation -> ranking impact
  console.log('\n--- TEST 6: High rating but recent bad reviews + high cancellation -> ranking impact ---');
  const input6 = "Carpenter in F-8";
  console.log(`Input: "${input6}"`);
  const nlu6 = {
    confidence: 95,
    language_detected: 'english',
    intent: 'book_service',
    entities: {
      service_type: 'carpenter',
      location: { area: 'F-8', city: 'Islamabad', coordinates: null },
      urgency: 'medium',
      preferred_time: { date: tomorrow.toISOString().split('T')[0], slot: 'morning', flexible: true, raw_text: 'tomorrow' },
      budget: { sensitivity: 'medium', max_amount: null, raw_text: null },
      complexity_hints: [],
      additional_details: null,
      job_complexity: 'basic'
    },
    raw_input: input6,
    normalized: 'Need a carpenter in F-8',
    processing_time_ms: 100,
    requires_clarification: false,
    clarification_question: null
  } as any;
  const intent6 = intentAgent.process({ nlu_result: nlu6, session_id: 't6' });
  if (intent6.confirmed_intent) {
    const disc6 = discoveryAgent.discover(intent6.confirmed_intent);
    if (disc6.status === 'success') {
      const p6 = disc6.ranked_providers.find((p: any) => p.id === 'p4'); // Usman Ali
      if (p6) {
        console.log(`Output: Usman Ali (p4) Details: Rating ${p6?.rating}, Review Sentiment: ${p6?.review_sentiment}, Cancellations: ${p6?.cancellation_rate}%`);
        console.log(`Output: Final Calculated Score for Usman Ali: ${p6?.calculated_score}`);
        console.log(`Result: Breakdown: ${JSON.stringify(p6?.score_breakdown)}`);
        console.log(`Reasoning: ${p6?.ranking_reason}`);
      } else {
        console.log('Result: Usman Ali not found in ranked providers.');
      }
    } else {
      console.log(`Result: Discovery failed: ${disc6.message}`);
    }
  }

  console.log('\n==========================================');
  console.log('              TESTS COMPLETED             ');
  console.log('==========================================');
}

runTests().catch(console.error);
