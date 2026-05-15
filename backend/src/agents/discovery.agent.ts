import fs from 'fs';
import path from 'path';
import { ConfirmedIntent } from '../models/intent.model';
import { Provider, RankedProvider, ScoreBreakdown, DiscoveryAgentOutput } from '../models/discovery.model';

const NEIGHBORS_MAP: Record<string, string[]> = {
  'G-11': ['G-13', 'G-10'],
  'G-13': ['G-11', 'I-8', 'G-10'],
  'G-10': ['G-11', 'G-13'],
  'F-10': ['F-8'],
  'F-8': ['F-10', 'F-7'],
  'F-7': ['F-8'],
  'I-8': ['G-13'],
};

const WEIGHTS = {
  availability: 0.15,
  distance: 0.12,
  rating: 0.12,
  reliability: 0.12,
  specialization: 0.10,
  review_sentiment: 0.07,
  review_recency: 0.07,
  price_vs_budget: 0.08,
  capacity: 0.05,
  cancellation_rate: 0.03,
  user_preference: 0.05,
  risk_score: 0.02,
  nadra_trust: 0.02
};

export class DiscoveryAgent {
  private providers: Provider[] = [];

  constructor() {
    this.loadProviders();
  }

  private loadProviders() {
    try {
      const dataPath = path.resolve(__dirname, '../../data/providers.json');
      if (fs.existsSync(dataPath)) {
        const fileContent = fs.readFileSync(dataPath, 'utf-8');
        this.providers = JSON.parse(fileContent);
      }
    } catch (error) {
      console.error('Failed to load providers:', error);
    }
  }

  // Mock NADRA Database for verification
  private readonly nadraDb: Record<string, boolean> = {
    '4210112345671': true,
    '3520198765432': true,
    '6110187654321': true,
    '3520112233445': true,
    '6110198877665': true,
    '4210187654322': true,
    '3310145678901': false,
    '4220156789012': false,
  };

  public async registerProvider(data: any): Promise<any> {
    const nic = data.nic;
    const isVerified = nic ? (this.nadraDb[nic] === true) : false;

    const newProvider: Provider = {
      id: 'PRV-' + Math.random().toString(36).substring(2, 10).toUpperCase(),
      name: data.name,
      service_types: data.service_types || [],
      blue_tick: isVerified,
      rating: 5.0,
      total_reviews: 0,
      review_sentiment: 'mixed',
      experience_years: data.experience_years || 1,
      area: data.area || 'Islamabad',
      hourly_rate: data.hourly_rate || 500,
      on_time_score: 100,
      cancellation_rate: 0,
      capacity_today: 3,
      risk_score: 'low',
      strikes: 0,
      is_mock: false,
      user_preference_score: 0
    };

    this.providers.push(newProvider);

    try {
      const dataPath = path.resolve(__dirname, '../../data/providers.json');
      fs.writeFileSync(dataPath, JSON.stringify(this.providers, null, 2));
    } catch (e) {
      console.error('Failed to save provider to JSON:', e);
    }

    return {
      status: 'success',
      provider: newProvider,
      message: isVerified ? 'Provider registered and NADRA verified.' : 'Provider registered without NADRA verification.'
    };
  }

  public discover(intent: ConfirmedIntent): DiscoveryAgentOutput {
    // PART A - FILTERING
    const candidates = this.providers.filter(p => {
      // 1. Service Type Match
      if (!p.service_types.includes(intent.service_type)) return false;

      // 2. Area Proximity
      const isExact = p.area === intent.location.area;
      const isNeighbor = NEIGHBORS_MAP[intent.location.area]?.includes(p.area);
      if (!isExact && !isNeighbor) return false;

      // 3. Capacity > 0
      if (p.capacity_today === 0) return false;

      // 4. Exclude high risk + strikes >= 2
      if (p.risk_score === 'high' && p.strikes >= 2) return false;

      return true;
    });

    if (candidates.length === 0) {
      return {
        status: 'no_providers',
        suggestion: 'waitlist',
        next_available_slot: null,
        message: 'Abhi koi provider available nahi. Waitlist mein add karein?'
      };
    }

    // PART B - RANKING
    const ranked: RankedProvider[] = candidates.map(p => this.scoreProvider(p, intent));

    // Sort descending
    ranked.sort((a, b) => b.calculated_score - a.calculated_score);

    // Return top 3
    return {
      status: 'success',
      total_found: ranked.length,
      job_complexity: intent.job_complexity,
      ranked_providers: ranked.slice(0, 3)
    };
  }

  private scoreProvider(p: Provider, intent: ConfirmedIntent): RankedProvider {
    const scores: ScoreBreakdown = {
      availability: 100, // capacity_today > 0 means available for now
      distance: p.area === intent.location.area ? 100 : 50,
      rating: Math.min(100, Math.round(p.rating * 20)),
      reliability: p.on_time_score,
      specialization: this.calcSpecialization(p.experience_years, intent.job_complexity),
      review_sentiment: this.calcSentiment(p.review_sentiment),
      review_recency: Math.min(100, p.total_reviews), // Proxy for now
      price_vs_budget: this.calcPriceVsBudget(p.hourly_rate, intent.budget_sensitive),
      capacity: p.capacity_today >= 3 ? 100 : p.capacity_today === 2 ? 66 : 33,
      cancellation_rate: Math.max(0, 100 - (p.cancellation_rate * 5)),
      user_preference: p.user_preference_score,
      risk_score: p.risk_score === 'low' ? 100 : p.risk_score === 'medium' ? 50 : 0,
      nadra_trust: p.blue_tick ? 100 : 0
    };

    let calculated_score = 0;
    for (const [key, weight] of Object.entries(WEIGHTS)) {
      calculated_score += scores[key as keyof ScoreBreakdown] * weight;
    }

    calculated_score = Math.min(100, Math.round(calculated_score));

    const ranking_reason = this.generateReason(p, intent, scores);

    return {
      ...p,
      calculated_score,
      score_breakdown: scores,
      ranking_reason
    };
  }

  private calcSpecialization(years: number, complexity: string): number {
    if (complexity === 'basic') return 100;
    if (complexity === 'intermediate') return years >= 3 ? 100 : years * 30;
    if (complexity === 'complex') return years >= 5 ? 100 : years * 20;
    return 100;
  }

  private calcSentiment(sentiment: string): number {
    if (sentiment === 'positive') return 100;
    if (sentiment === 'mostly_positive') return 75;
    if (sentiment === 'mixed') return 40;
    return 0;
  }

  private calcPriceVsBudget(rate: number, isSensitive: boolean): number {
    if (!isSensitive) return 100;
    // Lower rate is better. e.g. 500 = 100, 1500 = 0
    return Math.max(0, 100 - Math.max(0, (rate - 500) / 10));
  }

  private generateReason(p: Provider, intent: ConfirmedIntent, scores: ScoreBreakdown): string {
    const isExactArea = scores.distance === 100;
    const isBudgetFriendly = intent.budget_sensitive && scores.price_vs_budget >= 80;
    
    let reason = `${p.name} sabse munasib hai kyunki woh `;
    
    if (isExactArea) {
      reason += `${p.area} mein hai, `;
    } else {
      reason += `${p.area} se qareeb hai, `;
    }

    reason += `${p.experience_years} saal ka tajarba rakhte hain, `;
    reason += `aur inka on-time record ${p.on_time_score}% hai.`;

    if (p.blue_tick) {
      reason += ` (NADRA Verified)`;
    }

    return reason;
  }
}
