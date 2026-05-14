import { ConfirmedIntent } from './intent.model';
import { RankedProvider } from './discovery.model';
import { PricingAgentOutput } from './pricing.model';

export type BookingStatus = 'confirmed' | 'conflict_waitlist' | 'provider_declined' | 'cancelled_with_penalty';

export interface BookingRequest {
  intent: ConfirmedIntent;
  provider: RankedProvider;
  pricing: PricingAgentOutput;
  mock_action?: 'accept' | 'decline' | 'accept-then-reject';
  all_ranked_providers?: RankedProvider[]; // To auto-reschedule if needed
  is_returning_user?: boolean;
}

export interface BookingReceipt {
  booking_id: string;
  provider_name: string;
  blue_tick: boolean;
  service: string;
  datetime: string;
  total_price: number;
  status_message: string;
  status: BookingStatus;
  waitlist_suggestion?: string;
}

export interface BookingRecord {
  id: string;
  provider_id: string;
  datetime: Date;
  status: BookingStatus;
  request: BookingRequest;
}
