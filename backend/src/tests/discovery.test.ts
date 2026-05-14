import { DiscoveryAgent } from '../agents/discovery.agent';
import { ConfirmedIntent } from '../models/intent.model';

const agent = new DiscoveryAgent();

function createIntent(service_type: any, area: string): ConfirmedIntent {
  return {
    service_type,
    location: { area, city: 'Islamabad' },
    datetime: '2026-05-15T09:00:00',
    urgency: 'high',
    budget_sensitive: true,
    job_complexity: 'intermediate',
    confidence: 90,
    language_detected: 'roman_urdu'
  };
}

async function runTests() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║         DISCOVERY & RANKING AGENT TEST SUITE               ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  let passed = 0;
  let failed = 0;

  // TEST 1
  console.log('─── Test 1: service=ac_repair, area=G-13 ───');
  const res1 = agent.discover(createIntent('ac_repair', 'G-13'));
  console.log(JSON.stringify(res1, null, 2));
  if (res1.status === 'success' && res1.ranked_providers[0].name === 'Ali Hassan') {
    console.log('  ✅ PASSED');
    passed++;
  } else {
    console.log('  ❌ FAILED');
    failed++;
  }

  // TEST 2
  console.log('\n─── Test 2: service=plumber, area=G-13 ───');
  const res2 = agent.discover(createIntent('plumber', 'G-13'));
  console.log(JSON.stringify(res2, null, 2));
  if (res2.status === 'success' && (res2.ranked_providers[0].name === 'Bilal Ahmed' || res2.ranked_providers[0].name === 'Aslam Khan')) {
    console.log('  ✅ PASSED');
    passed++;
  } else {
    console.log('  ❌ FAILED');
    failed++;
  }

  // TEST 3
  console.log('\n─── Test 3: service=ac_repair, area=F-10 (Zero direct matches) ───');
  const res3 = agent.discover(createIntent('ac_repair', 'F-10'));
  console.log(JSON.stringify(res3, null, 2));
  if (res3.status === 'success' && res3.ranked_providers.length > 0) {
    console.log('  ✅ PASSED');
    passed++;
  } else if (res3.status === 'no_providers') {
    console.log('  ✅ PASSED (Fallback)');
    passed++;
  } else {
    console.log('  ❌ FAILED');
    failed++;
  }

  console.log('\n\n╔══════════════════════════════════════════════════════════════╗');
  console.log(`║  RESULTS: ${passed} passed, ${failed} failed, 3 total`);
  console.log('╚══════════════════════════════════════════════════════════════╝');
}

runTests().catch(console.error);
