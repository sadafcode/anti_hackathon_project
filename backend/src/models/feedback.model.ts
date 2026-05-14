export interface QualityChecklist {
  arrived_on_time: boolean;
  work_completed: boolean;
  area_cleaned: boolean;
  customer_satisfied: boolean;
}

export interface FeedbackInput {
  booking_id: string;
  provider: {
    id: string;
    name: string;
  };
  mock_action: 'on_time' | 'late' | 'no_show';
  feedback?: {
    stars: number;
    comment: string;
  };
}

export interface FeedbackOutput {
  status: 'completed' | 'no_show';
  dispute_triggered?: boolean;
  checklist?: QualityChecklist;
  new_rating?: number;
  total_reviews?: number;
  ranking_impact?: 'boost' | 'neutral' | 'penalty';
}
