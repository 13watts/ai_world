export type ModalitySlug =
  | 'text-llms'
  | 'image-video'
  | 'audio-speech'
  | 'code-agents'
  | 'research-ml'
  | 'infra-mlops'
  | 'governance-safety';


export type WatchAreaSlug =
  | 'llms'
  | 'agents'
  | 'rag-knowledge'
  | 'multimodal-ai'
  | 'evaluation-benchmarks'
  | 'ai-infrastructure'
  | 'ai-safety-governance'
  | 'data-datasets'
  | 'robotics-embodied-ai'
  | 'edge-on-device-ai';

export interface Modality {
  slug: ModalitySlug;
  name: string;
  summary: string;
  examples: string[];
}


export interface WatchArea {
  slug: WatchAreaSlug;
  name: string;
  summary: string;
  modalitySlugs: ModalitySlug[];
  keywords: string[];
}

export interface FeedSource {
  id: string;
  title: string;
  url: string;
  homepage: string;
  fallbackUrls?: string[];
  enabled?: boolean;
  modalitySlugs: ModalitySlug[];
  tags: string[];
  reliability: 'official' | 'research' | 'editorial' | 'community';
}

export interface FeedItem {
  sourceId: string;
  sourceTitle: string;
  title: string;
  link: string;
  isoDate?: string;
  summary?: string;
  categories: string[];
  modalitySlugs: ModalitySlug[];
  watchAreaSlugs?: WatchAreaSlug[];
}

export interface FeedCache {
  updatedAt: string;
  items: FeedItem[];
  errors: Array<{ sourceId: string; message: string; at: string }>;
}
