import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';
import { BookingRequest, BookingReceipt, BookingRecord } from '../models/booking.model';
import { Provider } from '../models/discovery.model';
import { PricingAgent } from './pricing.agent';

export class BookingAgent {
  private bookings: Map<string, BookingRecord[]> = new Map();

  public async bookService(request: BookingRequest): Promise<BookingReceipt> {
    const { provider, intent, pricing, mock_action } = request;
    const requestedTime = new Date(intent.datetime);
    
    // 1. Double booking check (1 hr job + 15 mins buffer = 75 mins)
    const providerBookings = this.bookings.get(provider.id) || [];
    for (const b of providerBookings) {
      if (b.status === 'confirmed') {
        const diffMs = Math.abs(requestedTime.getTime() - b.datetime.getTime());
        const diffMins = diffMs / (1000 * 60);
        if (diffMins < 75) {
          // Conflict
          const waitlistTime = new Date(requestedTime.getTime() + 2 * 60 * 60 * 1000); // suggest 2 hours later
          return {
            booking_id: '',
            provider_name: provider.name,
            blue_tick: provider.blue_tick,
            service: intent.service_type,
            datetime: intent.datetime,
            total_price: pricing.total,
            status: 'conflict_waitlist',
            status_message: 'Time slot unavailable.',
            waitlist_suggestion: waitlistTime.toISOString(),
            provider_id: provider.id
          };
        }
      }
    }

    // 2. We no longer mock a 3-second delay here because we want to return immediately as 'pending'.
    console.log(`\n⏳ Sending request to provider ${provider.name}... waiting for provider to respond from their app.`);

    // 3. Provider Decline
    if (mock_action === 'decline') {
      return {
        booking_id: '',
        provider_name: provider.name,
        blue_tick: provider.blue_tick,
        service: intent.service_type,
        datetime: intent.datetime,
        total_price: pricing.total,
        status: 'provider_declined',
        status_message: 'Provider declined the request.',
        provider_id: provider.id
      };
    }

    // 4. Provider Accept (or accept-then-reject initial phase)
    console.log(`📱 [MOCK FCM/WhatsApp] Notification: "Aapki booking ${provider.name} ke sath confirm ho gayi hai!"`);

    const booking_id = 'BK-' + randomUUID().substring(0, 8).toUpperCase();
    const newRecord: BookingRecord = {
      id: booking_id,
      provider_id: provider.id,
      datetime: requestedTime,
      status: 'pending', // MODIFIED: Start in pending state
      request
    };
    
    if (!this.bookings.has(provider.id)) {
      this.bookings.set(provider.id, []);
    }
    this.bookings.get(provider.id)!.push(newRecord);

    return {
      booking_id,
      provider_name: provider.name,
      blue_tick: provider.blue_tick,
      service: intent.service_type,
      datetime: intent.datetime,
      total_price: pricing.total,
      status: 'pending',
      status_message: 'Booking sent to provider. Waiting for acceptance.',
      provider_id: provider.id
    };
  }

  public getPendingBookings(providerId: string): BookingRecord[] {
    const providerBookings = this.bookings.get(providerId) || [];
    return providerBookings.filter(b => b.status === 'pending');
  }

  public async respondToBooking(bookingId: string, providerId: string, action: string, reason?: string): Promise<any> {
    const providerBookings = this.bookings.get(providerId) || [];
    const booking = providerBookings.find(b => b.id === bookingId);

    if (!booking) {
      throw new Error('Booking not found');
    }

    if (booking.status !== 'pending') {
      throw new Error(`Cannot respond to booking in status: ${booking.status}`);
    }

    if (action === 'accept') {
      booking.status = 'confirmed';
      return { status: 'success', booking_status: 'confirmed' };
    } else if (action === 'decline') {
      booking.status = 'provider_declined';
      console.log(`Provider declined booking. Reason: ${reason}`);

      // Auto-reschedule logic (similar to simulation)
      const allCandidates = booking.request.all_ranked_providers || [];
      const nextProvider = allCandidates.find(p => p.id !== providerId);

      if (nextProvider) {
        console.log(`🔄 Provider declined — finding next provider: ${nextProvider.name}`);
        const pricingAgent = new PricingAgent();
        const newPricing = pricingAgent.calculatePrice({
          provider: nextProvider,
          intent: booking.request.intent,
          is_returning_user: booking.request.is_returning_user || false
        });

        const newRequest: BookingRequest = {
          ...booking.request,
          provider: nextProvider,
          pricing: newPricing,
          mock_action: undefined 
        };

        const newBooking = await this.bookService(newRequest);
        return { status: 'declined', auto_rescheduled: true, new_booking: newBooking };
      }

      return { status: 'declined', auto_rescheduled: false };
    } else {
      throw new Error('Invalid action');
    }
  }

  public async simulateProviderCancellation(bookingId: string): Promise<BookingReceipt | null> {
    let foundRecord: BookingRecord | null = null;
    let targetProviderId: string | null = null;

    for (const [providerId, records] of this.bookings.entries()) {
      const record = records.find(r => r.id === bookingId);
      if (record) {
        foundRecord = record;
        targetProviderId = providerId;
        break;
      }
    }

    if (!foundRecord || !targetProviderId) return null;

    // Penalty logging
    foundRecord.status = 'cancelled_with_penalty';
    console.log(`\n❌ Provider ${foundRecord.request.provider.name} cancelled after accepting!`);
    
    // Update providers.json
    this.applyPenaltyToProvider(targetProviderId);

    // Auto-reschedule
    console.log(`🔄 Provider cancelled — finding next provider...`);
    const allCandidates = foundRecord.request.all_ranked_providers || [];
    const nextProvider = allCandidates.find(p => p.id !== targetProviderId);

    if (!nextProvider) {
      console.log('No alternative providers available for auto-reschedule.');
      return null;
    }

    console.log(`✅ Assigned to new provider: ${nextProvider.name}`);

    // Recalculate price for new provider
    const pricingAgent = new PricingAgent();
    const newPricing = pricingAgent.calculatePrice({
      provider: nextProvider,
      intent: foundRecord.request.intent,
      is_returning_user: foundRecord.request.is_returning_user || false
    });

    const newRequest: BookingRequest = {
      ...foundRecord.request,
      provider: nextProvider,
      pricing: newPricing,
      mock_action: 'accept' // Next one will cleanly accept
    };

    return this.bookService(newRequest);
  }

  private applyPenaltyToProvider(providerId: string) {
    try {
      const dataPath = path.resolve(__dirname, '../../data/providers.json');
      if (fs.existsSync(dataPath)) {
        const fileContent = fs.readFileSync(dataPath, 'utf-8');
        const providers: Provider[] = JSON.parse(fileContent);
        
        const idx = providers.findIndex(p => p.id === providerId);
        if (idx !== -1) {
          // IMPORTANT logic: cancellation_rate + 1, reliability_score - 10
          providers[idx].cancellation_rate += 1;
          providers[idx].on_time_score = Math.max(0, providers[idx].on_time_score - 10);
          fs.writeFileSync(dataPath, JSON.stringify(providers, null, 2));
          console.log(`   📉 Logged Penalty. Updated profile: cancellation_rate=${providers[idx].cancellation_rate}, reliability=${providers[idx].on_time_score}`);
        }
      }
    } catch (e) {
      console.error('Error updating provider penalty:', e);
    }
  }
}
