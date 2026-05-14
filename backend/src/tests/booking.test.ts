import fs from 'fs';
import path from 'path';
import { BookingAgent } from '../agents/booking.agent';
import { PricingAgent } from '../agents/pricing.agent';
import { ConfirmedIntent } from '../models/intent.model';
import { RankedProvider } from '../models/discovery.model';

// Utility to read current provider state for verifying penalty
function getProvider(id: string): RankedProvider {
  const dataPath = path.resolve(__dirname, '../../data/providers.json');
  const providers = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));
  return providers.find((p: any) => p.id === id);
}

function createMockRankedProvider(id: string, name: string, hourly_rate: number): RankedProvider {
  return {
    id, name, service_types: [], area: 'G-13', capacity_today: 1, risk_score: 'low',
    strikes: 0, rating: 4.5, on_time_score: 90, experience_years: 5, total_reviews: 100,
    review_sentiment: 'positive', hourly_rate, cancellation_rate: 0, user_preference_score: 0,
    blue_tick: true, calculated_score: 100, score_breakdown: {} as any, ranking_reason: ''
  };
}

const agent = new BookingAgent();
const pricingAgent = new PricingAgent();

async function runTests() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║               BOOKING & SCHEDULING AGENT TESTS               ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  // Basic Setup
  const intent1: ConfirmedIntent = {
    service_type: 'plumber', location: { area: 'F-10', city: 'Islamabad' },
    datetime: '2026-05-15T10:00:00', urgency: 'medium', budget_sensitive: false,
    job_complexity: 'basic', confidence: 95, language_detected: 'english'
  };
  const provider1 = getProvider('p3'); // Bilal Ahmed
  const pricing1 = pricingAgent.calculatePrice({ provider: provider1, intent: intent1, is_returning_user: false });

  // ─────────────────────────────────────────────────────────────────
  console.log('─── Flow 1: Normal Booking (Accept) ───');
  const res1 = await agent.bookService({
    intent: intent1,
    provider: provider1,
    pricing: pricing1,
    mock_action: 'accept',
    is_returning_user: false
  });
  console.log(JSON.stringify(res1, null, 2));

  // ─────────────────────────────────────────────────────────────────
  console.log('\n─── Flow 2: Conflict (Double Booking) ───');
  const intent2: ConfirmedIntent = { ...intent1, datetime: '2026-05-15T11:00:00' }; // 60 mins later, within 75 min buffer
  const pricing2 = pricingAgent.calculatePrice({ provider: provider1, intent: intent2, is_returning_user: false });
  const res2 = await agent.bookService({
    intent: intent2,
    provider: provider1,
    pricing: pricing2,
    mock_action: 'accept',
    is_returning_user: false
  });
  console.log(JSON.stringify(res2, null, 2));

  // ─────────────────────────────────────────────────────────────────
  console.log('\n─── Flow 3: Accept-Then-Reject Penalty ───');
  const intent3: ConfirmedIntent = { ...intent1, datetime: '2026-05-16T12:00:00', service_type: 'carpenter' };
  const provider4 = getProvider('p4'); // Usman Ali
  const fallbackProvider = getProvider('p5'); // Sana Malik
  
  // Save initial stats to compare later
  const initUsman = getProvider('p4');

  const pricing3 = pricingAgent.calculatePrice({ provider: provider4, intent: intent3, is_returning_user: false });
  
  // 1. Initial Accept
  const res3 = await agent.bookService({
    intent: intent3,
    provider: provider4,
    pricing: pricing3,
    mock_action: 'accept-then-reject',
    is_returning_user: false,
    all_ranked_providers: [provider4, fallbackProvider]
  });
  console.log(JSON.stringify(res3, null, 2));

  // 2. Simulate Cancellation
  const autoRescheduleRes = await agent.simulateProviderCancellation(res3.booking_id);
  
  console.log('\n✅ Auto-rescheduled Receipt:');
  console.log(JSON.stringify(autoRescheduleRes, null, 2));

  // 3. Verify Penalty Applied to JSON
  const updatedUsman = getProvider('p4');
  console.log(`\nVerification Check for ${updatedUsman.name}:`);
  console.log(`Cancellation Rate: ${initUsman.cancellation_rate} ➔ ${updatedUsman.cancellation_rate}`);
  console.log(`Reliability Score: ${initUsman.reliability_score} ➔ ${updatedUsman.reliability_score}`);

  if (
    updatedUsman.cancellation_rate === initUsman.cancellation_rate + 1 &&
    updatedUsman.reliability_score === initUsman.reliability_score - 10
  ) {
    console.log('✅ Penalty accurately applied to providers.json!');
  } else {
    console.log('❌ Penalty mismatch!');
  }

  console.log('\nAll Booking Tests completed.');
}

runTests().catch(console.error);
