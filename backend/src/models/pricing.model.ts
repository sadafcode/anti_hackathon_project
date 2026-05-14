import { ConfirmedIntent } from './intent.model';
import { RankedProvider } from './discovery.model';

export interface PricingAgentInput {
  provider: RankedProvider;
  intent: ConfirmedIntent;
  is_returning_user: boolean;
}

export interface BudgetAlternative {
  description: string;
  price: number;
}

export interface PricingAgentOutput {
  base_rate: number;
  complexity_factor: number;
  urgency_fee: number;
  distance_cost: number;
  surge_applied: boolean;
  surge_fee: number;
  loyalty_discount: number;
  platform_fee: number;
  provider_earning: number;
  provider_percentage_note: string;
  total: number;
  breakdown_text: string;
  budget_alternative?: BudgetAlternative;
}
