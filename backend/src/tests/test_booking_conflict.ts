import * as dotenv from 'dotenv';
import path from 'path';
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

import { run } from '@openai/agents';
import { bookingAgent } from '../agents/booking.agent';
import { bookingStore } from '../store/booking.store';

async function test() {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const timeA = new Date(tomorrow.setHours(10, 0, 0, 0)).toISOString();
  const timeB = new Date(tomorrow.setHours(10, 15, 0, 0)).toISOString();

  // Create booking A and confirm it
  const bA = bookingStore.createBooking({
    provider_id: 'p2',
    service_type: 'electrician',
    datetime: timeA,
    total_price: 1000,
    intent: {}
  });
  bookingStore.updateStatus(bA.id, 'confirmed');

  const prompt = `Process this service booking request:

PROVIDER: ${JSON.stringify({
  id: 'p2',
  name: 'Tariq Mehmood',
  area: 'G-13',
  blue_tick: true,
  hourly_rate: 800,
  availability: { monday: ['09:00', '10:00', '11:00'], tuesday: ['09:00', '10:00', '11:00'], wednesday: ['09:00', '10:00', '11:00'] },
})}

INTENT: ${JSON.stringify({
  service_type: 'electrician',
  location: { area: 'G-13', city: 'Islamabad' },
  datetime: timeB,
  urgency: 'medium',
})}

PRICING TOTAL: Rs.1000

ALL RANKED PROVIDERS COUNT: 1
IS RETURNING USER: false
CLIENT SESSION ID: none
MOCK ACTION: accept

Follow these steps:
1. Call check_booking_conflict for provider.id and intent.datetime
2. If no conflict: call create_booking and return pending status
3. If conflict: call find_next_free_slot and return conflict_waitlist status`;

  console.log('Running agent...');
  const result = await run(bookingAgent, prompt, { maxTurns: 20 });
  console.log('Success final output:', result.finalOutput);
}

test().catch(console.error);
