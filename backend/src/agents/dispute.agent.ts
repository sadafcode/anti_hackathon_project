import fs from 'fs';
import path from 'path';
import { DisputeInput, DisputeOutput } from '../models/dispute.model';
import { Provider } from '../models/discovery.model';

export class DisputeAgent {
  public resolveDispute(input: DisputeInput): DisputeOutput {
    const { dispute_type, original_price = 0, overcharged_amount = 0, extra_charge_amount = 0, hours_before_job = 0 } = input;
    
    let resolution = '';
    let refund_amount = 0;
    let status: 'resolved' | 'pending_user_approval' | 'blacklisted' = 'resolved';
    let strikes_after: number | undefined;

    switch (dispute_type) {
      case 'no_show':
        refund_amount = original_price;
        strikes_after = this.incrementProviderStrikes(input.provider.id);
        
        if (strikes_after >= 3) {
          status = 'blacklisted';
          resolution = `Provider failed to show up. Full refund of Rs. ${refund_amount} issued. Provider has reached 3 strikes and is now blacklisted.`;
        } else {
          resolution = `Provider failed to show up. Full refund of Rs. ${refund_amount} issued. Strike added to provider.`;
        }
        break;

      case 'quality_complaint':
        refund_amount = Math.round(original_price * 0.20);
        resolution = `Quality complaint verified. 20% refund of Rs. ${refund_amount} issued. Provider ranking penalized.`;
        break;

      case 'price_disagreement':
        refund_amount = overcharged_amount;
        resolution = `Price disagreement resolved. Overcharged amount of Rs. ${refund_amount} refunded to user.`;
        break;

      case 'overrun':
        status = 'pending_user_approval';
        refund_amount = 0; // extra charge, not a refund
        resolution = `Job overrun reported by provider. Extra charge of Rs. ${extra_charge_amount} is pending user approval.`;
        break;

      case 'cancellation':
        if (hours_before_job < 2) {
          const penalty = Math.round(original_price * 0.10);
          refund_amount = original_price - penalty;
          resolution = `Late cancellation (< 2 hours). 10% fee applied (Rs. ${penalty}). Refund issued: Rs. ${refund_amount}.`;
        } else {
          refund_amount = original_price;
          resolution = `Cancellation successful. Full refund of Rs. ${refund_amount} issued.`;
        }
        break;

      default:
        resolution = 'Unknown dispute type.';
    }

    return {
      dispute_type,
      resolution,
      refund_amount,
      strikes_after,
      status
    };
  }

  private incrementProviderStrikes(providerId: string): number {
    let newStrikes = 0;
    try {
      const dataPath = path.resolve(__dirname, '../../data/providers.json');
      if (fs.existsSync(dataPath)) {
        const fileContent = fs.readFileSync(dataPath, 'utf-8');
        const providers: Provider[] = JSON.parse(fileContent);
        
        const idx = providers.findIndex(p => p.id === providerId);
        if (idx !== -1) {
          providers[idx].strikes += 1;
          newStrikes = providers[idx].strikes;

          if (newStrikes >= 3) {
            providers[idx].risk_score = 'high';
          }

          fs.writeFileSync(dataPath, JSON.stringify(providers, null, 2));
          console.log(`   ⚖️ Dispute System: Updated profile for ${providers[idx].name}. Strikes=${newStrikes}, Risk=${providers[idx].risk_score}`);
        }
      }
    } catch (e) {
      console.error('Error applying provider strike:', e);
    }
    return newStrikes;
  }
}
