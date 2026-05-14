import fs from 'fs';
import path from 'path';
import { DisputeAgent } from '../agents/dispute.agent';
import { RankedProvider } from '../models/discovery.model';

const agent = new DisputeAgent();

function getProvider(id: string): RankedProvider {
  const dataPath = path.resolve(__dirname, '../../data/providers.json');
  const providers = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));
  return providers.find((p: any) => p.id === id);
}

async function runTests() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║               DISPUTE & RESOLUTION AGENT TESTS               ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  // Scenario 1: No-Show (Kamran Shah)
  console.log('─── Scenario 1: No-Show (3-Strike Blacklist) ───');
  const provider7 = getProvider('p7'); // Kamran Shah (Starts with 2 strikes)
  const res1 = agent.resolveDispute({
    booking_id: 'BK-0001',
    provider: { id: provider7.id, name: provider7.name },
    dispute_type: 'no_show',
    original_price: 1500
  });
  console.log('Result:', JSON.stringify(res1, null, 2));

  // Scenario 2: Quality Complaint
  console.log('\n─── Scenario 2: Quality Complaint ───');
  const res2 = agent.resolveDispute({
    booking_id: 'BK-0002',
    provider: { id: 'p1', name: 'Ali Hassan' },
    dispute_type: 'quality_complaint',
    original_price: 2000
  });
  console.log('Result:', JSON.stringify(res2, null, 2));

  // Scenario 3: Price Disagreement
  console.log('\n─── Scenario 3: Price Disagreement ───');
  const res3 = agent.resolveDispute({
    booking_id: 'BK-0003',
    provider: { id: 'p2', name: 'Tariq Mehmood' },
    dispute_type: 'price_disagreement',
    overcharged_amount: 500
  });
  console.log('Result:', JSON.stringify(res3, null, 2));

  // Scenario 4: Overrun
  console.log('\n─── Scenario 4: Overrun ───');
  const res4 = agent.resolveDispute({
    booking_id: 'BK-0004',
    provider: { id: 'p3', name: 'Bilal Ahmed' },
    dispute_type: 'overrun',
    extra_charge_amount: 800
  });
  console.log('Result:', JSON.stringify(res4, null, 2));

  // Scenario 5: Cancellation (< 2 hours)
  console.log('\n─── Scenario 5a: Late Cancellation (< 2 hours) ───');
  const res5a = agent.resolveDispute({
    booking_id: 'BK-0005',
    provider: { id: 'p4', name: 'Usman Ali' },
    dispute_type: 'cancellation',
    original_price: 1000,
    hours_before_job: 1
  });
  console.log('Result:', JSON.stringify(res5a, null, 2));

  // Scenario 5: Cancellation (>= 2 hours)
  console.log('\n─── Scenario 5b: Cancellation (>= 2 hours) ───');
  const res5b = agent.resolveDispute({
    booking_id: 'BK-0006',
    provider: { id: 'p4', name: 'Usman Ali' },
    dispute_type: 'cancellation',
    original_price: 1000,
    hours_before_job: 5
  });
  console.log('Result:', JSON.stringify(res5b, null, 2));

  console.log('\n✅ All dispute tests executed.');
}

runTests().catch(console.error);
