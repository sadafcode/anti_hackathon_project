import { IntentAgentInput, IntentAgentOutput, PartialIntent, ConfirmedIntent } from '../models/intent.model';
import { NLUResult } from '../models/nlu.model';

export class IntentAgent {
  private sessions = new Map<string, PartialIntent>();

  public process(input: IntentAgentInput): IntentAgentOutput {
    const { nlu_result, session_id } = input;
    
    // Get or initialize session state
    let state = this.sessions.get(session_id) || this.createEmptyState(nlu_result);

    // Merge new fields
    state = this.mergeState(state, nlu_result);

    // Validate fields
    const missingFields = this.getMissingFields(state);

    if (missingFields.length > 0) {
      this.sessions.set(session_id, state); // Save state
      return {
        status: 'incomplete',
        follow_up_needed: true,
        follow_up_question: this.generateFollowUp(missingFields[0], state.language_detected),
        missing_fields: missingFields,
        partial_intent: state
      };
    } else {
      // Clear session
      this.sessions.delete(session_id);

      // We have all fields. Make sure job_complexity is set.
      const finalComplexity = state.job_complexity || 'basic';

      const confirmed: ConfirmedIntent = {
        service_type: state.service_type!,
        location: { area: state.location!.area!, city: state.location!.city },
        datetime: this.convertToISO(state.preferred_time!),
        urgency: state.urgency,
        budget_sensitive: state.budget_sensitive,
        job_complexity: finalComplexity,
        confidence: state.confidence,
        language_detected: state.language_detected
      };

      return {
        status: 'complete',
        follow_up_needed: false,
        follow_up_question: null,
        confirmed_intent: confirmed
      };
    }
  }

  public clearSession(session_id: string): void {
    this.sessions.delete(session_id);
  }

  public getSession(session_id: string): PartialIntent | undefined {
    return this.sessions.get(session_id);
  }

  private createEmptyState(nlu: NLUResult): PartialIntent {
    return {
      service_type: null,
      location: null,
      urgency: 'medium',
      preferred_time: null,
      budget_sensitive: false, // will be updated in mergeState if applicable
      job_complexity: null,
      confidence: nlu.confidence,
      language_detected: nlu.language_detected
    };
  }

  private mergeState(state: PartialIntent, nlu: NLUResult): PartialIntent {
    const entities = nlu.entities;
    if (entities.service_type) state.service_type = entities.service_type;
    
    if (entities.location) {
      if (!state.location) state.location = { ...entities.location };
      else {
        if (entities.location.area) state.location.area = entities.location.area;
        if (entities.location.city) state.location.city = entities.location.city;
        if (entities.location.coordinates) state.location.coordinates = entities.location.coordinates;
      }
    }
    
    if (entities.urgency && entities.urgency !== 'medium') {
      state.urgency = entities.urgency;
    }
    
    if (entities.preferred_time) {
        if (!state.preferred_time) {
             state.preferred_time = { date: null, slot: null };
        }
        if (entities.preferred_time.date) state.preferred_time.date = entities.preferred_time.date;
        if (entities.preferred_time.slot) state.preferred_time.slot = entities.preferred_time.slot;
    }
    
    if (entities.budget) {
      state.budget_sensitive = entities.budget.sensitivity === 'high';
    }
    
    if (entities.job_complexity) state.job_complexity = entities.job_complexity;
    
    // Update language if the new one is not 'unknown'
    if (nlu.language_detected && nlu.language_detected !== 'unknown') {
      state.language_detected = nlu.language_detected;
    }

    // Keep lowest confidence to be safe
    if (nlu.confidence < state.confidence) {
      state.confidence = nlu.confidence;
    }

    return state;
  }

  private getMissingFields(state: PartialIntent): string[] {
    const missing: string[] = [];
    if (!state.service_type) missing.push('service_type');
    if (!state.location || !state.location.area) missing.push('location.area');
    if (!state.preferred_time || (!state.preferred_time.date && !state.preferred_time.slot)) missing.push('preferred_time');
    
    return missing;
  }

  private generateFollowUp(field: string, language: string): string {
    const isEnglish = language === 'english';
    const isUrdu = language === 'urdu';

    switch (field) {
      case 'service_type':
        if (isEnglish) return "What service do you need? (e.g., plumber, electrician, AC repair)";
        if (isUrdu) return "آپ کو کس سروس کی ضرورت ہے؟ (مثلاً پلمبر، الیکٹریشن، اے سی ریپیئر)";
        return "Kya service chahiye? (plumber, electrician, AC repair...)";
      case 'location.area':
        if (isEnglish) return "Where do you need the service? Please specify the area (e.g., G-13, F-10).";
        if (isUrdu) return "آپ کو سروس کہاں چاہیے؟ براہ کرم علاقہ بتائیں (مثلاً G-13، F-10)";
        return "Kahan chahiye? Area batayein (G-13, F-10, etc.)";
      case 'preferred_time':
        if (isEnglish) return "When do you need it? Please provide a date and time.";
        if (isUrdu) return "آپ کو سروس کب چاہیے؟ تاریخ اور وقت بتائیں";
        return "Kab chahiye? Date aur time batayein";
      default:
        if (isEnglish) return "Could you provide more details?";
        if (isUrdu) return "مزید تفصیل بتائیں";
        return "Tafseel batayein";
    }
  }

  private convertToISO(prefTime: { date: string | null; slot: string | null }): string {
    const dateStr = prefTime.date || new Date().toISOString().split('T')[0];
    let hour = '12:00:00';
    switch (prefTime.slot) {
      case 'morning': hour = '09:00:00'; break;
      case 'afternoon': hour = '14:00:00'; break;
      case 'evening': hour = '18:00:00'; break;
      case 'night': hour = '21:00:00'; break;
    }
    return `${dateStr}T${hour}`;
  }
}
