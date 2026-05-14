import { NLUResult, ServiceType, NLULocation, Urgency } from './nlu.model';

export interface IntentAgentInput {
  nlu_result: NLUResult;
  session_id: string;
}

export interface PartialIntent {
  service_type: ServiceType | null;
  location: NLULocation | null;
  urgency: Urgency;
  preferred_time: {
    date: string | null;
    slot: string | null;
  } | null;
  budget_sensitive: boolean;
  job_complexity: 'basic' | 'intermediate' | 'complex' | null;
  confidence: number;
  language_detected: string;
}

export interface ConfirmedIntent {
  service_type: ServiceType;
  location: { area: string; city: string };
  datetime: string;
  urgency: Urgency;
  budget_sensitive: boolean;
  job_complexity: 'basic' | 'intermediate' | 'complex';
  confidence: number;
  language_detected: string;
}

export interface IntentAgentOutput {
  status: 'complete' | 'incomplete';
  follow_up_needed: boolean;
  follow_up_question: string | null;
  missing_fields?: string[];
  partial_intent?: PartialIntent;
  confirmed_intent?: ConfirmedIntent;
}
