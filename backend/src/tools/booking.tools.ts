import { tool } from '@openai/agents';
import { z } from 'zod';
import { bookingStore } from '../store/booking.store';

function findNextFreeSlot(provider: any, requestedDatetime: string, bookedDatetimes: string[]): { label: string; iso: string } {
  const requested = new Date(requestedDatetime);
  const booked = bookedDatetimes.map(d => new Date(d));
  const days = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  for (let offset = 0; offset <= 14; offset++) {
    const checkDate = new Date(requested);
    checkDate.setDate(checkDate.getDate() + offset);
    const dayName = days[checkDate.getDay()];
    const slots: string[] = provider.availability?.[dayName] || [];

    for (const slot of slots) {
      const [h, m] = slot.split(':').map(Number);
      const slotDate = new Date(checkDate);
      slotDate.setHours(h, m, 0, 0);
      if (slotDate <= new Date()) continue;
      if (offset === 0 && Math.abs(slotDate.getTime() - requested.getTime()) < 75 * 60 * 1000) continue;
      const conflict = booked.some(b => Math.abs(slotDate.getTime() - b.getTime()) < 75 * 60 * 1000);
      if (!conflict) {
        const label = offset === 1
          ? `Kal, ${slotDate.getDate()} ${months[slotDate.getMonth()]} — ${slot}`
          : `${dayName.charAt(0).toUpperCase() + dayName.slice(1)}, ${slotDate.getDate()} ${months[slotDate.getMonth()]} — ${slot}`;
        return { label, iso: slotDate.toISOString() };
      }
    }
  }
  return { label: 'Agle 2 hafte mein koi slot nahi', iso: '' };
}

export const checkBookingConflict = tool({
  name: 'check_booking_conflict',
  description: 'Check if a provider has a booking conflict at the requested time (75-minute buffer).',
  parameters: z.object({
    provider_id: z.string(),
    requested_datetime: z.string().describe('ISO datetime string'),
  }),
  execute: async ({ provider_id, requested_datetime }) => {
    const booked = bookingStore.getConfirmedDatetimes(provider_id);
    const requested = new Date(requested_datetime);
    for (const dt of booked) {
      const diff = Math.abs(new Date(dt).getTime() - requested.getTime()) / 60000;
      if (diff < 75) return { conflict: true, conflicting_slot: dt };
    }
    return { conflict: false, conflicting_slot: null };
  },
});

export const createBooking = tool({
  name: 'create_booking',
  description: 'Create a new booking record. Returns booking ID and pending status.',
  parameters: z.object({
    provider_id: z.string(),
    provider_name: z.string(),
    service_type: z.string(),
    datetime: z.string(),
    total_price: z.number(),
    intent: z.string().describe('JSON string of the confirmed intent object'),
    all_ranked_providers_json: z.string().nullable().describe('JSON string of all ranked providers array, or null'),
    is_returning_user: z.boolean().nullable(),
    client_session_id: z.string().nullable(),
  }),
  execute: async (params) => {
    let intent: any = {};
    let allRanked: any[] = [];
    try { intent = JSON.parse(params.intent); } catch {}
    try { if (params.all_ranked_providers_json) allRanked = JSON.parse(params.all_ranked_providers_json); } catch {}

    const record = bookingStore.createBooking({
      provider_id: params.provider_id,
      service_type: params.service_type,
      datetime: params.datetime,
      total_price: params.total_price,
      intent,
      all_ranked_providers: allRanked,
      is_returning_user: params.is_returning_user ?? false,
      client_session_id: params.client_session_id ?? undefined,
    });

    return {
      booking_id: record.id,
      provider_name: params.provider_name,
      status: 'pending',
      status_message: 'Booking sent to provider. Waiting for acceptance.',
      datetime: params.datetime,
      total_price: params.total_price,
    };
  },
});

export const findNextFreeSlotTool = tool({
  name: 'find_next_free_slot',
  description: 'Find the next available booking slot for a provider when the requested time has a conflict.',
  parameters: z.object({
    provider_json: z.string().describe('Full provider object serialized as JSON string'),
    requested_datetime: z.string(),
    provider_id: z.string(),
  }),
  execute: async ({ provider_json, requested_datetime, provider_id }) => {
    let provider: any = {};
    try { provider = JSON.parse(provider_json); } catch {}
    const booked = bookingStore.getConfirmedDatetimes(provider_id);
    return findNextFreeSlot(provider, requested_datetime, booked);
  },
});

export const respondToBooking = tool({
  name: 'respond_to_booking',
  description: 'Provider accepts or declines a pending booking.',
  parameters: z.object({
    booking_id: z.string(),
    provider_id: z.string(),
    action: z.enum(['accept', 'decline']),
    reason: z.string().nullable(),
  }),
  execute: async ({ booking_id, provider_id, action, reason }) => {
    const found = bookingStore.findById(booking_id);
    if (!found) return { success: false, error: 'Booking not found' };
    if (found.booking.status !== 'pending') return { success: false, error: `Cannot respond — booking is ${found.booking.status}` };
    if (action === 'accept') {
      bookingStore.updateStatus(booking_id, 'confirmed');
      return { success: true, booking_status: 'confirmed', error: null };
    } else {
      bookingStore.updateStatus(booking_id, 'provider_declined');
      return { success: true, booking_status: 'provider_declined', error: null };
    }
  },
});

export const cancelBookingWithPenalty = tool({
  name: 'cancel_booking_with_penalty',
  description: 'Cancel a confirmed booking and apply penalty to the provider.',
  parameters: z.object({ booking_id: z.string() }),
  execute: async ({ booking_id }) => {
    const found = bookingStore.findById(booking_id);
    if (!found) return { success: false, error: 'Booking not found', cancelled_provider_id: null, next_provider: null };
    bookingStore.updateStatus(booking_id, 'cancelled_with_penalty');
    bookingStore.applyPenaltyToProvider(found.provider_id);
    const allCandidates = found.booking.all_ranked_providers || [];
    const nextProvider = allCandidates.find((p: any) => p.id !== found.provider_id) || null;
    return { success: true, cancelled_provider_id: found.provider_id, next_provider: nextProvider, error: null };
  },
});

export const getBookedSlots = tool({
  name: 'get_booked_slots',
  description: 'Get all confirmed booking datetimes for a provider.',
  parameters: z.object({ provider_id: z.string() }),
  execute: async ({ provider_id }) => {
    return { provider_id, booked_slots: bookingStore.getConfirmedDatetimes(provider_id) };
  },
});

export const getPendingBookings = tool({
  name: 'get_pending_bookings',
  description: 'Get all pending booking requests for a provider.',
  parameters: z.object({ provider_id: z.string() }),
  execute: async ({ provider_id }) => {
    return bookingStore.getPendingByProvider(provider_id);
  },
});
