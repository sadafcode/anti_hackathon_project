/**
 * NLU Agent — Natural Language Understanding for Pakistan's Informal Economy
 *
 * Agent 2 in the orchestrator pipeline.
 * Parses multilingual user input (Urdu, Roman Urdu, English, mixed)
 * and extracts structured intent + entities with confidence scores.
 *
 * Input:  Raw user message (any language)
 * Output: NLUResult with intent, entities, confidence, and clarification needs
 * Tools:  Gemini Flash (via GeminiService)
 */

import { GeminiService } from '../services/gemini.service';
import { buildNLUPrompt } from '../prompts/nlu.prompt';
import { NLUResult, NLUAgentInput } from '../models/nlu.model';

export class NLUAgent {
  private gemini: GeminiService;

  constructor() {
    this.gemini = GeminiService.getInstance();
  }

  /**
   * Main entry point — parse a user message into structured NLU output
   */
  async parse(input: NLUAgentInput): Promise<NLUResult> {
    const startTime = Date.now();

    // Validate input
    if (!input.message || input.message.trim().length === 0) {
      return this.createEmptyResult(input.message, startTime);
    }

    // Build today's date context for relative date resolution
    const today = new Date();
    const todayISO = today.toISOString().split('T')[0]; // "2026-05-14"

    // Build the prompt with few-shot examples
    const prompt = buildNLUPrompt(input.message.trim(), todayISO);

    try {
      // Call Gemini for structured JSON extraction
      const rawResult = await this.gemini.generateJSON<any>(prompt);

      // Post-process and validate the result
      const result = this.validateAndNormalize(rawResult, input.message, startTime);

      // Resolve relative dates (TODAY, TOMORROW placeholders)
      this.resolveDates(result, today);

      return result;
    } catch (error: any) {
      console.error('[NLUAgent] Parse failed:', error.message);

      // Return a low-confidence result instead of crashing
      return this.createFallbackResult(input.message, startTime, error.message);
    }
  }

  /**
   * Validate Gemini output against our schema and fill in defaults
   */
  private validateAndNormalize(raw: any, originalMessage: string, startTime: number): NLUResult {
    const validIntents = [
      'book_service', 'check_status', 'cancel_booking', 'give_feedback',
      'file_dispute', 'ask_price', 'provider_info', 'greeting', 'unclear'
    ];
    const validServiceTypes = [
      'ac_repair', 'ac_installation', 'ac_servicing', 'electrician', 'plumber',
      'carpenter', 'tutor', 'beautician', 'driver', 'mechanic', 'painter',
      'cleaning', 'other'
    ];
    const validUrgency = ['low', 'medium', 'high', 'emergency'];
    const validLanguages = ['urdu', 'roman_urdu', 'english', 'roman_urdu_mixed', 'urdu_mixed', 'unknown'];

    return {
      confidence: typeof raw.confidence === 'number'
        ? Math.round(Math.max(0, Math.min(1, raw.confidence)) * 100)
        : 50,

      language_detected: validLanguages.includes(raw.language_detected)
        ? raw.language_detected
        : 'unknown',

      intent: validIntents.includes(raw.intent)
        ? raw.intent
        : 'unclear',

      entities: {
        service_type: raw.entities?.service_type && validServiceTypes.includes(raw.entities.service_type)
          ? raw.entities.service_type
          : null,

        location: raw.entities?.location ? {
          area: raw.entities.location.area || null,
          city: raw.entities.location.city || 'Islamabad',
          coordinates: raw.entities.location.coordinates || null,
        } : { area: null, city: 'Islamabad', coordinates: null },

        urgency: raw.entities?.urgency && validUrgency.includes(raw.entities.urgency)
          ? raw.entities.urgency
          : 'medium',

        preferred_time: raw.entities?.preferred_time ? {
          date: raw.entities.preferred_time.date || null,
          slot: raw.entities.preferred_time.slot || null,
          flexible: raw.entities.preferred_time.flexible ?? true,
          raw_text: raw.entities.preferred_time.raw_text || null,
        } : null,

        budget: raw.entities?.budget ? {
          sensitivity: ['low', 'medium', 'high'].includes(raw.entities.budget.sensitivity)
            ? raw.entities.budget.sensitivity
            : 'medium',
          max_amount: typeof raw.entities.budget.max_amount === 'number'
            ? raw.entities.budget.max_amount
            : null,
          raw_text: raw.entities.budget.raw_text || null,
        } : { sensitivity: 'medium', max_amount: null, raw_text: null },

        complexity_hints: Array.isArray(raw.entities?.complexity_hints)
          ? raw.entities.complexity_hints
          : [],

        additional_details: raw.entities?.additional_details || null,
        job_complexity: ['basic', 'intermediate', 'complex'].includes(raw.entities?.job_complexity)
          ? raw.entities.job_complexity
          : null,
      },

      raw_input: originalMessage,
      normalized: raw.normalized || 'Unclear request',
      processing_time_ms: Date.now() - startTime,

      requires_clarification: raw.confidence < 0.6 || raw.requires_clarification === true,

      clarification_question: raw.clarification_question || null,
      user_emotion: ['neutral','frustrated','angry','satisfied','confused'].includes(raw.user_emotion)
        ? raw.user_emotion
        : 'neutral',
      past_date_error: raw.past_date_error === true,
    };
  }

  /**
   * Resolve relative date placeholders (TODAY, TOMORROW) to actual ISO dates
   */
  private resolveDates(result: NLUResult, today: Date): void {
    if (!result.entities.preferred_time?.date) return;

    const dateStr = result.entities.preferred_time.date.toUpperCase();

    if (dateStr === 'TODAY') {
      result.entities.preferred_time.date = today.toISOString().split('T')[0];
    } else if (dateStr === 'TOMORROW') {
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);
      result.entities.preferred_time.date = tomorrow.toISOString().split('T')[0];
    }
    // Otherwise keep the date as-is (already ISO format from Gemini)
  }

  /**
   * Create an empty result for blank/null input
   */
  private createEmptyResult(message: string, startTime: number): NLUResult {
    return {
      confidence: 0,
      language_detected: 'unknown',
      intent: 'unclear',
      entities: {
        service_type: null,
        location: { area: null, city: 'Islamabad', coordinates: null },
        urgency: 'medium',
        preferred_time: null,
        budget: { sensitivity: 'medium', max_amount: null, raw_text: null },
        complexity_hints: [],
        additional_details: null,
        job_complexity: null,
      },
      raw_input: message || '',
      normalized: 'Empty request',
      processing_time_ms: Date.now() - startTime,
      requires_clarification: true,
      clarification_question: 'Kya kaam karwana hai? Apni zaroorat batayein.',
      user_emotion: 'neutral',
      past_date_error: false,
    };
  }

  /**
   * Create a fallback result when Gemini call fails
   */
  private createFallbackResult(message: string, startTime: number, error: string): NLUResult {
    return {
      confidence: 10,
      language_detected: 'unknown',
      intent: 'unclear',
      entities: {
        service_type: null,
        location: { area: null, city: 'Islamabad', coordinates: null },
        urgency: 'medium',
        preferred_time: null,
        budget: { sensitivity: 'medium', max_amount: null, raw_text: null },
        complexity_hints: [],
        additional_details: `Parse error: ${error}`,
        job_complexity: null,
      },
      raw_input: message,
      normalized: 'Error parsing request',
      processing_time_ms: Date.now() - startTime,
      requires_clarification: true,
      clarification_question: 'Sorry, samajh nahi aa raha. Dobara batayein kya service chahiye?',
      user_emotion: 'neutral',
      past_date_error: false,
    };
  }
}
