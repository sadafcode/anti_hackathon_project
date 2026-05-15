import fs from 'fs';
import path from 'path';
import { QualityChecklist, FeedbackInput, FeedbackOutput } from '../models/feedback.model';
import { Provider } from '../models/discovery.model';

export class FeedbackAgent {
  public async processFeedback(input: FeedbackInput): Promise<FeedbackOutput> {
    console.log(`\n🚗 Provider ${input.provider.name} is en-route...`);
    // 1. Mock travel delay
    await new Promise(r => setTimeout(r, 2000));

    // 2. Handle NO SHOW
    if (input.mock_action === 'no_show') {
      console.log(`❌ Provider ${input.provider.name} did not show up!`);
      this.applyNoShowPenalty(input.provider.id);
      return {
        status: 'no_show',
        dispute_triggered: true
      };
    }

    // 3. Run Checklist for arrived jobs
    console.log(`✅ Provider arrived. Running quality checklist...`);
    const checklist: QualityChecklist = {
      arrived_on_time: input.mock_action === 'on_time',
      work_completed: true,
      area_cleaned: true,
      customer_satisfied: true
    };

    if (!input.feedback) {
      throw new Error('Feedback (stars/comment) is required for completed jobs.');
    }

    const { stars } = input.feedback;

    // 4. Determine ranking impact
    let ranking_impact: 'boost' | 'neutral' | 'penalty' = 'neutral';
    if (stars >= 4) ranking_impact = 'boost';
    if (stars <= 2) ranking_impact = 'penalty';

    // 5. Update rating & on-time stats
    const updatedStats = this.updateProviderStats(input.provider.id, stars, checklist.arrived_on_time);

    return {
      status: 'completed',
      checklist,
      new_rating: updatedStats.new_rating,
      total_reviews: updatedStats.total_reviews,
      ranking_impact
    };
  }

  private applyNoShowPenalty(providerId: string) {
    try {
      const dataPath = path.resolve(__dirname, '../../data/providers.json');
      if (fs.existsSync(dataPath)) {
        const fileContent = fs.readFileSync(dataPath, 'utf-8');
        const providers: Provider[] = JSON.parse(fileContent);
        
        const idx = providers.findIndex(p => p.id === providerId);
        if (idx !== -1) {
          providers[idx].cancellation_rate += 1;
          providers[idx].on_time_score = Math.max(0, providers[idx].on_time_score - 10);
          fs.writeFileSync(dataPath, JSON.stringify(providers, null, 2));
          console.log(`   📉 No Show Penalty logged: cancellation_rate=${providers[idx].cancellation_rate}, reliability=${providers[idx].on_time_score}`);
        }
      }
    } catch (e) {
      console.error('Error applying no_show penalty:', e);
    }
  }

  private updateProviderStats(providerId: string, stars: number, arrivedOnTime: boolean) {
    let new_rating = 0;
    let total_reviews = 0;

    try {
      const dataPath = path.resolve(__dirname, '../../data/providers.json');
      if (fs.existsSync(dataPath)) {
        const fileContent = fs.readFileSync(dataPath, 'utf-8');
        const providers: Provider[] = JSON.parse(fileContent);
        
        const idx = providers.findIndex(p => p.id === providerId);
        if (idx !== -1) {
          const oldRating = providers[idx].rating;
          const oldTotal = providers[idx].total_reviews;
          
          new_rating = Number((((oldRating * oldTotal) + stars) / (oldTotal + 1)).toFixed(2));
          total_reviews = oldTotal + 1;

          providers[idx].rating = new_rating;
          providers[idx].total_reviews = total_reviews;

          // If late, small penalty to on_time_score
          if (!arrivedOnTime) {
             providers[idx].on_time_score = Math.max(0, providers[idx].on_time_score - 2);
          }

          fs.writeFileSync(dataPath, JSON.stringify(providers, null, 2));
          console.log(`   🌟 Updated Profile: new_rating=${new_rating}, total_reviews=${total_reviews}`);
        }
      }
    } catch (e) {
      console.error('Error updating provider stats:', e);
    }

    return { new_rating, total_reviews };
  }
}
