import { create } from 'zustand';

interface RecordingsState {
  refreshKey: number;
  triggerRefresh: () => void;
}

export const useRecordingsStore = create<RecordingsState>((set) => ({
  refreshKey: 0,
  triggerRefresh: () => set((state) => ({ refreshKey: state.refreshKey + 1 })),
}));
