import { run, MemorySession } from '@openai/agents';
import { orchestratorAgent } from '../agents/orchestrator.agent';
import { ChatOutputSchema } from '../agents/schemas';
import { z } from 'zod';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

// Mirrors the logic in api.routes.ts
function detectMessageLanguage(text: string): string {
  const hasUrduScript = /[؀-ۿ]/.test(text);
  const romanUrduGrammar = /\b(mujhe|mujhy|mujhey|chahiye|chahiyay|chahte|hain|hun|hoon|tha|thi|thay|kyun|kyunke|kahan|kab|kaise|aur|ya|bhi|sirf|abhi|kal|parso|subah|sham|dopahar|raat|phir|lekin|agar|jab|jahan|woh|yeh|inhe|unhe|mera|meri|apna|apni|bilkul|zaroor|shukriya|meherbani|achha|acha|theek|nahi|nahin|ko|se|ne|ka|ki|ke|batadiya|bataya|batao|bata|pori|poori|sara|sari|karo|karna|karta|karti|karte|gaya|gayi|aya|ayi|aao|jao|lena|lelo|dena|dedo|hogaya|hojao|hojaega|samajh|samjho|dekho|dekhna|suno|sun|pata|maloom|zaroor|theek|bilkul|acha|haan|han|nahi|nahin|milta|milti|lagta|lagti|rakho|rakh|dono|saath|abhi|foran|jaldi|dair|baaqi|upar|neeche|andar|bahar|pehle|baad|phir|dobara|zyada|kam|alag|wahi|yahi|koi|kuch|sab|har|sirf|bas)\b/i;
  const hasRomanUrdu = romanUrduGrammar.test(text);
  const englishFunctionWords = /\b(yes|no|ok|sure|confirm|i'm|i've|the|a\b|an\b|is\b|are\b|was\b|have|has|would|should|my|your|this|that|please|hello|thank|thanks)\b/i;
  const hasEnglishFunctionWords = englishFunctionWords.test(text);

  if (hasUrduScript) return hasEnglishFunctionWords ? 'urdu_mixed' : 'urdu';
  if (hasRomanUrdu) return 'roman_urdu';
  if (hasEnglishFunctionWords) return 'english';
  return 'english';
}

function isReplyInCorrectLanguage(reply: string, lang: string): boolean {
  const hasUrduScript = /[؀-ۿ]/.test(reply);
  const romanUrduMarkers = /\b(bilkul|zaroor|ji\b|haan|nahi|nahin|chahiye|zaroorat|hain|hun|kal|aaj|subah|sham|aap\b|tum|hum|kya|kahan|kab|theek|acha|mujhe|mein\b|ka\b|ki\b|ke\b|ko\b|se\b)\b/i;
  const hasRomanUrdu = romanUrduMarkers.test(reply);

  if (lang === 'english') return !hasUrduScript && !hasRomanUrdu;
  if (lang === 'urdu') return hasUrduScript;
  if (lang === 'roman_urdu') return hasRomanUrdu && !hasUrduScript; // ← THE BUG WAS HERE: was just `return true`
  return true;
}

const LABEL: Record<string, string> = {
  english: 'ENGLISH',
  roman_urdu: 'ROMAN URDU',
  urdu: 'URDU SCRIPT',
  roman_urdu_mixed: 'ROMAN URDU MIXED',
};

// Test cases: [description, messages array (multi-turn conversation)]
const TEST_CASES: Array<{ desc: string; turns: string[] }> = [
  {
    desc: 'Roman Urdu — tutor with English service name (the original bug)',
    turns: [
      'mujhe a-10 gulshan block 4 may english ki tutor chahiya kal 8 class ki bachi kay liya shaam may 6 baje',
      'batadiya hi pori detail',
    ],
  },
  {
    desc: 'English — full booking request',
    turns: [
      'I need a plumber at House 5 Street 3 F-10 tomorrow morning',
      'yes that is correct',
    ],
  },
  {
    desc: 'Roman Urdu — AC repair',
    turns: [
      'AC bilkul kaam nahi kar raha kal subah G-13 mein technician chahiye',
      'House 7 gali 2 G-13',
      'haan sahi hai',
    ],
  },
  {
    desc: 'Urdu script',
    turns: [
      'مجھے پلمبر چاہیے گھر نمبر 5 ایف ٹین میں کل صبح',
      'ہاں ٹھیک ہے',
    ],
  },
  {
    desc: 'Roman Urdu — English tutor (full flow)',
    turns: [
      'english ka tutor chahiye kal sham ko',
      'House 12, Street 4, DHA Phase 5',
      'class 9 ka bacha hai',
      'theek hai confirm kar do',
    ],
  },
];

async function runTestCase(desc: string, turns: string[]) {
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`TEST: ${desc}`);
  console.log('═'.repeat(60));

  // Each test case gets its own fresh MemorySession (same as API route)
  const session = new MemorySession();

  for (let i = 0; i < turns.length; i++) {
    const userMsg = turns[i];
    const detectedLang = detectMessageLanguage(userMsg);
    const langLabel = LABEL[detectedLang] || detectedLang.toUpperCase();

    const now = new Date();
    const todayISO = now.toISOString().split('T')[0];
    const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const tomorrowDate = new Date(now);
    tomorrowDate.setDate(now.getDate() + 1);
    const tomorrowISO = tomorrowDate.toISOString().split('T')[0];

    const promptWithLang = `[LANGUAGE: ${langLabel} — REPLY IN ${langLabel} ONLY]\n[TODAY: ${todayISO} (${days[now.getDay()]}) | TOMORROW: ${tomorrowISO} (${days[tomorrowDate.getDay()]})]\n${userMsg}`;

    try {
      const result = await run(orchestratorAgent, promptWithLang, { session, maxTurns: 10 });
      const rawOutput = result.finalOutput as z.infer<typeof ChatOutputSchema>;
      const reply = rawOutput?.reply || '(no reply)';

      // Check language
      const correct = isReplyInCorrectLanguage(reply, detectedLang);
      const status = correct ? '✅' : '❌ WRONG LANGUAGE';

      console.log(`\nTurn ${i + 1}:`);
      console.log(`  User (${detectedLang}): "${userMsg}"`);
      console.log(`  Reply: "${reply}"`);
      console.log(`  Status: ${status} | Agent status: ${rawOutput?.status}`);

      // Stop if booking complete
      if (rawOutput?.status === 'complete') {
        console.log('  → Booking confirmed, stopping.');
        break;
      }
    } catch (err: any) {
      console.log(`  Error on turn ${i + 1}: ${err.message}`);
      break;
    }
  }
}

async function main() {
  console.log('Language Switch Test — KhidmatBot Orchestrator');
  console.log(`Running ${TEST_CASES.length} test cases...\n`);

  for (const tc of TEST_CASES) {
    await runTestCase(tc.desc, tc.turns);
  }

  console.log(`\n${'═'.repeat(60)}`);
  console.log('All tests done.');
}

main().catch(console.error);
