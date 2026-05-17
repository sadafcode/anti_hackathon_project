import { z } from 'zod';

// Shared output schema for all chat-facing agents (orchestrator + sub-agents with handoffs).
export const ChatOutputSchema = z.object({
  reply: z.string().describe('The exact message to display to the user. LANGUAGE RULE: if language_detected=english write in English; if language_detected=roman_urdu write in Roman Urdu; if language_detected=urdu write in Urdu script. NEVER mix languages in this field.'),
  status: z.enum(['collecting_info', 'complete', 'off_topic', 'empathy_handled']),
  language_detected: z.enum(['urdu', 'roman_urdu', 'english', 'roman_urdu_mixed', 'urdu_mixed', 'unknown']).describe('Language of the CURRENT user message — update every turn'),
  user_emotion: z.enum(['neutral', 'frustrated', 'angry', 'satisfied', 'confused']),
  collected_info: z.object({
    service_type: z.string().nullable().describe('e.g. ac_repair, plumber, electrician, carpenter, tutor, beautician, driver, mechanic, painter, cleaning'),
    area: z.string().nullable().describe('Customer area e.g. G-11, F-10, Gulberg'),
    city: z.string().nullable().describe('e.g. Islamabad, Lahore, Karachi'),
    datetime_iso: z.string().nullable().describe('ISO datetime e.g. 2026-05-18T09:00:00'),
    urgency: z.enum(['low', 'medium', 'high', 'emergency']).nullable(),
    budget_sensitive: z.boolean(),
    job_complexity: z.enum(['basic', 'intermediate', 'complex']).nullable(),
  }),
  confidence: z.number().min(0).max(100),
});

export type ChatOutput = z.infer<typeof ChatOutputSchema>;

// Provider score breakdown — used inside ranked providers
const ScoreBreakdownSchema = z.object({
  availability: z.number(),
  distance: z.number(),
  rating: z.number(),
  reliability: z.number(),
  specialization: z.number(),
  price_vs_budget: z.number(),
  nadra_trust: z.number(),
});

// Single ranked provider
const RankedProviderSchema = z.object({
  id: z.string(),
  name: z.string(),
  photo_url: z.string().nullable(),
  area: z.string(),
  service_types: z.array(z.string()),
  rating: z.number(),
  total_reviews: z.number(),
  review_sentiment: z.string(),
  experience_years: z.number(),
  on_time_score: z.number(),
  cancellation_rate: z.number(),
  hourly_rate: z.number(),
  capacity_today: z.number(),
  blue_tick: z.boolean(),
  risk_score: z.string(),
  strikes: z.number(),
  certifications: z.array(z.string()),
  tools_available: z.array(z.string()),
  user_preference_score: z.number(),
  same_area: z.boolean(),
  calculated_score: z.number(),
  ranking_reason: z.string(),
  score_breakdown: ScoreBreakdownSchema,
});

// Discovery output
export const DiscoveryOutputSchema = z.object({
  status: z.enum(['success', 'no_providers']),
  message: z.string().nullable(),
  total_found: z.number(),
  job_complexity: z.string().nullable(),
  suggestion: z.string().nullable(),
  next_available_slot: z.string().nullable(),
  ranked_providers: z.array(RankedProviderSchema).nullable(),
  suggested_provider: RankedProviderSchema.nullable(),
});

// Pricing output
export const PricingOutputSchema = z.object({
  base_rate: z.number(),
  complexity_factor: z.number(),
  urgency_fee: z.number(),
  distance_cost: z.number(),
  surge_applied: z.boolean(),
  surge_fee: z.number(),
  loyalty_discount: z.number(),
  platform_fee: z.number(),
  provider_earning: z.number(),
  provider_percentage_note: z.string(),
  total: z.number(),
  breakdown_text: z.string(),
  budget_alternative: z.object({
    description: z.string(),
    price: z.number(),
  }).nullable(),
});

// Conflict info for booking
const ConflictInfoSchema = z.object({
  reason: z.string(),
  perfect_match_explanation: z.string(),
  next_available_slot: z.string(),
  next_available_datetime: z.string(),
  second_best_provider_id: z.string().nullable(),
  second_best_provider_name: z.string().nullable(),
});

// Booking output
export const BookingOutputSchema = z.object({
  booking_id: z.string(),
  provider_name: z.string(),
  provider_id: z.string(),
  blue_tick: z.boolean(),
  service: z.string(),
  datetime: z.string(),
  total_price: z.number(),
  status: z.enum(['pending', 'conflict_waitlist', 'provider_declined']),
  status_message: z.string(),
  waitlist_suggestion: z.string().nullable(),
  conflict_info: ConflictInfoSchema.nullable(),
});

// Feedback output
export const FeedbackOutputSchema = z.object({
  status: z.enum(['completed', 'no_show']),
  dispute_triggered: z.boolean(),
  checklist: z.object({
    arrived_on_time: z.boolean(),
    work_completed: z.boolean(),
    area_cleaned: z.boolean(),
    customer_satisfied: z.boolean(),
  }).nullable(),
  new_rating: z.number().nullable(),
  total_reviews: z.number().nullable(),
  ranking_impact: z.enum(['boost', 'neutral', 'penalty']).nullable(),
});

// Dispute output
export const DisputeOutputSchema = z.object({
  dispute_type: z.string(),
  resolution: z.string().describe('Full resolution explanation for the user'),
  refund_amount: z.number(),
  strikes_after: z.number().nullable(),
  status: z.enum(['resolved', 'pending_user_approval', 'blacklisted']),
  gemini_reasoning: z.string().nullable(),
});
