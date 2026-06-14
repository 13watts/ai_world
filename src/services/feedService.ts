import fs from 'node:fs/promises';
import path from 'node:path';
import Parser from 'rss-parser';
import { z } from 'zod';
import type { FeedCache, FeedItem, ModalitySlug } from '../types/content.js';
import { getAllFeedSources } from './feedRegistry.js';
import { classifyItemModalities } from './modalityClassifier.js';

const parser = new Parser({
  timeout: 15_000,
  headers: { 'User-Agent': 'AIWorldRSS/0.1 (+https://localhost)' }
});

const envSchema = z.object({
  FEED_CACHE_FILE: z.string().default('data/feed-cache.json'),
  MAX_ITEMS_PER_FEED: z.coerce.number().int().positive().default(20)
});

const env = envSchema.parse(process.env);
const cacheFile = path.resolve(process.cwd(), env.FEED_CACHE_FILE);

function stripHtml(value: string | undefined): string | undefined {
  if (!value) return undefined;
  return value.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim().slice(0, 400);
}

async function readCache(): Promise<FeedCache> {
  try {
    const raw = await fs.readFile(cacheFile, 'utf8');
    return JSON.parse(raw) as FeedCache;
  } catch {
    return { updatedAt: new Date(0).toISOString(), items: [], errors: [] };
  }
}

async function writeCache(cache: FeedCache): Promise<void> {
  await fs.mkdir(path.dirname(cacheFile), { recursive: true });
  await fs.writeFile(cacheFile, JSON.stringify(cache, null, 2));
}

export async function refreshFeeds(): Promise<FeedCache> {
  const items: FeedItem[] = [];
  const errors: FeedCache['errors'] = [];
  const sources = await getAllFeedSources();

  await Promise.allSettled(
    sources.map(async (source) => {
      try {
        const parsed = await parser.parseURL(source.url);
        for (const item of parsed.items.slice(0, env.MAX_ITEMS_PER_FEED)) {
          const title = item.title?.trim();
          const link = item.link?.trim();
          if (!title || !link) continue;

          const summary = stripHtml(item.contentSnippet ?? item.content ?? item.summary);
          const categories = [...new Set([...(item.categories ?? []), ...source.tags])];
          items.push({
            sourceId: source.id,
            sourceTitle: source.title,
            title,
            link,
            isoDate: item.isoDate ?? item.pubDate,
            summary,
            categories,
            modalitySlugs: classifyItemModalities(source, title, summary, categories)
          });
        }
      } catch (error) {
        errors.push({ sourceId: source.id, message: error instanceof Error ? error.message : String(error), at: new Date().toISOString() });
      }
    })
  );

  const uniqueByLink = new Map<string, FeedItem>();
  for (const item of items) uniqueByLink.set(item.link, item);

  const cache: FeedCache = {
    updatedAt: new Date().toISOString(),
    items: [...uniqueByLink.values()].sort((a, b) => {
      const aTime = a.isoDate ? Date.parse(a.isoDate) : 0;
      const bTime = b.isoDate ? Date.parse(b.isoDate) : 0;
      return bTime - aTime;
    }),
    errors
  };

  await writeCache(cache);
  return cache;
}

export async function getFeedCache(): Promise<FeedCache> {
  const cache = await readCache();
  if (cache.items.length === 0) return refreshFeeds();
  return cache;
}

export async function getItemsForModality(slug: string, limit = 50): Promise<FeedItem[]> {
  const cache = await getFeedCache();
  return cache.items.filter((item) => item.modalitySlugs.includes(slug as ModalitySlug)).slice(0, limit);
}
