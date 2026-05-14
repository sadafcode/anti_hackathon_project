/**
 * NLU Agent Test Suite
 * 
 * Tests the NLU Agent against 12 diverse scenarios covering:
 * - Roman Urdu, English, Urdu script, mixed language
 * - Misspellings, slang, noisy input
 * - Greetings, status checks, vague requests
 * - Edge cases: empty input, gibberish
 * 
 * Usage: npx tsx backend/src/tests/nlu.test.ts
 * Requires: GEMINI_API_KEY in .env file
 */

import * as dotenv from 'dotenv';
import * as path from 'path';
dotenv.config({ path: path.resolve(process.cwd(), '.env'), override: true });

import { NLUAgent } from '../agents/nlu.agent';
import { NLUResult } from '../models/nlu.model';

// ─── Test Cases ───────────────────────────────────────────────

interface TestCase {
  name: string;
  input: string;
  expected: {
    intent: string;
    service_type: string | null;
    area: string | null;
    urgency?: string;
    min_confidence: number;
  };
}

const TEST_CASES: TestCase[] = [
  {
    name: '1. Roman Urdu — AC repair with full details',
    input: 'AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai',
    expected: {
      intent: 'book_service',
      service_type: 'ac_repair',
      area: 'G-13',
      urgency: 'high',
      min_confidence: 0.85,
    },
  },
  {
    name: '2. English — Plumber request',
    input: 'I need a plumber in F-10 today evening, my kitchen pipe is leaking badly',
    expected: {
      intent: 'book_service',
      service_type: 'plumber',
      area: 'F-10',
      min_confidence: 0.9,
    },
  },
  {
    name: '3. Mixed — Electrician with budget',
    input: 'electrician chahiye F-8 mein, switch board change karna hai, budget 2000 tak',
    expected: {
      intent: 'book_service',
      service_type: 'electrician',
      area: 'F-8',
      min_confidence: 0.85,
    },
  },
  {
    name: '4. Misspelled + Slang — Plumber emergency',
    input: 'bhai plumer bhejo jaldi G-13 mei pani aara hai har jagah',
    expected: {
      intent: 'book_service',
      service_type: 'plumber',
      area: 'G-13',
      urgency: 'high',
      min_confidence: 0.75,
    },
  },
  {
    name: '5. Vague request — should need clarification',
    input: 'kuch kaam karwana hai',
    expected: {
      intent: 'book_service',
      service_type: null,
      area: null,
      min_confidence: 0.0, // Very low expected
    },
  },
  {
    name: '6. Greeting',
    input: 'Assalam o alaikum',
    expected: {
      intent: 'greeting',
      service_type: null,
      area: null,
      min_confidence: 0.9,
    },
  },
  {
    name: '7. Status check',
    input: 'meri booking ka kya status hai?',
    expected: {
      intent: 'check_status',
      service_type: null,
      area: null,
      min_confidence: 0.85,
    },
  },
  {
    name: '8. Tutor request — Mixed',
    input: 'meri beti ko math ki tuition chahiye, I-8 mein, budget 15000 monthly',
    expected: {
      intent: 'book_service',
      service_type: 'tutor',
      area: 'I-8',
      min_confidence: 0.85,
    },
  },
  {
    name: '9. Carpenter — Complex job',
    input: 'almari banana hai custom size ki, F-10 mein, agle hafte',
    expected: {
      intent: 'book_service',
      service_type: 'carpenter',
      area: 'F-10',
      min_confidence: 0.85,
    },
  },
  {
    name: '10. Emergency — Roman Urdu',
    input: 'bijli ka short circuit ho gaya hai G-11 mein, abhi foran aao please',
    expected: {
      intent: 'book_service',
      service_type: 'electrician',
      area: 'G-11',
      urgency: 'emergency',
      min_confidence: 0.8,
    },
  },
  {
    name: '11. Empty input — edge case',
    input: '',
    expected: {
      intent: 'unclear',
      service_type: null,
      area: null,
      min_confidence: 0.0,
    },
  },
  {
    name: '12. Cancel booking',
    input: 'mujhe apni booking cancel karni hai, kal wali',
    expected: {
      intent: 'cancel_booking',
      service_type: null,
      area: null,
      min_confidence: 0.8,
    },
  },
];

// ─── Test Runner ──────────────────────────────────────────────

async function runTests() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║         NLU AGENT TEST SUITE — 12 Test Cases               ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  const agent = new NLUAgent();
  let passed = 0;
  let failed = 0;

  for (const tc of TEST_CASES) {
    console.log(`\n─── ${tc.name} ───`);
    console.log(`Input: "${tc.input}"`);

    try {
      const result: NLUResult = await agent.parse({ message: tc.input });

      // Check assertions
      const checks: { label: string; pass: boolean; got: any; want: any }[] = [];

      checks.push({
        label: 'Intent',
        pass: result.intent === tc.expected.intent,
        got: result.intent,
        want: tc.expected.intent,
      });

      checks.push({
        label: 'Service Type',
        pass: result.entities.service_type === tc.expected.service_type,
        got: result.entities.service_type,
        want: tc.expected.service_type,
      });

      checks.push({
        label: 'Area',
        pass: result.entities.location?.area === tc.expected.area,
        got: result.entities.location?.area,
        want: tc.expected.area,
      });

      checks.push({
        label: 'Confidence',
        pass: result.confidence >= tc.expected.min_confidence,
        got: result.confidence.toFixed(2),
        want: `>= ${tc.expected.min_confidence}`,
      });

      if (tc.expected.urgency) {
        checks.push({
          label: 'Urgency',
          pass: result.entities.urgency === tc.expected.urgency,
          got: result.entities.urgency,
          want: tc.expected.urgency,
        });
      }

      // Print results
      let allPassed = true;
      for (const c of checks) {
        const icon = c.pass ? '✅' : '❌';
        console.log(`  ${icon} ${c.label}: got=${c.got}, want=${c.want}`);
        if (!c.pass) allPassed = false;
      }

      // Print extra info
      console.log(`  ℹ️  Language: ${result.language_detected}`);
      console.log(`  ℹ️  Time: ${result.processing_time_ms}ms`);
      if (result.requires_clarification) {
        console.log(`  ⚠️  Clarification: "${result.clarification_question}"`);
      }
      if (result.entities.complexity_hints.length > 0) {
        console.log(`  🔧 Complexity hints: ${result.entities.complexity_hints.join(', ')}`);
      }

      if (allPassed) {
        passed++;
        console.log(`  ✅ PASSED`);
      } else {
        failed++;
        console.log(`  ❌ FAILED`);
      }
    } catch (error: any) {
      failed++;
      console.log(`  ❌ ERROR: ${error.message}`);
    }

    // 15s delay — free tier limit is 5 req/min for gemini-2.5-flash
    await new Promise(resolve => setTimeout(resolve, 15000));
  }

  // Summary
  console.log('\n\n╔══════════════════════════════════════════════════════════════╗');
  console.log(`║  RESULTS: ${passed} passed, ${failed} failed, ${TEST_CASES.length} total`);
  console.log('╚══════════════════════════════════════════════════════════════╝');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(console.error);
