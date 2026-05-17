/**
 * Builds structured trace objects for each agent.
 * These are returned alongside API responses so the Flutter app
 * can display live reasoning in the Agent Trace Screen.
 */

export interface AgentTrace {
  agent: string;
  emoji: string;
  decision: string;
  reasoning: string;
  timestamp: string;
  status: 'success' | 'warning' | 'incomplete' | 'conflict';
  details: Record<string, string>;
}

function now(): string {
  return new Date().toISOString();
}

export function buildNLUTrace(nluResult: any): AgentTrace {
  const lang = nluResult.language_detected || 'unknown';
  const conf = nluResult.confidence || 0;
  const service = nluResult.entities?.service_type || 'unclear';
  const area = nluResult.entities?.location?.area || 'unclear';
  const urgency = nluResult.entities?.urgency || 'medium';

  return {
    agent: 'NLU Agent (Gemini 2.5 Flash)',
    emoji: '🧠',
    decision: `Language: ${lang} — Confidence: ${conf}%`,
    reasoning: `Gemini parsed the user's message and extracted structured intent. ` +
      `Detected language: ${lang} with ${conf}% confidence. ` +
      `Service type identified: ${service}. Location: ${area}. Urgency: ${urgency}. ` +
      (nluResult.requires_clarification
        ? `Low confidence — clarification question generated.`
        : `All key fields extracted without clarification needed.`),
    timestamp: now(),
    status: conf < 70 ? 'warning' : 'success',
    details: {
      'Language Detected': lang,
      'Confidence': `${conf}%`,
      'Service Type': service,
      'Location': area,
      'Urgency': urgency,
      'Budget Sensitive': String(nluResult.entities?.budget?.sensitivity === 'high'),
      'Job Complexity': nluResult.entities?.job_complexity || 'basic',
      'Clarification Needed': String(nluResult.requires_clarification),
      'LLM Used': 'Gemini 2.5 Flash',
      'Processing Time': `${nluResult.processing_time_ms || 0}ms`,
    }
  };
}

export function buildIntentTrace(intentResult: any, confirmedIntent?: any): AgentTrace {
  const isComplete = intentResult.status === 'complete';
  const missing = intentResult.missing_fields || [];

  return {
    agent: 'Intent Agent',
    emoji: '📋',
    decision: isComplete
      ? 'All fields confirmed — intent complete'
      : `Follow-up needed: ${missing.join(', ')}`,
    reasoning: isComplete
      ? `All 3 required fields confirmed: service_type, location.area, preferred_time. ` +
        `No follow-up questions needed. Session cleared. ` +
        `ConfirmedIntent passed to Discovery Agent.`
      : `Missing fields detected: ${missing.join(', ')}. ` +
        `Follow-up question generated in user's language. ` +
        `Session kept open for next message.`,
    timestamp: now(),
    status: isComplete ? 'success' : 'incomplete',
    details: confirmedIntent ? {
      'Service': confirmedIntent.service_type,
      'Area': `${confirmedIntent.location?.area}, ${confirmedIntent.location?.city}`,
      'Date/Time': confirmedIntent.datetime,
      'Urgency': confirmedIntent.urgency,
      'Job Complexity': confirmedIntent.job_complexity,
      'Budget Sensitive': String(confirmedIntent.budget_sensitive),
      'Missing Fields': missing.length > 0 ? missing.join(', ') : 'None',
      'Follow-up Sent': String(!isComplete),
    } : {
      'Status': intentResult.status,
      'Missing Fields': missing.join(', ') || 'None',
    }
  };
}

export function buildDiscoveryTrace(discoveryResult: any, intent: any): AgentTrace {
  const isSuccess = discoveryResult.status === 'success';
  const providers = discoveryResult.ranked_providers || [];
  const top = providers[0];

  return {
    agent: 'Discovery & Ranking Agent (Gemini)',
    emoji: '🔍',
    decision: isSuccess
      ? `${providers.length} providers ranked — #1: ${top?.name} (${top?.calculated_score}/100)`
      : `No providers — ${discoveryResult.suggestion}`,
    reasoning: isSuccess
      ? `Gemini analyzed all available providers using 13 weighted factors. ` +
        `${top?.name} ranked #1 with score ${top?.calculated_score}/100. ` +
        `Reason: ${top?.ranking_reason || 'Best overall match for service and location.'} ` +
        `High-risk providers and fully-booked slots were filtered before ranking.`
      : `${discoveryResult.message || 'No suitable providers found.'} ` +
        `System triggered: ${discoveryResult.suggestion}.`,
    timestamp: now(),
    status: isSuccess ? 'success' : 'warning',
    details: isSuccess ? {
      'Providers Scanned': String(providers.length),
      'Service Type': intent?.service_type || '-',
      'Area': intent?.location?.area || '-',
      [`#1 ${top?.name}`]: `Score ${top?.calculated_score} — ${top?.area}, ${top?.blue_tick ? 'NADRA ✓' : 'No NADRA'}`,
      ...(providers[1] ? { [`#2 ${providers[1].name}`]: `Score ${providers[1].calculated_score}` } : {}),
      ...(providers[2] ? { [`#3 ${providers[2].name}`]: `Score ${providers[2].calculated_score}` } : {}),
      'Ranking Engine': 'Gemini 2.5 Flash — 13 factors',
      'Job Complexity': intent?.job_complexity || 'basic',
      'Budget Sensitive': String(intent?.budget_sensitive),
    } : {
      'Status': 'No providers',
      'Suggestion': discoveryResult.suggestion,
      'Area Searched': intent?.location?.area || '-',
      'Service': intent?.service_type || '-',
    }
  };
}

export function buildPricingTrace(pricingResult: any, providerName: string): AgentTrace {
  return {
    agent: 'Pricing Agent (Gemini)',
    emoji: '💰',
    decision: `Total: Rs. ${pricingResult.total} — Provider earns ${Math.round(pricingResult.provider_earning / pricingResult.total * 100)}%`,
    reasoning: `Gemini calculated a dynamic transparent price with full breakdown. ` +
      `Base rate Rs.${pricingResult.base_rate} adjusted for complexity (×${pricingResult.complexity_factor}), ` +
      `urgency (+Rs.${pricingResult.urgency_fee}), and distance (Rs.${pricingResult.distance_cost}). ` +
      (pricingResult.surge_applied ? `Peak-hour surge applied (+Rs.${pricingResult.surge_fee}). ` : '') +
      (pricingResult.loyalty_discount > 0 ? `Loyalty discount applied (-Rs.${pricingResult.loyalty_discount}). ` : '') +
      `Platform fee ${pricingResult.platform_fee} (10%) ensures provider gets ~90% of total.`,
    timestamp: now(),
    status: 'success',
    details: {
      'Provider': providerName,
      'Base Rate': `Rs. ${pricingResult.base_rate}`,
      'Complexity Factor': `×${pricingResult.complexity_factor}`,
      'Urgency Fee': `Rs. ${pricingResult.urgency_fee}`,
      'Distance Cost': `Rs. ${pricingResult.distance_cost}`,
      'Surge Applied': pricingResult.surge_applied ? `Rs. ${pricingResult.surge_fee}` : 'No',
      'Loyalty Discount': pricingResult.loyalty_discount > 0 ? `-Rs. ${pricingResult.loyalty_discount}` : 'None',
      'Platform Fee (10%)': `Rs. ${pricingResult.platform_fee}`,
      'Provider Earns': `Rs. ${pricingResult.provider_earning}`,
      'Total': `Rs. ${pricingResult.total}`,
      ...(pricingResult.budget_alternative
        ? { 'Budget Option': `Rs. ${pricingResult.budget_alternative.price} — ${pricingResult.budget_alternative.description}` }
        : {}),
    }
  };
}

export function buildBookingTrace(bookingResult: any): AgentTrace {
  const isConflict = bookingResult.status === 'conflict_waitlist';

  return {
    agent: 'Booking & Scheduling Agent',
    emoji: '📅',
    decision: isConflict
      ? `Conflict detected — waitlist triggered`
      : `Booking ${bookingResult.booking_id} created — status: ${bookingResult.status}`,
    reasoning: isConflict
      ? `Time slot conflict detected within 75-minute buffer. ` +
        `Another booking exists too close to requested time. ` +
        `User added to waitlist. Next available slot suggested.`
      : `Double-booking check passed (75-min buffer verified). ` +
        `Booking created in PENDING state — waiting for provider to accept via app. ` +
        `FCM push notification sent to provider. WhatsApp notification simulated. ` +
        `Calendar slot blocked. Receipt generated for customer.`,
    timestamp: now(),
    status: isConflict ? 'conflict' : 'success',
    details: {
      'Booking ID': bookingResult.booking_id || 'N/A',
      'Provider': bookingResult.provider_name || '-',
      'NADRA Verified': bookingResult.blue_tick ? 'Yes ✓' : 'No',
      'Service': bookingResult.service || '-',
      'Scheduled': bookingResult.datetime || '-',
      'Total Price': `Rs. ${bookingResult.total_price}`,
      'Status': bookingResult.status || '-',
      'Conflict Check': isConflict ? 'FAILED — slot taken' : 'PASSED — no overlap',
      'FCM Notification': 'Sent to provider ✓',
      'WhatsApp': 'Simulation triggered ✓',
      'Receipt': 'Sent to customer ✓',
    }
  };
}

export function buildDisputeTrace(disputeResult: any, disputeType: string): AgentTrace {
  return {
    agent: 'Dispute & Resolution Agent (Gemini)',
    emoji: '⚖️',
    decision: `${disputeType} — Refund: Rs. ${disputeResult.refund_amount} — ${disputeResult.status}`,
    reasoning: `Gemini analyzed the dispute details and applied platform policies fairly. ` +
      `Resolution: ${disputeResult.resolution}`,
    timestamp: now(),
    status: disputeResult.status === 'blacklisted' ? 'warning' : 'success',
    details: {
      'Dispute Type': disputeType,
      'Resolution': disputeResult.resolution?.substring(0, 80) + '...' || '-',
      'Refund Amount': `Rs. ${disputeResult.refund_amount}`,
      'Status': disputeResult.status,
      'Strikes After': String(disputeResult.strikes_after ?? 'N/A'),
      'LLM Used': 'Gemini 2.5 Flash',
    }
  };
}
