import * as dotenv from 'dotenv';
import path from 'path';
import util from 'util';
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

import { run } from '@openai/agents';
import { bookingAgent } from '../agents/booking.agent';

async function test() {
  const result = await run(bookingAgent, "test", { maxTurns: 1 });
  console.log("Inspection:");
  console.log(util.inspect(result, { showHidden: true, depth: 1 }));
}

test().catch(console.error);
