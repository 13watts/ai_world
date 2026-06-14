export type ModalitySlug =
  | 'text-llms'
  | 'image-video'
  | 'audio-speech'
  | 'code-agents'
  | 'research-ml'
  | 'infra-mlops'
  | 'governance-safety';

export interface Modality {
  slug: ModalitySlug;
  name: string;
  summary: string;
  examples: string[];
}

export interface FeedSource {
  id: string;
  title: string;
  url: string;
  homepage: string;
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
}

export interface FeedCache {
  updatedAt: string;
  items: FeedItem[];
  errors: Array<{ sourceId: string; message: string; at: string }>;
}
