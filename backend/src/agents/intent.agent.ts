import { IntentAgentInput, IntentAgentOutput, PartialIntent, ConfirmedIntent } from '../models/intent.model';
import { NLUResult } from '../models/nlu.model';

export class IntentAgent {
  private sessions = new Map<string, PartialIntent>();
  private followUpCounts = new Map<string, Map<string, number>>();
  // Remembers last confirmed intent so budget/service follow-ups work
  private lastConfirmedIntents = new Map<string, ConfirmedIntent>();

  public getLastConfirmedIntent(session_id: string): ConfirmedIntent | undefined {
    return this.lastConfirmedIntents.get(session_id);
  }

  public process(input: IntentAgentInput): IntentAgentOutput {
    const { nlu_result, session_id, raw_message } = input;

    // --- Emotion: calm angry/frustrated users first ---
    const emotion = nlu_result.user_emotion;
    if (emotion === 'angry' || emotion === 'frustrated') {
      return {
        status: 'incomplete',
        follow_up_needed: true,
        follow_up_question: this.getCalmingResponse(emotion, nlu_result.language_detected),
        missing_fields: [],
        partial_intent: this.sessions.get(session_id) || this.createEmptyState(nlu_result)
      };
    }

    // --- Past date error ---
    if (nlu_result.past_date_error) {
      const today = new Date().toLocaleDateString('en-PK', { day: 'numeric', month: 'long', year: 'numeric' });
      const lang = nlu_result.language_detected;
      let msg = '';
      if (lang === 'english') {
        msg = `That date has already passed. Today is ${today}. When would you like the service? You can say "tomorrow", "next week", or any future date.`;
      } else if (lang === 'urdu') {
        msg = `یہ تاریخ گزر چکی ہے۔ آج ${today} ہے۔ آپ کو کب سروس چاہیے؟`;
      } else {
        msg = `Yeh date guzar chuki hai. Aaj ${today} hai. Aap kab chahiye service? "kal", "parso", ya koi future date batayein.`;
      }
      return {
        status: 'incomplete',
        follow_up_needed: true,
        follow_up_question: msg,
        missing_fields: ['preferred_time'],
        partial_intent: this.sessions.get(session_id) || this.createEmptyState(nlu_result)
      };
    }

    // Get or initialize session state
    let state = this.sessions.get(session_id) || this.createEmptyState(nlu_result);
    if (!this.followUpCounts.has(session_id)) {
      this.followUpCounts.set(session_id, new Map());
    }
    const counts = this.followUpCounts.get(session_id)!;

    // Merge new fields from NLU
    state = this.mergeState(state, nlu_result);

    // Regex fallback: extract date if NLU missed it
    if (raw_message) state = this.extractDateFromRaw(raw_message, state);

    // Validate fields
    const missingFields = this.getMissingFields(state);

    if (missingFields.length > 0) {
      const field = missingFields[0];
      const count = counts.get(field) || 0;
      counts.set(field, count + 1);
      this.sessions.set(session_id, state);

      return {
        status: 'incomplete',
        follow_up_needed: true,
        follow_up_question: this.generateFollowUp(field, state.language_detected, count),
        missing_fields: missingFields,
        partial_intent: state
      };
    } else {
      // All fields collected — clear session
      this.sessions.delete(session_id);
      this.followUpCounts.delete(session_id);

      const confirmed: ConfirmedIntent = {
        service_type: state.service_type!,
        location: { area: state.location!.area!, city: state.location!.city || 'Islamabad' },
        datetime: this.convertToISO(state.preferred_time!),
        urgency: state.urgency,
        budget_sensitive: state.budget_sensitive,
        job_complexity: state.job_complexity || 'basic',
        confidence: state.confidence,
        language_detected: state.language_detected
      };

      this.lastConfirmedIntents.set(session_id, confirmed);

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
    this.followUpCounts.delete(session_id);
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
      budget_sensitive: false,
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
      if (!state.preferred_time) state.preferred_time = { date: null, slot: null };
      if (entities.preferred_time.date) state.preferred_time.date = entities.preferred_time.date;
      if (entities.preferred_time.slot) state.preferred_time.slot = entities.preferred_time.slot;
    }

    if (entities.budget) {
      state.budget_sensitive = entities.budget.sensitivity === 'high';
    }

    if (entities.job_complexity) state.job_complexity = entities.job_complexity;

    if (nlu.language_detected && nlu.language_detected !== 'unknown') {
      state.language_detected = nlu.language_detected;
    }

    if (nlu.confidence < state.confidence) {
      state.confidence = nlu.confidence;
    }

    return state;
  }

  private getMissingFields(state: PartialIntent): string[] {
    const missing: string[] = [];
    if (!state.service_type) missing.push('service_type');
    if (!state.location || !state.location.area) missing.push('location.area');
    if (!state.preferred_time || (!state.preferred_time.date && !state.preferred_time.slot)) {
      missing.push('preferred_time');
    }
    return missing;
  }

  private getCalmingResponse(emotion: string, language: string): string {
    const isEnglish = language === 'english';
    const isUrdu = language === 'urdu';

    if (emotion === 'angry') {
      if (isEnglish) return "I completely understand your frustration, and I sincerely apologize. Please tell me what happened and I will make it right immediately.";
      if (isUrdu) return "آپ کی ناراضگی بالکل سمجھ میں آتی ہے، معذرت چاہتا ہوں۔ بتائیں کیا مسئلہ ہوا، فوری حل کریں گے۔";
      return "Aap ki narazgi samajh aa rahi hai, dil se maafi chahta hoon. Bataiye kya masla hua — main abhi hal karta hoon.";
    }

    if (isEnglish) return "I understand your frustration. Let me help you resolve this quickly. Could you share more details about the issue?";
    if (isUrdu) return "آپ کی پریشانی سمجھ آ رہی ہے۔ بتائیں کیا ہوا، فوراً مدد کریں گے۔";
    return "Samajhta hoon aap pareshan hain. Maafi chahta hoon. Bataiye kya hua — hum foran theek karte hain.";
  }

  // Varied follow-up questions based on how many times the field has been asked
  private generateFollowUp(field: string, language: string, count: number): string {
    const isEnglish = language === 'english';
    const isUrdu = language === 'urdu';

    if (field === 'service_type') {
      if (isEnglish) {
        const opts = [
          "What service do you need? (e.g., plumber, electrician, AC repair, beautician, driver, mechanic)",
          "Could you tell me the type of work? Is it electrical, plumbing, AC, carpentry, beauty, driving, or something else?",
          "I want to help — just need to know the service type. What kind of technician or professional do you need?"
        ];
        return opts[Math.min(count, opts.length - 1)];
      }
      if (isUrdu) {
        const opts = [
          "آپ کو کس سروس کی ضرورت ہے؟ (پلمبر، الیکٹریشن، اے سی، بیوٹیشن، ڈرائیور، مکینک)",
          "کیا کام کروانا ہے؟ بجلی، پانی، اے سی، بڑھئی، بیوٹی، یا کچھ اور؟",
          "بس سروس کا نام بتا دیں، باقی ہم سنبھال لیں گے۔"
        ];
        return opts[Math.min(count, opts.length - 1)];
      }
      const opts = [
        "Kya service chahiye? Plumber, electrician, AC repair, beautician, driver, mechanic?",
        "Kaunsa kaam hai? Bijli, paani, AC, carpenter, beauty, gaadi, ya kuch aur — bata dein.",
        "Ek kaam ki zaroorat hai — bas service type batayein, jaise 'plumber' ya 'electrician', aur hum dhundh lete hain."
      ];
      return opts[Math.min(count, opts.length - 1)];
    }

    if (field === 'location.area') {
      if (isEnglish) {
        const opts = [
          "Where do you need the service? Please share your area or sector (e.g., G-13, F-10).",
          "Which area are you in? Islamabad sectors like G-11, F-8, I-8, or your city/neighborhood works too.",
          "Just share your location — even a nearby landmark or your sector number helps us find the closest provider."
        ];
        return opts[Math.min(count, opts.length - 1)];
      }
      if (isUrdu) {
        const opts = [
          "سروس کہاں چاہیے؟ علاقہ یا سیکٹر بتائیں (مثلاً G-13، F-10)",
          "آپ کا علاقہ کون سا ہے؟ G, F, I سیکٹر یا محلے کا نام بھی چلے گا۔",
          "بس علاقہ بتا دیں — قریبی لینڈ مارک یا سیکٹر نمبر سے بھی کام چلے گا۔"
        ];
        return opts[Math.min(count, opts.length - 1)];
      }
      const opts = [
        "Kahan chahiye service? Apna area ya sector batayein — jaise G-13, F-10, I-8.",
        "Area clear nahi hua. G, F, H, I mein kaunsa sector? Ya mohalle ka naam bhi chale ga.",
        "Bas jagah bata dein — chahe landmark ho ya sector number, hum qareeb wala provider dhundh lete hain."
      ];
      return opts[Math.min(count, opts.length - 1)];
    }

    if (field === 'preferred_time') {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      const tomorrowStr = tomorrow.toLocaleDateString('en-GB', { day: 'numeric', month: 'long' });
      const nextWeek = new Date();
      nextWeek.setDate(nextWeek.getDate() + 7);
      const nextWeekStr = nextWeek.toLocaleDateString('en-GB', { day: 'numeric', month: 'long' });

      if (isEnglish) {
        const opts = [
          `When do you need it? You can say 'tomorrow morning', 'today evening', or a date like '${tomorrowStr}'.`,
          `What time works for you? Today, tomorrow, or something like '${nextWeekStr}'? Any preference is fine.`,
          `Almost done! Just share when you need it — even 'anytime this week' works to confirm your booking.`
        ];
        return opts[Math.min(count, opts.length - 1)];
      }
      if (isUrdu) {
        const opts = [
          `کب چاہیے؟ 'کل صبح'، 'آج شام'، یا '${tomorrowStr}' جیسی تاریخ بتائیں۔`,
          `کوئی بھی وقت بتا دیں — آج، کل، یا '${nextWeekStr}' — جو آپ کے لیے ٹھیک ہو۔`,
          `بس وقت بتا دیں، بکنگ ہو جائے گی۔ 'اس ہفتے کبھی بھی' بھی چلے گا۔`
        ];
        return opts[Math.min(count, opts.length - 1)];
      }
      const opts = [
        `Kab chahiye? 'Kal subah', 'aaj sham', ya '${tomorrowStr}' jaise koi date — kuch bhi batayein.`,
        `Waqt batayein. Aaj, kal, ya phir '${nextWeekStr}'? Jo bhi aap ke liye theek ho.`,
        `Sirf time batayein, booking ho jaye gi. 'Is hafte mein kabhi bhi' bhi chale ga.`
      ];
      return opts[Math.min(count, opts.length - 1)];
    }

    return language === 'english'
      ? "Could you provide more details?"
      : language === 'urdu'
        ? "مزید تفصیل بتائیں"
        : "Thodi aur detail chahiye.";
  }

  private extractDateFromRaw(raw: string, state: PartialIntent): PartialIntent {
    if (state.preferred_time?.date) return state;

    const lower = raw.toLowerCase();
    const monthMap: Record<string, number> = {
      jan: 1, january: 1, feb: 2, february: 2, mar: 3, march: 3,
      apr: 4, april: 4, may: 5, jun: 6, june: 6, jul: 7, july: 7,
      aug: 8, august: 8, sep: 9, sept: 9, september: 9,
      oct: 10, october: 10, nov: 11, november: 11, dec: 12, december: 12
    };

    // Matches: "18 may", "18-may", "18/may", "18 may 2026", "18-may-2026", "may 18", "may 18th"
    const pattern = /\b(?:(\d{1,2})[-\/\s](jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)|(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?)(?:[-\/\s](\d{4}))?\b/i;

    const match = lower.match(pattern);
    if (!match) return state;

    let day: number;
    let monthStr: string;
    let year: number;

    if (match[1] && match[2]) {
      // DD month [YYYY]
      day = parseInt(match[1], 10);
      monthStr = match[2].substring(0, 3);
      year = match[5] ? parseInt(match[5], 10) : new Date().getFullYear();
    } else if (match[3] && match[4]) {
      // month DD [YYYY]
      monthStr = match[3].substring(0, 3);
      day = parseInt(match[4], 10);
      year = match[5] ? parseInt(match[5], 10) : new Date().getFullYear();
    } else {
      return state;
    }

    const monthNum = monthMap[monthStr];
    if (!monthNum || day < 1 || day > 31) return state;

    const dateISO = `${year}-${String(monthNum).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

    if (!state.preferred_time) state.preferred_time = { date: null, slot: null };
    state.preferred_time.date = dateISO;

    return state;
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
