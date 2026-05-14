import fs from 'fs';
import path from 'path';
import { FeedbackAgent } from '../agents/feedback.agent';
import { RankedProvider } from '../models/discovery.model';

const agent = new FeedbackAgent();

function getProvider(id: string): RankedProvider {
  const dataPath = path.resolve(__dirname, '../../data/providers.json');
  const providers = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));
  return providers.find((p: any) => p.id === id);
}

async function runTests() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║               QUALITY & FEEDBACK AGENT TESTS                 ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  // Scenario 1: On-Time + 5 Stars (Ali Hassan)
  console.log('─── Scenario 1: On-Time + 5 Stars ───');
  const provider1 = getProvider('p1');
  const res1 = await agent.processFeedback({
    booking_id: 'BK-1001',
    provider: { id: provider1.id, name: provider1.name },
    mock_action: 'on_time',
    feedback: { stars: 5, comment: 'Excellent and quick repair!' }
  });
  console.log('Result:', JSON.stringify(res1, null, 2));

  // Scenario 2: Late + 3 Stars (Tariq Mehmood)
  console.log('\n─── Scenario 2: Late + 3 Stars ───');
  const provider2 = getProvider('p2');
  const res2 = await agent.processFeedback({
    booking_id: 'BK-1002',
    provider: { id: provider2.id, name: provider2.name },
    mock_action: 'late',
    feedback: { stars: 3, comment: 'Arrived 30 mins late, but fixed the issue.' }
  });
  console.log('Result:', JSON.stringify(res2, null, 2));

  // Scenario 3: No-Show (Bilal Ahmed)
  console.log('\n─── Scenario 3: No-Show ───');
  const provider3 = getProvider('p3');
  const res3 = await agent.processFeedback({
    booking_id: 'BK-1003',
    provider: { id: provider3.id, name: provider3.name },
    mock_action: 'no_show'
  });
  console.log('Result:', JSON.stringify(res3, null, 2));

  console.log('\n✅ All feedback tests executed.');
}

runTests().catch(console.error);
