import { modalities } from '../config/modalities.js';
import type { FeedSource, ModalitySlug } from '../types/content.js';

type WeightedTerm = { term: string; weight: number };

const modalitySignals: Record<ModalitySlug, WeightedTerm[]> = {
  'text-llms': [
    { term: 'llm', weight: 4 }, { term: 'large language model', weight: 5 }, { term: 'language model', weight: 4 },
    { term: 'chatbot', weight: 3 }, { term: 'assistant', weight: 3 }, { term: 'rag', weight: 5 },
    { term: 'retrieval augmented', weight: 5 }, { term: 'prompt', weight: 3 }, { term: 'context window', weight: 3 },
    { term: 'reasoning model', weight: 4 }, { term: 'token', weight: 2 }, { term: 'nlp', weight: 3 }
  ],
  'image-video': [
    { term: 'image generation', weight: 5 }, { term: 'video generation', weight: 5 }, { term: 'vision', weight: 4 },
    { term: 'computer vision', weight: 5 }, { term: 'multimodal', weight: 4 }, { term: 'diffusion', weight: 4 },
    { term: 'sora', weight: 4 }, { term: 'imagen', weight: 4 }, { term: 'visual', weight: 3 }, { term: 'synthetic media', weight: 4 }
  ],
  'audio-speech': [
    { term: 'speech', weight: 5 }, { term: 'audio', weight: 5 }, { term: 'voice', weight: 4 },
    { term: 'text to speech', weight: 5 }, { term: 'speech to text', weight: 5 }, { term: 'tts', weight: 5 },
    { term: 'stt', weight: 5 }, { term: 'transcription', weight: 4 }, { term: 'whisper', weight: 4 }, { term: 'music generation', weight: 4 }
  ],
  'code-agents': [
    { term: 'agent', weight: 4 }, { term: 'agents', weight: 4 }, { term: 'coding assistant', weight: 5 },
    { term: 'code generation', weight: 5 }, { term: 'developer', weight: 3 }, { term: 'software engineering', weight: 4 },
    { term: 'tool calling', weight: 5 }, { term: 'function calling', weight: 4 }, { term: 'mcp', weight: 5 },
    { term: 'automation', weight: 4 }, { term: 'computer use', weight: 5 }, { term: 'workflow', weight: 3 }
  ],
  'research-ml': [
    { term: 'paper', weight: 5 }, { term: 'papers', weight: 5 }, { term: 'research', weight: 5 },
    { term: 'benchmark', weight: 4 }, { term: 'dataset', weight: 4 }, { term: 'training', weight: 4 },
    { term: 'model architecture', weight: 5 }, { term: 'evaluation', weight: 4 }, { term: 'arxiv', weight: 5 },
    { term: 'machine learning', weight: 5 }, { term: 'deep learning', weight: 4 }
  ],
  'infra-mlops': [
    { term: 'inference', weight: 5 }, { term: 'gpu', weight: 5 }, { term: 'accelerator', weight: 4 },
    { term: 'serving', weight: 4 }, { term: 'deployment', weight: 4 }, { term: 'vector database', weight: 5 },
    { term: 'vector db', weight: 5 }, { term: 'embedding', weight: 3 }, { term: 'observability', weight: 4 },
    { term: 'monitoring', weight: 3 }, { term: 'mlops', weight: 5 }, { term: 'latency', weight: 3 }, { term: 'kubernetes', weight: 4 }
  ],
  'governance-safety': [
    { term: 'safety', weight: 5 }, { term: 'policy', weight: 5 }, { term: 'regulation', weight: 5 },
    { term: 'governance', weight: 5 }, { term: 'privacy', weight: 4 }, { term: 'risk', weight: 4 },
    { term: 'security', weight: 4 }, { term: 'ethics', weight: 4 }, { term: 'compliance', weight: 5 },
    { term: 'copyright', weight: 4 }, { term: 'law', weight: 3 }, { term: 'model risk', weight: 5 }
  ]
};

function normalize(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9+#.\s-]/g, ' ').replace(/\s+/g, ' ').trim();
}

function countOccurrences(haystack: string, needle: string): number {
  if (!needle) return 0;
  let count = 0;
  let position = haystack.indexOf(needle);
  while (position !== -1) {
    count += 1;
    position = haystack.indexOf(needle, position + needle.length);
  }
  return count;
}

export type ModalityClassification = {
  modalitySlugs: ModalitySlug[];
  scores: Record<ModalitySlug, number>;
  rationale: string[];
};

export function classifyModalitiesFromText(input: string, defaults: ModalitySlug[] = []): ModalityClassification {
  const text = normalize(input);
  const scores = Object.fromEntries(modalities.map((modality) => [modality.slug, 0])) as Record<ModalitySlug, number>;
  const rationale: string[] = [];

  for (const modality of modalities) {
    const profileText = normalize(`${modality.name} ${modality.summary} ${modality.examples.join(' ')}`);

    for (const example of modality.examples) {
      const term = normalize(example);
      const hits = countOccurrences(text, term);
      if (hits > 0) scores[modality.slug] += hits * 3;
    }

    for (const word of profileText.split(' ').filter((part) => part.length > 4)) {
      if (text.includes(word)) scores[modality.slug] += 0.5;
    }

    for (const signal of modalitySignals[modality.slug]) {
      const hits = countOccurrences(text, normalize(signal.term));
      if (hits > 0) {
        scores[modality.slug] += hits * signal.weight;
        rationale.push(`${modality.slug}: matched "${signal.term}"`);
      }
    }
  }

  for (const slug of defaults) scores[slug] += 2;

  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]) as Array<[ModalitySlug, number]>;
  const topScore = sorted[0]?.[1] ?? 0;
  let modalitySlugs = sorted.filter(([, score]) => score > 0 && score >= Math.max(4, topScore * 0.5)).map(([slug]) => slug);

  if (modalitySlugs.length === 0) modalitySlugs = defaults.length > 0 ? [...defaults] : ['research-ml'];

  return { modalitySlugs: [...new Set(modalitySlugs)], scores, rationale: [...new Set(rationale)].slice(0, 12) };
}

export function classifyItemModalities(source: FeedSource, title: string, summary?: string, categories: string[] = []): ModalitySlug[] {
  const combined = [source.title, source.tags.join(' '), title, summary ?? '', categories.join(' ')].join(' ');
  return classifyModalitiesFromText(combined, source.modalitySlugs).modalitySlugs;
}
