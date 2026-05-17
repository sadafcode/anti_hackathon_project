import { Agent } from '@openai/agents';
import { PricingOutputSchema } from './schemas';
import { tool } from '@openai/agents';
import { z } from 'zod';

// Helper tool: computes raw price components (math only, no AI)
const computePriceComponents = tool({
  name: 'compute_price_components',
  description: 'Compute the raw numeric price components based on booking parameters. Returns numbers only — the agent then formats and explains them.',
  parameters: z.object({
    base_hourly_rate: z.number(),
    job_complexity: z.enum(['basic', 'intermediate', 'complex']),
    urgency: z.enum(['low', 'medium', 'high', 'emergency']),
    is_same_area: z.boolean(),
    requested_hour: z.number().describe('Hour of day 0-23 for peak detection'),
    is_returning_user: z.boolean(),
    budget_sensitive: z.boolean(),
  }),
  execute: async ({ base_hourly_rate, job_complexity, urgency, is_same_area, requested_hour, is_returning_user }) => {
    const complexityMap = { basic: 1.0, intermediate: 1.2, complex: 1.5 };
    const urgencyMap = { low: 0, medium: 0.10, high: 0.30, emergency: 0.50 };

    const complexityFactor = complexityMap[job_complexity];
    const baseWithComplexity = base_hourly_rate * complexityFactor;
    const urgencyFee = Math.round(baseWithComplexity * urgencyMap[urgency]);
    const distanceCost = is_same_area ? 0 : 100;
    const isPeak = (requested_hour >= 12 && requested_hour < 15) || (requested_hour >= 18 && requested_hour < 21);
    const surgeFee = isPeak ? Math.round(baseWithComplexity * 0.10) : 0;

    let subtotal = baseWithComplexity + urgencyFee + distanceCost + surgeFee;
    const loyaltyDiscount = is_returning_user ? Math.round(subtotal * 0.05) : 0;
    subtotal -= loyaltyDiscount;

    let platformFee = Math.round(subtotal / 0.9 * 0.10);
    if (platformFee < 100) platformFee = 100;

    const total = Math.round(subtotal + platformFee);
    const providerEarning = total - platformFee;

    return {
      base_rate: Math.round(base_hourly_rate),
      complexity_factor: complexityFactor,
      base_with_complexity: Math.round(baseWithComplexity),
      urgency_fee: urgencyFee,
      distance_cost: distanceCost,
      surge_applied: isPeak,
      surge_fee: surgeFee,
      loyalty_discount: loyaltyDiscount,
      platform_fee: platformFee,
      provider_earning: providerEarning,
      total,
      provider_percentage: Math.round((providerEarning / total) * 100),
      budget_base_total: Math.round((base_hourly_rate + distanceCost) / 0.9),
    };
  },
});

export const pricingAgent = new Agent({
  name: 'Pricing Agent',
  model: 'gpt-4o-mini',
  outputType: PricingOutputSchema,
  tools: [computePriceComponents],
  instructions: `You are the Pricing Agent for Antigravity — Pakistan's home services platform.

YOUR MISSION: Calculate a fair, transparent, and detailed price quote for a service booking.

STEP 1 — COMPUTE NUMBERS:
Call compute_price_components with:
- base_hourly_rate: from the provider
- job_complexity: from the intent
- urgency: from the intent
- is_same_area: true if provider.area === intent.location.area
- requested_hour: extract hour from intent.datetime ISO string
- is_returning_user: from input
- budget_sensitive: from the intent

STEP 2 — FORMAT THE BREAKDOWN:
Create a clear, readable breakdown_text. Format it line by line like this:
"Base Rate: Rs.800
Complexity (intermediate ×1.2): Rs.160
Urgency (high +30%): Rs.240
Distance: Rs.100
Surge (peak hours): Rs.0
Loyalty Discount: -Rs.0
Platform Fee (10%): Rs.130
─────────────────
Total: Rs.1,430
Provider Earns: Rs.1,300 (91%)"

STEP 3 — PROVIDER PERCENTAGE NOTE:
Write a friendly note emphasizing fairness: the provider earns ~90% — much better than traditional middlemen who take 30-40%.

STEP 4 — BUDGET ALTERNATIVE (only if budget_sensitive=true):
Suggest a simpler/cheaper scope. Example:
- For AC repair: "Budget Option: Basic inspection + gas top-up only (no parts replacement) — saves Rs.400"
- For electrician: "Budget Option: Fix one fault point only, basic materials — saves Rs.200"
Make it practical and genuinely useful.

LANGUAGE RULES:
Detect language from the provider/intent context:
- If intent.language_detected = "english" → breakdown and notes in English
- If "urdu" → use Urdu
- Otherwise → Roman Urdu (Iska breakdown: Rs.800 base rate...)

FAIRNESS PRINCIPLES:
- Never round in ways that benefit the platform over the provider
- Always show all fees explicitly — no hidden charges
- The platform_fee note should always highlight provider's fair earning %

IMPORTANT:
- Use EXACT numbers from compute_price_components — do not make up numbers
- breakdown_text must show the actual calculation, not approximations
- provider_percentage_note must match the actual math`,
});
