/**
 * Returns a language instruction block for Gemini prompts.
 * Forces Gemini to reply in the exact same language the user used.
 */
export function getLanguageInstruction(lang: string): string {
  switch (lang) {
    case 'english':
      return `LANGUAGE RULE (MANDATORY):
The user wrote in ENGLISH. You MUST write ALL text fields in your JSON response (ranking_reason, breakdown_text, budget_alternative description, resolution, gemini_reasoning) in clear, professional English only.
Do NOT use Urdu script or Roman Urdu anywhere in your response.`;

    case 'urdu':
      return `LANGUAGE RULE (MANDATORY):
The user wrote in URDU SCRIPT (اردو). You MUST write ALL text fields in your JSON response (ranking_reason, breakdown_text, budget_alternative description, resolution, gemini_reasoning) in proper Urdu script only.
مثال: "علی حسن بہترین انتخاب ہیں کیونکہ..."
Do NOT use Roman Urdu (Latin letters) or English anywhere in your text fields.`;

    case 'roman_urdu':
    case 'roman_urdu_mixed':
      return `LANGUAGE RULE (MANDATORY):
The user wrote in ROMAN URDU (Urdu written in English/Latin letters). You MUST write ALL text fields in your JSON response (ranking_reason, breakdown_text, budget_alternative description, resolution, gemini_reasoning) in Roman Urdu only.
Example: "Ali Hassan best choice hai kyunki woh G-13 mein hai aur unka record acha hai..."
Do NOT use Urdu script (اردو حروف) or formal English sentences. Write exactly as someone would type Urdu on a phone keyboard.`;

    case 'urdu_mixed':
      return `LANGUAGE RULE (MANDATORY):
The user wrote in a mix of Urdu script and Roman Urdu. You MUST write ALL text fields in your JSON response in Roman Urdu (Urdu in Latin letters), as it is most accessible for mixed-language users.
Example: "Ali Hassan sabse acha option hai kyunki..."
Do NOT use pure Urdu script only.`;

    default:
      return `LANGUAGE RULE (MANDATORY):
The user's language could not be clearly identified. Use ROMAN URDU as the default language for ALL text fields in your JSON response.
Example: "Ali Hassan best choice hai kyunki woh qareeb hai aur rating achi hai..."
Do NOT use Urdu script. Do NOT use formal English.`;
  }
}
