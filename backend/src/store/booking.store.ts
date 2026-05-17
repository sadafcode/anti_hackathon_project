import { randomUUID } from 'crypto';
import fs from 'fs';
import path from 'path';

export interface BookingRecord {
  id: string;
  provider_id: string;
  client_session_id?: string;
  service_type: string;
  datetime: string;
  status: 'pending' | 'confirmed' | 'provider_declined' | 'cancelled_with_penalty';
  total_price: number;
  intent: any;
  all_ranked_providers?: any[];
  is_returning_user?: boolean;
  created_at: string;
}

// Singleton in-memory store — lives until server restarts
class BookingStore {
  private bookings = new Map<string, BookingRecord[]>(); // keyed by provider_id

  createBooking(params: {
    provider_id: string;
    service_type: string;
    datetime: string;
    total_price: number;
    intent: any;
    all_ranked_providers?: any[];
    is_returning_user?: boolean;
    client_session_id?: string;
  }): BookingRecord {
    const record: BookingRecord = {
      id: 'BK-' + randomUUID().substring(0, 8).toUpperCase(),
      status: 'pending',
      created_at: new Date().toISOString(),
      ...params,
    };
    const list = this.bookings.get(params.provider_id) || [];
    list.push(record);
    this.bookings.set(params.provider_id, list);
    return record;
  }

  getByProvider(provider_id: string): BookingRecord[] {
    return this.bookings.get(provider_id) || [];
  }

  getPendingByProvider(provider_id: string): BookingRecord[] {
    return this.getByProvider(provider_id).filter(b => b.status === 'pending');
  }

  getConfirmedDatetimes(provider_id: string): string[] {
    return this.getByProvider(provider_id)
      .filter(b => b.status === 'confirmed' || b.status === 'pending')
      .map(b => b.datetime);
  }

  findById(booking_id: string): { booking: BookingRecord; provider_id: string } | null {
    for (const [provider_id, records] of this.bookings.entries()) {
      const booking = records.find(r => r.id === booking_id);
      if (booking) return { booking, provider_id };
    }
    return null;
  }

  updateStatus(booking_id: string, status: BookingRecord['status']): boolean {
    for (const records of this.bookings.values()) {
      const rec = records.find(r => r.id === booking_id);
      if (rec) { rec.status = status; return true; }
    }
    return false;
  }

  applyPenaltyToProvider(provider_id: string): void {
    try {
      const dataPath = path.resolve(__dirname, '../../data/providers.json');
      const providers = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));
      const idx = providers.findIndex((p: any) => p.id === provider_id);
      if (idx !== -1) {
        providers[idx].cancellation_rate = (providers[idx].cancellation_rate || 0) + 1;
        providers[idx].on_time_score = Math.max(0, (providers[idx].on_time_score || 100) - 10);
        fs.writeFileSync(dataPath, JSON.stringify(providers, null, 2));
      }
    } catch {}
  }
}

export const bookingStore = new BookingStore();
