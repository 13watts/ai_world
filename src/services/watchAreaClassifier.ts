import type { FeedItem, FeedSource, WatchAreaSlug } from '../types/content.js';
import { watchAreas } from '../config/watchAreas.js';

function normalize(value: string | undefined): string {
  return (value ?? '').toLowerCase();
}

function countKeywordMatches(haystack: string, keywords: string[]): number {
  let score = 0;

  for (const keyword of keywords) {
    const needle = keyword.toLowerCase();
    if (!needle) continue;

    if (haystack.includes(needle)) {
      score += needle.includes(' ') || needle.includes('-') ? 3 : 2;
    }
  }

  return score;
}

export function classifyItemWatchAreas(
  source: FeedSource,
  title: string,
  summary: string | undefined,
  categories: string[]
): WatchAreaSlug[] {
  const titleText = normalize(title);
  const summaryText = normalize(summary);
  const categoryText = categories.map((category) => normalize(category)).join(' ');
  const sourceText = [source.title, source.tags.join(' '), source.modalitySlugs.join(' ')].map(normalize).join(' ');
  const combined = `${titleText} ${titleText} ${summaryText} ${categoryText} ${sourceText}`;

  const scored = watchAreas
    .map((watchArea) => {
      let score = countKeywordMatches(combined, watchArea.keywords);

      for (const modalitySlug of source.modalitySlugs) {
        if (watchArea.modalitySlugs.includes(modalitySlug)) score += 1;
      }

      return { slug: watchArea.slug, score };
    })
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score);

  const selected = scored.slice(0, 4).map((entry) => entry.slug as WatchAreaSlug);

  if (selected.length > 0) return selected;

  // Reasonable fallback when a feed item is relevant but too generic to score cleanly.
  if (source.modalitySlugs.includes('text-llms')) return ['llms'];
  if (source.modalitySlugs.includes('infra-mlops')) return ['ai-infrastructure'];
  if (source.modalitySlugs.includes('governance-safety')) return ['ai-safety-governance'];
  return ['llms'];
}

export function getWatchAreaNamesForItem(item: FeedItem): string[] {
  const slugs = item.watchAreaSlugs ?? [];
  return slugs
    .map((slug) => watchAreas.find((watchArea) => watchArea.slug === slug)?.name)
    .filter((name): name is string => Boolean(name));
}
