import { IntentAgent } from '../agents/intent.agent';
import { NLUResult } from '../models/nlu.model';

function createMockNLUResult(overrides: Partial<NLUResult>): NLUResult {
  const defaultEntities = {
    service_type: null,
    location: null,
    urgency: 'medium' as any,
    preferred_time: null,
    budget: null,
    complexity_hints: [],
    additional_details: null,
    job_complexity: null,
  };

  return {
    confidence: 100,
    language_detected: 'roman_urdu',
    intent: 'book_service',
    raw_input: '',
    normalized: '',
    processing_time_ms: 10,
    requires_clarification: false,
    clarification_question: null,
    ...overrides,
    entities: {
      ...defaultEntities,
      ...(overrides.entities || {})
    }
  };
}

async function runTests() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║         INTENT AGENT TEST SUITE — 5 Test Cases             ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  const agent = new IntentAgent();
  let passed = 0;
  let failed = 0;

  // Test 1: Complete input
  console.log('─── Test 1: Complete input (no follow-up needed) ───');
  const nlu1 = createMockNLUResult({
    entities: {
      service_type: 'ac_repair',
      location: { area: 'G-13', city: 'Islamabad', coordinates: null },
      urgency: 'high',
      preferred_time: { date: '2026-05-15', slot: 'morning', flexible: false, raw_text: 'kal subah' },
      budget: { sensitivity: 'high', max_amount: null, raw_text: 'budget zyada nahi hai' },
      complexity_hints: [],
      additional_details: null,
      job_complexity: 'intermediate'
    }
  });
  
  const res1 = agent.process({ nlu_result: nlu1, session_id: 'test1' });
  if (res1.status === 'complete' && res1.follow_up_needed === false && res1.confirmed_intent?.budget_sensitive === true) {
    console.log('  ✅ PASSED');
    passed++;
  } else {
    console.log('  ❌ FAILED', res1);
    failed++;
  }

  // Test 2: Missing time
  console.log('\n─── Test 2: Missing time ───');
  const nlu2 = createMockNLUResult({
    entities: {
      service_type: 'plumber',
      location: { area: 'G-13', city: 'Islamabad', coordinates: null },
      urgency: 'medium',
      preferred_time: null,
      budget: null,
      complexity_hints: [],
      additional_details: null,
      job_complexity: null
    }
  });
  const res2 = agent.process({ nlu_result: nlu2, session_id: 'test2' });
  if (res2.status === 'incomplete' && res2.follow_up_needed === true && res2.follow_up_question?.includes('Kab chahiye')) {
    console.log('  ✅ PASSED');
    passed++;
  } else {
    console.log('  ❌ FAILED', res2);
    failed++;
  }

  // Test 3: Missing location
  console.log('\n─── Test 3: Missing location ───');
  const nlu3 = createMockNLUResult({
    entities: {
      service_type: 'electrician',
      location: null,
      urgency: 'medium',
      preferred_time: { date: '2026-05-15', slot: 'morning', flexible: false, raw_text: 'kal subah' },
      budget: null,
      complexity_hints: [],
      additional_details: null,
      job_complexity: null
    }
  });
  const res3 = agent.process({ nlu_result: nlu3, session_id: 'test3' });
  if (res3.status === 'incomplete' && res3.follow_up_question?.includes('Kahan chahiye')) {
    console.log('  ✅ PASSED');
    passed++;
  } else {
    console.log('  ❌ FAILED', res3);
    failed++;
  }

  // Test 4: Missing service type
  console.log('\n─── Test 4: Missing service type ───');
  const nlu4 = createMockNLUResult({
    entities: {
      service_type: null,
      location: { area: 'G-13', city: 'Islamabad', coordinates: null },
      urgency: 'medium',
      preferred_time: { date: '2026-05-15', slot: 'morning', flexible: false, raw_text: 'kal subah' },
      budget: null,
      complexity_hints: [],
      additional_details: null,
      job_complexity: null
    }
  });
  const res4 = agent.process({ nlu_result: nlu4, session_id: 'test4' });
  if (res4.status === 'incomplete' && res4.follow_up_question?.includes('Kya service chahiye')) {
    console.log('  ✅ PASSED');
    passed++;
  } else {
    console.log('  ❌ FAILED', res4);
    failed++;
  }

  // Test 5: Multi-turn simulation
  console.log('\n─── Test 5: Multi-turn simulation ───');
  const session_id = 'test5_multi_turn';
  
  // Turn 1: plumber chahiye
  const t1 = createMockNLUResult({
    entities: {
      service_type: 'plumber',
      location: null,
      urgency: 'medium',
      preferred_time: null,
      budget: null,
      complexity_hints: [],
      additional_details: null,
      job_complexity: null
    }
  });
  const resT1 = agent.process({ nlu_result: t1, session_id });
  let t1Pass = resT1.status === 'incomplete' && resT1.follow_up_question?.includes('Kahan chahiye');
  
  // Turn 2: G-10 mein
  const t2 = createMockNLUResult({
    entities: {
      service_type: null,
      location: { area: 'G-10', city: 'Islamabad', coordinates: null },
      urgency: 'medium',
      preferred_time: null,
      budget: null,
      complexity_hints: [],
      additional_details: null,
      job_complexity: null
    }
  });
  const resT2 = agent.process({ nlu_result: t2, session_id });
  let t2Pass = resT2.status === 'incomplete' && resT2.follow_up_question?.includes('Kab chahiye');

  // Turn 3: kal dopahar
  const t3 = createMockNLUResult({
    entities: {
      service_type: null,
      location: null,
      urgency: 'medium',
      preferred_time: { date: '2026-05-15', slot: 'afternoon', flexible: false, raw_text: 'kal dopahar' },
      budget: null,
      complexity_hints: [],
      additional_details: null,
      job_complexity: null
    }
  });
  const resT3 = agent.process({ nlu_result: t3, session_id });
  let t3Pass = resT3.status === 'complete' && resT3.confirmed_intent?.service_type === 'plumber' && resT3.confirmed_intent?.location.area === 'G-10';

  if (t1Pass && t2Pass && t3Pass) {
    console.log('  ✅ PASSED');
    passed++;
  } else {
    console.log('  ❌ FAILED', { t1Pass, t2Pass, t3Pass });
    failed++;
  }

  // Summary
  console.log('\n\n╔══════════════════════════════════════════════════════════════╗');
  console.log(`║  RESULTS: ${passed} passed, ${failed} failed, 5 total`);
  console.log('╚══════════════════════════════════════════════════════════════╝');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(console.error);
