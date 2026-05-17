/**
 * NLU Agent Output Models
 * Defines the structured output schema for parsed user requests
 */

export interface NLULocation {
  area: string | null;
  city: string;
  coordinates: { lat: number; lng: number } | null;
}

export interface NLUTimePreference {
  date: string | null;       // ISO date string e.g. "2026-05-15"
  slot: 'morning' | 'afternoon' | 'evening' | 'night' | 'anytime' | null;
  flexible: boolean;
  raw_text: string | null;   // Original time text from user e.g. "kal subah"
}

export interface NLUBudget {
  sensitivity: 'low' | 'medium' | 'high';
  max_amount: number | null;
  raw_text: string | null;   // Original budget text e.g. "budget zyada nahi hai"
}

export type ServiceType =
  | 'ac_repair'
  | 'ac_installation'
  | 'ac_servicing'
  | 'electrician'
  | 'plumber'
  | 'carpenter'
  | 'tutor'
  | 'beautician'
  | 'driver'
  | 'mechanic'
  | 'painter'
  | 'cleaning'
  | 'other';

export type Urgency = 'low' | 'medium' | 'high' | 'emergency';

export type Intent =
  | 'book_service'
  | 'check_status'
  | 'cancel_booking'
  | 'give_feedback'
  | 'file_dispute'
  | 'ask_price'
  | 'provider_info'
  | 'greeting'
  | 'unclear';

export interface NLUEntities {
  service_type: ServiceType | null;
  location: NLULocation | null;
  urgency: Urgency;
  preferred_time: NLUTimePreference | null;
  budget: NLUBudget | null;
  complexity_hints: string[];
  additional_details: string | null;
  job_complexity: 'basic' | 'intermediate' | 'complex' | null;
}

export interface NLUResult {
  confidence: number;          // 0–100 integer after scaling
  language_detected: 'urdu' | 'roman_urdu' | 'english' | 'roman_urdu_mixed' | 'urdu_mixed' | 'unknown';
  intent: Intent;
  entities: NLUEntities;
  raw_input: string;
  normalized: string;
  processing_time_ms: number;
  requires_clarification: boolean;
  clarification_question: string | null;
  user_emotion: 'neutral' | 'frustrated' | 'angry' | 'satisfied' | 'confused';
  past_date_error: boolean;
}

export interface NLUAgentInput {
  message: string;
  session_id?: string;
  context?: {
    previous_messages?: string[];
    user_location?: { lat: number; lng: number };
  };
}
