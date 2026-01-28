export type BadgeType = 'Work' | 'Personal' | 'Inbox';

export interface RecordingCard {
  id: string;
  title: string;
  summary?: string;
  timestamp: string;
  duration: string;
  badge: BadgeType;
  isProcessing: boolean;
  isActive?: boolean;
}

export interface HomeSection {
  title: string;
  recordings: RecordingCard[];
}

export interface HomeData {
  sections: HomeSection[];
}

// Mock data matching the template structure
const mockData: HomeData = {
  sections: [
    {
      title: 'Today',
      recordings: [
        {
          id: '1',
          title: 'New Recording 4',
          timestamp: '10:42 AM',
          duration: '2m 14s',
          badge: 'Inbox',
          isProcessing: true,
        },
        {
          id: '2',
          title: 'Marketing Brainstorm',
          summary:
            'Discussion on Q4 social media strategy. Key points: increase video content, partnership with local influencers, and weekly newsletter revamp.',
          timestamp: '09:15 AM',
          duration: '14m 32s',
          badge: 'Work',
          isProcessing: false,
          isActive: true,
        },
      ],
    },
    {
      title: 'Yesterday',
      recordings: [
        {
          id: '3',
          title: 'Apartment Hunting',
          summary:
            'List of amenities to check: parking space, laundry in-unit, and proximity to the subway station. Budget cap set at $2500.',
          timestamp: '4:20 PM',
          duration: '3m 05s',
          badge: 'Personal',
          isProcessing: false,
        },
        {
          id: '4',
          title: 'Gift Ideas for Mom',
          summary:
            'Potential gifts: gardening kit, new kindle, or a weekend spa voucher. Check delivery times for the kit.',
          timestamp: '1:05 PM',
          duration: '1m 45s',
          badge: 'Personal',
          isProcessing: false,
        },
        {
          id: '5',
          title: 'Client Feedback - Project A',
          summary:
            'Client requested changes to the homepage layout. Wants the hero image to be larger and the CTA button more prominent.',
          timestamp: '10:00 AM',
          duration: '5m 12s',
          badge: 'Work',
          isProcessing: false,
        },
      ],
    },
  ],
};

/**
 * Simulates an async API call to fetch home data
 * @returns Promise that resolves with home data after a delay
 */
export const fetchHomeData = async (): Promise<HomeData> => {
  // Simulate network delay
  await new Promise((resolve) => setTimeout(resolve, 500));

  console.log('teste');
  // Return a copy of the mock data to avoid mutations
  return JSON.parse(JSON.stringify(mockData));
};
