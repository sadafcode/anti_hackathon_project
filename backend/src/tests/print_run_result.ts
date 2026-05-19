import * as dotenv from 'dotenv';
import path from 'path';
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

import { run } from '@openai/agents';
import { bookingAgent } from '../agents/booking.agent';

async function test() {
  const result = await run(bookingAgent, "test", { maxTurns: 1 });
  console.log("RunResult keys:", Object.keys(result));
  console.log("RunResult JSON:", JSON.stringify(result, (key, value) => {
    if (key === 'agent' || key === 'tools') return undefined; // avoid circular or large objects
    return value;
  }, 2));
}

test().catch(console.error);
