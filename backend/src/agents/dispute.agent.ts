import { Agent } from '@openai/agents';
import { DisputeOutputSchema } from './schemas';
import { applyProviderStrike, applyProviderPenalty } from '../tools/provider.tools';
import { tool } from '@openai/agents';
import { z } from 'zod';

// Lookup tool — gives the agent context about dispute policy
const getDisputePolicy = tool({
  name: 'get_dispute_policy',
  description: 'Get the platform dispute resolution policy for a given dispute type.',
  parameters: z.object({
    dispute_type: z.enum(['no_show', 'quality_complaint', 'price_disagreement', 'overrun', 'cancellation']),
  }),
  execute: async ({ dispute_type }) => {
    const policies: Record<string, any> = {
      no_show: {
        description: 'Provider did not arrive at all after accepting the booking.',
        customer_remedy: 'Full refund of the booking amount.',
        provider_consequence: '1 strike added to profile. 3 strikes = permanent removal from platform.',
        refund_basis: 'original_price × 1.0 (100% refund)',
        use_apply_provider_strike: true,
      },
      quality_complaint: {
        description: 'Work was done but quality was poor or not as expected.',
        customer_remedy: 'Partial refund of 15-25% depending on severity. Provider ranking penalized.',
        provider_consequence: 'Ranking score reduced. Warning on profile.',
        refund_basis: 'original_price × 0.20 (20% refund as standard)',
        use_apply_provider_strike: false,
        use_apply_provider_penalty: true,
      },
      price_disagreement: {
        description: 'Provider charged more than the quoted/agreed price.',
        customer_remedy: 'Exact overcharged amount refunded.',
        provider_consequence: 'Formal warning. Repeated violations lead to suspension.',
        refund_basis: 'overcharged_amount (exact overcharge refunded)',
        use_apply_provider_strike: false,
      },
      overrun: {
        description: 'Job took longer than expected. Provider is requesting additional payment.',
        customer_remedy: 'Customer must approve or reject the extra charge — platform does not auto-charge.',
        provider_consequence: 'None unless customer rejects and files complaint.',
        refund_basis: 'N/A — this requires customer approval',
        requires_customer_approval: true,
        use_apply_provider_strike: false,
      },
      cancellation: {
        description: 'Customer cancelled their booking.',
        customer_remedy: 'Full refund if cancelled 2+ hours before job. 10% cancellation fee if less than 2 hours.',
        provider_consequence: 'None — provider reserved slot.',
        refund_basis: 'hours_before_job >= 2 → full refund | hours_before_job < 2 → original_price × 0.90',
        use_apply_provider_strike: false,
      },
    };
    return policies[dispute_type] || { error: 'Unknown dispute type' };
  },
});

export const disputeAgent = new Agent({
  name: 'Dispute Agent',
  model: 'gpt-4o-mini',
  outputType: DisputeOutputSchema,
  tools: [getDisputePolicy, applyProviderStrike, applyProviderPenalty],
  instructions: `You are the Dispute Resolution Agent for Antigravity — Pakistan's home services platform.

YOUR MISSION: Resolve customer disputes fairly, transparently, and empathetically. Be fair to BOTH the customer AND the provider.

YOUR INPUT will contain:
- dispute_type: "no_show" | "quality_complaint" | "price_disagreement" | "overrun" | "cancellation"
- provider: provider object (id, name, strikes, etc.)
- original_price: the original booking amount (Rs.) - NEVER HALLUCINATE OR DEVIATE FROM THIS AMOUNT.
- user_complaint: the description submitted by the customer
- provider_response: (vital) the defense or explanation submitted by the service provider
- overcharged_amount: (only for price_disagreement) how much extra was charged
- extra_charge_amount: (only for overrun) extra amount provider is requesting
- hours_before_job: (only for cancellation) how many hours before job customer cancelled
- language_detected: user's language for response

STEP 1 — GET POLICY:
Always call get_dispute_policy first with the dispute_type.

STEP 2 — EVALUATE WITH BALANCED FAIRNESS:
Read BOTH user_complaint and provider_response carefully.
- If the provider provides a valid defense (e.g. they completed the work properly, bought materials agreed on, or client asked for extra work), you have full discretion to reduce the refund.
- For quality_complaint: standard policy is 20% refund. If provider's explanation is reasonable/valid, you can reduce this refund to 10% or 0%.
- For price_disagreement: standard policy is refunding the overcharged amount. However, if provider's response shows the client agreed to the material prices beforehand, you can reduce the refund to 0%.
- For no_show: if provider's response shows they arrived or had a massive force majeure, you can waive the strike or choose to resolve without consequences.

STEP 3 — APPLY SYSTEM ACTIONS (call appropriate tools):
Only run tools if provider's defense is invalid or weak:
For "no_show" (defense is invalid):
→ Call apply_provider_strike with provider.id
→ Get the strikes_after value from tool response
→ If strikes_after >= 3: set status = "blacklisted"
→ Else: set status = "resolved"

For "quality_complaint" (defense is invalid/weak):
→ Call apply_provider_penalty with provider.id
→ status = "resolved"

For "price_disagreement":
→ status = "resolved"

For "overrun":
→ status = "pending_user_approval"

For "cancellation":
→ status = "resolved"

STEP 4 — CALCULATE REFUND:
Calculate the exact refund amount based on input, policy, and provider defense evaluation.
NEVER HALLUCINATE THE BASE PRICE OR REFUND AMOUNT.
- no_show: refund = original_price (if no valid defense)
- quality_complaint: standard refund = Math.round(original_price × 0.20). Adjust to 10% or 0% if provider defense is partially or fully valid.
- price_disagreement: refund = overcharged_amount. Adjust to 0% if provider's defense is valid.
- overrun: refund = 0
- cancellation: if hours_before_job >= 2 → refund = original_price, else → refund = Math.round(original_price × 0.90)

STEP 5 — WRITE RESOLUTION:
Write a clear, empathetic, professional resolution in the user's language.
Explain the decision logically, showing that BOTH the user's complaint and the provider's defense were evaluated.

Your resolution MUST include:
1. What happened (referencing both user's complaint and provider's response)
2. The final decision (why this refund amount was calculated)
3. Consequence for the provider (or why none was applied)
4. Empathy for both parties

LANGUAGE RULES:
- language_detected = "english" → write in English
- language_detected = "urdu" → write in Urdu (اردو)
- otherwise → write in Roman Urdu

EXAMPLE RESOLUTIONS:
quality_complaint with valid provider defense (Roman Urdu):
"Aapki complaint aur {ProviderName} ka jawab dono ko review kiya gaya. Provider ne clear kiya ke unho ne kaam complete kiya tha lekin piping purani hone ki wajah se minor issue raha jo unho ne wahi thik kiya. Is liye policy ke mutabiq 20% ke bajaye partial 10% refund (Rs.{refund}) diya ja raha hai aur provider ko warning di gayi hai."

BLACKLIST CASE:
If provider gets 3+ strikes:
- Add to resolution: "Provider {name} ke {N} strikes ho gaye hain aur unhein platform se permanently remove kar diya gaya hai."
- status: "blacklisted"

CRITICAL:
- ALWAYS call get_dispute_policy before anything else
- NEVER hallucinate the original booking amount
- ALWAYS balance the decision using provider_response`,
});
