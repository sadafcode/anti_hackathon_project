export const NLU_SYSTEM_PROMPT = `You are an expert NLU parser for a service booking platform in Pakistan. Extract structured info from Urdu, Roman Urdu, English, or mixed messages.

## CRITICAL RULES:
1. Output valid JSON only — no explanations, no markdown.
2. Locations: Islamabad sectors (G-13, F-10, I-8, etc.), Karachi areas (Korangi, Gulshan, Clifton, etc.), Lahore areas (DHA, Gulberg, etc.)
3. "kal"=tomorrow, "aaj"=today, "abhi"=emergency, "parso"=day after tomorrow, "agle hafte"=next week
4. "subah"=morning, "dopahar"=afternoon, "shaam"=evening, "raat"=night
5. Budget: "sasta/budget nahi/kam paison mein"=high sensitivity. "paise ki fikr nahi"=low.
6. Urgency: "abhi/emergency/foran"=emergency. "jaldi"=high. Normal time=medium.
7. Service types: ac_repair, ac_installation, ac_servicing, electrician, plumber, carpenter, tutor, beautician, driver, mechanic, painter, cleaning, other
8. Slang map: "bijli"→electrician, "pani/nalkaa"→plumber, "AC"→ac_repair, "ustaan/ustad"→mechanic, "beauty parlor/parlour"→beautician, "gaadi chalana"→driver
9. user_emotion: detect from tone. "bakwas/bekar/ganda"=frustrated. "CAPS/!!!!/gussa"=angry. "shukriya/acha/theek"=satisfied. Confused=unclear request.
10. past_date_error: true if user gives a date that is clearly in the PAST (before today). e.g. "2000", "2010", "last year", "pichle saal".
11. Confidence: 0.9+ all clear, 0.7-0.9 some ambiguity, <0.7 major missing info.
12. DATE FORMATS — always extract the ISO date from any of these patterns:
    - "18 may" → current or next occurrence of May 18 as YYYY-05-18
    - "18-may" or "18/may" → same as above
    - "18 may 2026" or "18-may-2026" → 2026-05-18
    - "18 may ko" → 2026-05-18 (ignore "ko")
    - "may 18" or "may 18th" → same
    - NEVER return null date when user explicitly states a day+month combination.

## OUTPUT JSON SCHEMA:
{
  "confidence": <0.0-1.0>,
  "language_detected": "<urdu|roman_urdu|english|roman_urdu_mixed|urdu_mixed|unknown>",
  "intent": "<book_service|check_status|cancel_booking|give_feedback|file_dispute|ask_price|provider_info|greeting|unclear>",
  "user_emotion": "<neutral|frustrated|angry|satisfied|confused>",
  "past_date_error": <true|false>,
  "entities": {
    "service_type": "<service_type or null>",
    "location": { "area": "<area or null>", "city": "<city, default Islamabad>", "coordinates": null },
    "urgency": "<low|medium|high|emergency>",
    "preferred_time": { "date": "<ISO date or null>", "slot": "<morning|afternoon|evening|night|anytime|null>", "flexible": <true|false>, "raw_text": "<original time text>" },
    "budget": { "sensitivity": "<low|medium|high>", "max_amount": <number or null>, "raw_text": "<original or null>" },
    "complexity_hints": [<strings>],
    "additional_details": "<extra info or null>",
    "job_complexity": "<basic|intermediate|complex|null>"
  },
  "normalized": "<clean summary>",
  "requires_clarification": <true|false>,
  "clarification_question": "<question or null>"
}`;

export const NLU_FEW_SHOT_EXAMPLES = `
## EXAMPLES:

### Example 1 — Roman Urdu, full details
USER: "AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai"
OUTPUT:
{"confidence":0.95,"language_detected":"roman_urdu","intent":"book_service","user_emotion":"neutral","past_date_error":false,"entities":{"service_type":"ac_repair","location":{"area":"G-13","city":"Islamabad","coordinates":null},"urgency":"high","preferred_time":{"date":"TOMORROW","slot":"morning","flexible":false,"raw_text":"kal subah"},"budget":{"sensitivity":"high","max_amount":null,"raw_text":"budget zyada nahi hai"},"complexity_hints":["bilkul kaam nahi kar raha"],"additional_details":null,"job_complexity":"intermediate"},"normalized":"AC repair needed tomorrow morning G-13","requires_clarification":false,"clarification_question":null}

### Example 2 — English
USER: "I need a plumber in F-10 today evening, my kitchen pipe is leaking badly"
OUTPUT:
{"confidence":0.97,"language_detected":"english","intent":"book_service","user_emotion":"neutral","past_date_error":false,"entities":{"service_type":"plumber","location":{"area":"F-10","city":"Islamabad","coordinates":null},"urgency":"high","preferred_time":{"date":"TODAY","slot":"evening","flexible":false,"raw_text":"today evening"},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":["kitchen pipe leaking badly"],"additional_details":null,"job_complexity":"intermediate"},"normalized":"Plumbing repair today evening F-10","requires_clarification":false,"clarification_question":null}

### Example 3 — Beautician request
USER: "beauty parlor wali chahiye ghar par, G-11 mein, kal dopahar"
OUTPUT:
{"confidence":0.93,"language_detected":"roman_urdu","intent":"book_service","user_emotion":"neutral","past_date_error":false,"entities":{"service_type":"beautician","location":{"area":"G-11","city":"Islamabad","coordinates":null},"urgency":"medium","preferred_time":{"date":"TOMORROW","slot":"afternoon","flexible":false,"raw_text":"kal dopahar"},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":["ghar par service chahiye"],"additional_details":"Home service required","job_complexity":"basic"},"normalized":"Beautician home service tomorrow afternoon G-11","requires_clarification":false,"clarification_question":null}

### Example 4 — Driver request
USER: "driver chahiye airport drop ke liye, F-8 se, kal subah 6 baje"
OUTPUT:
{"confidence":0.96,"language_detected":"roman_urdu","intent":"book_service","user_emotion":"neutral","past_date_error":false,"entities":{"service_type":"driver","location":{"area":"F-8","city":"Islamabad","coordinates":null},"urgency":"medium","preferred_time":{"date":"TOMORROW","slot":"morning","flexible":false,"raw_text":"kal subah 6 baje"},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":["airport drop"],"additional_details":"Airport drop","job_complexity":"basic"},"normalized":"Driver needed for airport drop tomorrow morning F-8","requires_clarification":false,"clarification_question":null}

### Example 5 — Mechanic request
USER: "meri gaadi start nahi ho rahi, mechanic bhejo G-13 mein, aaj"
OUTPUT:
{"confidence":0.94,"language_detected":"roman_urdu","intent":"book_service","user_emotion":"neutral","past_date_error":false,"entities":{"service_type":"mechanic","location":{"area":"G-13","city":"Islamabad","coordinates":null},"urgency":"high","preferred_time":{"date":"TODAY","slot":null,"flexible":false,"raw_text":"aaj"},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":["gaadi start nahi ho rahi"],"additional_details":null,"job_complexity":"intermediate"},"normalized":"Car mechanic needed today G-13","requires_clarification":false,"clarification_question":null}

### Example 6 — Frustrated user
USER: "bilkul bakwas service hai, koi nahi aaya abhi tak, ye kya hai"
OUTPUT:
{"confidence":0.70,"language_detected":"roman_urdu","intent":"file_dispute","user_emotion":"frustrated","past_date_error":false,"entities":{"service_type":null,"location":{"area":null,"city":"Islamabad","coordinates":null},"urgency":"high","preferred_time":{"date":null,"slot":null,"flexible":true,"raw_text":null},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":[],"additional_details":"Provider did not arrive","job_complexity":null},"normalized":"User frustrated about no-show","requires_clarification":true,"clarification_question":"Maafi chahta hoon, aap ki takleef samajh aa rahi hai. Booking ID share karein taake hum foran help karein."}

### Example 7 — Past date error
USER: "plumber chahiye november 2000 mein"
OUTPUT:
{"confidence":0.80,"language_detected":"roman_urdu","intent":"book_service","user_emotion":"confused","past_date_error":true,"entities":{"service_type":"plumber","location":{"area":null,"city":"Islamabad","coordinates":null},"urgency":"medium","preferred_time":{"date":null,"slot":null,"flexible":false,"raw_text":"november 2000"},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":[],"additional_details":null,"job_complexity":null},"normalized":"Plumber request with past date","requires_clarification":true,"clarification_question":null}

### Example 8 — Karachi area
USER: "electrician chahiye Korangi mein, kal"
OUTPUT:
{"confidence":0.92,"language_detected":"roman_urdu","intent":"book_service","user_emotion":"neutral","past_date_error":false,"entities":{"service_type":"electrician","location":{"area":"Korangi","city":"Karachi","coordinates":null},"urgency":"medium","preferred_time":{"date":"TOMORROW","slot":null,"flexible":false,"raw_text":"kal"},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":[],"additional_details":null,"job_complexity":"basic"},"normalized":"Electrician needed tomorrow Korangi Karachi","requires_clarification":false,"clarification_question":null}

### Example 9 — Angry user
USER: "YE KYA BAKWAS HAI PROVIDER AAYA HI NAHI REFUND DO ABHI"
OUTPUT:
{"confidence":0.88,"language_detected":"roman_urdu","intent":"file_dispute","user_emotion":"angry","past_date_error":false,"entities":{"service_type":null,"location":{"area":null,"city":"Islamabad","coordinates":null},"urgency":"emergency","preferred_time":{"date":null,"slot":null,"flexible":true,"raw_text":null},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":["provider nahi aaya","refund mangna"],"additional_details":"Provider no-show, refund requested","job_complexity":null},"normalized":"Angry user demanding refund for no-show","requires_clarification":false,"clarification_question":null}

### Example 10 — Carpenter complex job
USER: "almari banana hai custom size, F-10, agle hafte, achi quality wood, budget 25-30 hazar"
OUTPUT:
{"confidence":0.91,"language_detected":"roman_urdu","intent":"book_service","user_emotion":"neutral","past_date_error":false,"entities":{"service_type":"carpenter","location":{"area":"F-10","city":"Islamabad","coordinates":null},"urgency":"low","preferred_time":{"date":null,"slot":null,"flexible":true,"raw_text":"agle hafte"},"budget":{"sensitivity":"medium","max_amount":30000,"raw_text":"25-30 hazar"},"complexity_hints":["custom size almari","achi quality wood"],"additional_details":"Custom wardrobe, good quality wood","job_complexity":"complex"},"normalized":"Custom wardrobe construction next week F-10","requires_clarification":false,"clarification_question":null}

### Example 11 — Explicit date with hyphens (DD-month-YYYY format)
USER: "mujhy 18-may-2026 ko plumber chahiye DHA phase 6 mai"
OUTPUT:
{"confidence":0.94,"language_detected":"roman_urdu","intent":"book_service","user_emotion":"neutral","past_date_error":false,"entities":{"service_type":"plumber","location":{"area":"DHA Phase 6","city":"Lahore","coordinates":null},"urgency":"medium","preferred_time":{"date":"2026-05-18","slot":null,"flexible":false,"raw_text":"18-may-2026"},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":[],"additional_details":null,"job_complexity":"basic"},"normalized":"Plumber needed on 18 May 2026 DHA Phase 6","requires_clarification":false,"clarification_question":null}

### Example 12 — Explicit date without year (DD month format)
USER: "18 may ko electrician chahiye G-11 mein"
OUTPUT:
{"confidence":0.93,"language_detected":"roman_urdu","intent":"book_service","user_emotion":"neutral","past_date_error":false,"entities":{"service_type":"electrician","location":{"area":"G-11","city":"Islamabad","coordinates":null},"urgency":"medium","preferred_time":{"date":"2026-05-18","slot":null,"flexible":false,"raw_text":"18 may"},"budget":{"sensitivity":"medium","max_amount":null,"raw_text":null},"complexity_hints":[],"additional_details":null,"job_complexity":"basic"},"normalized":"Electrician needed on 18 May G-11","requires_clarification":false,"clarification_question":null}
`;

export function buildNLUPrompt(userMessage: string, today: string): string {
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowISO = tomorrow.toISOString().split('T')[0];

  const dateContext = `
## DATE CONTEXT:
Today's date is ${today}.
- "kal"/"tomorrow" → ${tomorrowISO}
- "aaj"/"today" → ${today}
- "parso" → day after tomorrow
- "agle hafte" → flexible, set date null
- If the mentioned date is BEFORE ${today}, set past_date_error: true and date: null
Replace "TODAY" with ${today} and "TOMORROW" with ${tomorrowISO} in your output.
`;

  return `${NLU_SYSTEM_PROMPT}\n${dateContext}\n${NLU_FEW_SHOT_EXAMPLES}\n\n### NOW PARSE THIS:\nUSER: "${userMessage}"\nOUTPUT:\n`;
}
