import { writable } from 'svelte/store';

export interface MobilePageState {
  currentPage: 'home' | 'my-jobs' | 'attendance' | 'jobs' | 'job-detail' | 'job-creation';
  pageTitle: string;
  selectedJobId?: string;
}

const initialState: MobilePageState = {
  currentPage: 'home',
  pageTitle: 'Home'
};

export const mobilePageStore = writable<MobilePageState>(initialState);

export function setMobilePage(page: MobilePageState['currentPage'], title: string, jobId?: string) {
  mobilePageStore.set({ currentPage: page, pageTitle: title, selectedJobId: jobId });
}

export function goBackToHome() {
  mobilePageStore.set({ currentPage: 'home', pageTitle: 'Home' });
}
