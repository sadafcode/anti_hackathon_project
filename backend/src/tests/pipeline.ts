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

async function runPipeline() {
  console.log('--- STARTING ORCHESTRATOR PIPELINE ---');

  // 1. NLU Agent
  console.log('\n[1] Running NLU Agent...');
  const nluAgent = new NLUAgent();
  const input = "AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai";
  const nluResult = await nluAgent.parse({ message: input });

  // 2. Intent Agent
  console.log('\n[2] Running Intent Agent...');
  const intentAgent = new IntentAgent();
  const intentState = intentAgent.process({ nlu_result: nluResult, session_id: 'test-session-1' });

  if (intentState.status === 'incomplete') {
    console.log('Intent incomplete! Clarification needed:', intentState.follow_up_question);
    return;
  }

  // 3. Discovery Agent (Ranking)
  console.log('\n[3] Running Discovery & Ranking Agent...');
  const discoveryAgent = new DiscoveryAgent();
  const discoveryResult = await discoveryAgent.discover(intentState.confirmed_intent!);
  const rankedProviders = discoveryResult.status === 'success' ? discoveryResult.ranked_providers : [];

  console.log('\n--- RANKING RESULTS ---');
  for (const p of rankedProviders) {
    console.log(`\nProvider: ${p.name} (Area: ${p.area})`);
    console.log(`Final Score: ${p.calculated_score} / 100`);
    console.log('Ranking Factors Breakdown:', JSON.stringify(p.score_breakdown, null, 2));
    console.log('Reasoning:', p.ranking_reason);
  }

  if (rankedProviders.length === 0) {
    console.log('No providers found!');
    return;
  }

  const topProvider = rankedProviders[0];

  // 4. Pricing Agent
  console.log('\n[4] Running Pricing Agent...');
  const pricingAgent = new PricingAgent();
  const pricingResult = await pricingAgent.calculatePrice({
    provider: topProvider,
    intent: intentState.confirmed_intent!,
    is_returning_user: false
  });

  // 5. Booking Agent
  console.log('\n[5] Running Booking Agent...');
  const bookingAgent = new BookingAgent();
  const bookingResult = await bookingAgent.bookService({
    intent: intentState.confirmed_intent!,
    provider: topProvider,
    pricing: pricingResult,
    mock_action: 'accept',
    all_ranked_providers: rankedProviders
  });

  console.log('\n--- FINAL BOOKING RECEIPT ---');
  console.log(JSON.stringify(bookingResult, null, 2));
}

runPipeline().catch(console.error);
