import { NLUAgent } from '../agents/nlu.agent';
import * as dotenv from 'dotenv';
import path from 'path';

// Load env vars
dotenv.config({ path: path.resolve(__dirname, '../../../.env') }); // Or whatever the path is
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

async function run() {
  const agent = new NLUAgent();
  const input = "AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai";
  
  try {
    const result = await agent.parse({ message: input });
    console.log(JSON.stringify({
      language_detected: result.language_detected,
      confidence: result.confidence,
      normalized: result.normalized,
      requires_clarification: result.requires_clarification,
      full_output: result
    }, null, 2));
  } catch (error) {
    console.error('Error running NLU agent:', error);
  }
}

run();
