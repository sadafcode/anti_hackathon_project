import { PricingAgent } from '../agents/pricing.agent';
import { ConfirmedIntent } from '../models/intent.model';
import { RankedProvider } from '../models/discovery.model';

const agent = new PricingAgent();

function createIntent(
  service_type: any,
  area: string,
  datetime: string,
  urgency: any,
  job_complexity: any,
  budget_sensitive: boolean
): ConfirmedIntent {
  return {
    service_type,
    location: { area, city: 'Islamabad' },
    datetime,
    urgency,
    budget_sensitive,
    job_complexity,
    confidence: 95,
    language_detected: 'english'
  };
}

function createProvider(name: string, area: string, hourly_rate: number): RankedProvider {
  return {
    id: 'pX',
    name,
    service_types: [],
    area,
    capacity_today: 1,
    risk_score: 'low',
    strikes: 0,
    rating: 4.5,
    on_time_score: 90,
    experience_years: 5,
    total_reviews: 100,
    review_sentiment: 'positive',
    hourly_rate,
    cancellation_rate: 0,
    user_preference_score: 0,
    blue_tick: true,
    calculated_score: 100,
    score_breakdown: {} as any,
    ranking_reason: ''
  };
}

async function runTests() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║               DYNAMIC PRICING AGENT TESTS                    ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  // Scenario 1: Budget Sensitive
  console.log('─── Scenario 1: Budget Sensitive ───');
  const res1 = agent.calculatePrice({
    provider: createProvider('Bilal Ahmed', 'F-10', 700),
    intent: createIntent('plumber', 'F-10', '2026-05-15T09:00:00', 'high', 'intermediate', true),
    is_returning_user: false
  });
  console.log(JSON.stringify(res1, null, 2));

  // Scenario 2: Emergency + Surge
  console.log('\n─── Scenario 2: Emergency + Surge ───');
  const res2 = agent.calculatePrice({
    provider: createProvider('Usman Ali', 'F-8', 500),
    intent: createIntent('carpenter', 'F-8', '2026-05-15T19:00:00', 'emergency', 'basic', false),
    is_returning_user: true
  });
  console.log(JSON.stringify(res2, null, 2));

  // Scenario 3: Complex Job (with Distance Cost)
  console.log('\n─── Scenario 3: Complex Job ───');
  const res3 = agent.calculatePrice({
    provider: createProvider('Ali Hassan', 'G-11', 800),
    intent: createIntent('ac_repair', 'G-13', '2026-05-15T11:00:00', 'low', 'complex', false),
    is_returning_user: false
  });
  console.log(JSON.stringify(res3, null, 2));

  console.log('\n✅ All pricing tests executed.');
}

runTests().catch(console.error);
