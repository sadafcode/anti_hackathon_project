export type DisputeType = 'no_show' | 'quality_complaint' | 'price_disagreement' | 'overrun' | 'cancellation';

export interface DisputeInput {
  booking_id: string;
  provider: {
    id: string;
    name: string;
  };
  dispute_type: DisputeType;
  original_price?: number;
  overcharged_amount?: number;
  extra_charge_amount?: number;
  hours_before_job?: number;
  language_detected?: string;
}

export interface DisputeOutput {
  dispute_type: DisputeType;
  resolution: string;
  refund_amount: number;
  strikes_after?: number;
  status: 'resolved' | 'pending_user_approval' | 'blacklisted';
}
