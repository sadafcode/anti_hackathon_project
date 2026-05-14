import { PricingAgentInput, PricingAgentOutput, BudgetAlternative } from '../models/pricing.model';

export class PricingAgent {
  public calculatePrice(input: PricingAgentInput): PricingAgentOutput {
    const { provider, intent, is_returning_user } = input;

    // 1. Base rate
    const baseRate = provider.hourly_rate;

    // 2. Complexity factor
    let complexityMultiplier = 1.0;
    if (intent.job_complexity === 'intermediate') complexityMultiplier = 1.2;
    if (intent.job_complexity === 'complex') complexityMultiplier = 1.5;
    
    const complexityFee = baseRate * complexityMultiplier - baseRate;

    // 3. Urgency fee
    let urgencyPercent = 0;
    if (intent.urgency === 'medium') urgencyPercent = 0.10;
    if (intent.urgency === 'high') urgencyPercent = 0.30;
    if (intent.urgency === 'emergency') urgencyPercent = 0.50;

    const baseWithComplexity = baseRate * complexityMultiplier;
    const urgencyFee = baseWithComplexity * urgencyPercent;

    // 4. Distance cost
    const distanceCost = provider.area === intent.location.area ? 0 : 100;

    // 5. Surge pricing
    let surgeApplied = false;
    let surgeFee = 0;
    const dateObj = new Date(intent.datetime);
    const hour = dateObj.getHours();
    
    if ((hour >= 12 && hour < 15) || (hour >= 18 && hour < 21)) {
      surgeApplied = true;
      surgeFee = baseWithComplexity * 0.10;
    }

    let subtotal = baseWithComplexity + urgencyFee + distanceCost + surgeFee;

    // 6. Loyalty discount
    let loyaltyDiscount = 0;
    if (is_returning_user) {
      loyaltyDiscount = subtotal * 0.05;
      subtotal -= loyaltyDiscount;
    }

    // 7. Platform fee
    // "10% of total (min Rs.100)"
    // Total = Subtotal + PlatformFee
    // If PlatformFee = 10% of Total -> Total = Subtotal / 0.9 -> PlatformFee = Total * 0.1
    let total = subtotal / 0.9;
    let platformFee = total * 0.10;
    if (platformFee < 100) {
      platformFee = 100;
      total = subtotal + 100;
    }

    const providerEarning = total - platformFee;
    const providerPercentage = Math.round((providerEarning / total) * 100);
    const providerPercentageNote = `Provider earns ${providerPercentage}% of the total.`;

    // 8. Breakdown text
    const breakdownText = `
Pricing Breakdown for ${provider.name}:
- Base Rate: Rs. ${baseRate.toFixed(2)}
- Complexity (${intent.job_complexity}): Rs. ${complexityFee.toFixed(2)}
- Urgency (${intent.urgency}): Rs. ${urgencyFee.toFixed(2)}
- Distance Cost: Rs. ${distanceCost.toFixed(2)}
- Surge Pricing: ${surgeApplied ? `Rs. ${surgeFee.toFixed(2)}` : 'Rs. 0.00'}
- Loyalty Discount: -Rs. ${loyaltyDiscount.toFixed(2)}
- Platform Fee: Rs. ${platformFee.toFixed(2)}
-------------------------
Total: Rs. ${total.toFixed(2)}
`.trim();

    // 9. Budget alternative
    let budget_alternative: BudgetAlternative | undefined;
    if (intent.budget_sensitive) {
      const altBase = baseRate;
      let altSurgeFee = 0;
      if (surgeApplied) altSurgeFee = altBase * 0.10;
      let altSubtotal = altBase + 0 /* basic complexity */ + 0 /* low urgency */ + distanceCost + altSurgeFee;
      let altLoyalty = 0;
      if (is_returning_user) {
        altLoyalty = altSubtotal * 0.05;
        altSubtotal -= altLoyalty;
      }
      
      let altTotal = altSubtotal / 0.9;
      let altPlatformFee = altTotal * 0.10;
      if (altPlatformFee < 100) {
        altTotal = altSubtotal + 100;
      }

      budget_alternative = {
        description: "Budget Option: Basic scope with low urgency",
        price: Math.round(altTotal)
      };
    }

    return {
      base_rate: Math.round(baseRate),
      complexity_factor: complexityMultiplier,
      urgency_fee: Math.round(urgencyFee),
      distance_cost: Math.round(distanceCost),
      surge_applied: surgeApplied,
      surge_fee: Math.round(surgeFee),
      loyalty_discount: Math.round(loyaltyDiscount),
      platform_fee: Math.round(platformFee),
      provider_earning: Math.round(providerEarning),
      provider_percentage_note: providerPercentageNote,
      total: Math.round(total),
      breakdown_text: breakdownText,
      budget_alternative: budget_alternative
    };
  }
}
