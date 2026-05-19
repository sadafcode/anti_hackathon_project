import { disputeReportAgent } from '../agents/dispute-report.agent';
import { run } from '@openai/agents';
import * as dotenv from 'dotenv';
import path from 'path';

// Load env variables
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

async function runTest() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║               DISPUTE REPORT AGENT TEST                      ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  const sampleDispute = {
    booking_id: 'BK-SAMPLE99',
    user_id: 'u123',
    provider_id: 'p123',
    issue_type: 'quality',
    description: 'Ali Hassan ne AC ki service theek nahi ki, cooling abhi bhi kharab hai aur compressor se ajeeb aawazein aa rahi hain. Aur usne cleaning bhi nahi ki badboo aa rahi hai.',
    provider_response: 'Maine kaam bilkul theek kiya tha, service ke waqt cooling bilkul sahi thi. Customer jhoot bol raha hai taake paise na dene parein. AC ka blower ganda tha jo maine saaf kar diya.',
    evidence_photos: [
      'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500',
      'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500'
    ],
    original_price: 2500,
    status: 'pending_review'
  };

  console.log('Generating Neutral Report via Gemini AI...');
  try {
    const prompt = `Analyze this dispute neutrally:
Dispute Type: ${sampleDispute.issue_type}
Client Complaint: ${sampleDispute.description}
Provider Response: ${sampleDispute.provider_response}
Evidence Photos: ${JSON.stringify(sampleDispute.evidence_photos)}
Original Price: Rs. ${sampleDispute.original_price}
Provider Name: Ali Hassan
Provider ID: ${sampleDispute.provider_id}`;

    const result = await run(disputeReportAgent, prompt);
    console.log('\n--- Neutral Dispute Report ---');
    console.log(JSON.stringify(result.finalOutput, null, 2));
    console.log('\n✅ Dispute Report Agent test passed successfully!');
  } catch (err) {
    console.error('❌ Dispute Report Agent test failed:', err);
  }
}

runTest().catch(console.error);
