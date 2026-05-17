export interface Provider {
  id: string;
  name: string;
  photo_url?: string;
  nic?: string;
  service_types: string[];
  area: string;
  coordinates?: { lat: number; lng: number };
  capacity_today: number;
  risk_score: 'low' | 'medium' | 'high';
  strikes: number;
  rating: number;
  on_time_score: number;
  experience_years: number;
  total_reviews: number;
  review_sentiment: 'positive' | 'mostly_positive' | 'mixed' | 'negative' | 'unrated';
  certifications?: string[];
  tools_available?: string[];
  hourly_rate: number;
  availability?: any;
  cancellation_rate: number;
  user_preference_score: number;
  blue_tick: boolean;
  is_mock?: boolean;
  registered_at?: string;
}

export interface ConflictInfo {
  reason: string;
  perfect_match_explanation: string;
  next_available_slot: string;
  next_available_datetime: string;
  second_best_provider: RankedProvider | null;
}

export interface ScoreBreakdown {
  availability: number;
  distance: number;
  rating: number;
  reliability: number;
  specialization: number;
  review_sentiment: number;
  review_recency: number;
  price_vs_budget: number;
  capacity: number;
  cancellation_rate: number;
  user_preference: number;
  risk_score: number;
  nadra_trust: number;
}

export interface RankedProvider extends Provider {
  calculated_score: number;
  score_breakdown: ScoreBreakdown;
  ranking_reason: string;
  booking_conflict?: ConflictInfo;
}

export type DiscoveryAgentOutput =
  | {
      status: 'success';
      total_found: number;
      job_complexity: 'basic' | 'intermediate' | 'complex';
      ranked_providers: RankedProvider[];
    }
  | {
      status: 'no_providers';
      suggestion: 'next_available' | 'waitlist';
      next_available_slot: string | null;
      message: string;
      suggested_provider?: RankedProvider;
    };
