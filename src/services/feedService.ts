import fs from 'node:fs/promises';
import path from 'node:path';
import Parser from 'rss-parser';
import { z } from 'zod';
import { feedSources } from '../config/feeds.js';
import type { FeedCache, FeedItem, FeedSource, ModalitySlug } from '../types/content.js';

const parser = new Parser({
  timeout: 15_000,
  headers: {
    'User-Agent': 'AIWorldRSS/0.1 (+https://localhost)'
  }
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

function inferModalities(source: FeedSource, title: string, summary?: string): ModalitySlug[] {
  const text = `${title} ${summary ?? ''}`.toLowerCase();
  const inferred = new Set<ModalitySlug>(source.modalitySlugs);

  if (/image|vision|video|multimodal|diffusion|sora|imagen|vae|visual/.test(text)) inferred.add('image-video');
  if (/speech|audio|voice|tts|transcrib|whisper|music/.test(text)) inferred.add('audio-speech');
  if (/code|agent|tool|mcp|developer|software|automation|computer use/.test(text)) inferred.add('code-agents');
  if (/policy|safety|risk|regulation|governance|privacy|security|ethic/.test(text)) inferred.add('governance-safety');
  if (/inference|gpu|serving|vector|database|mlops|deployment|monitoring|latency/.test(text)) inferred.add('infra-mlops');
  if (/paper|research|benchmark|dataset|training|model|architecture|evaluation/.test(text)) inferred.add('research-ml');
  if (/llm|language|chat|assistant|rag|context|reasoning|token/.test(text)) inferred.add('text-llms');

  return [...inferred];
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

  await Promise.allSettled(
    feedSources.map(async (source) => {
      try {
        const parsed = await parser.parseURL(source.url);
        for (const item of parsed.items.slice(0, env.MAX_ITEMS_PER_FEED)) {
          const title = item.title?.trim();
          const link = item.link?.trim();
          if (!title || !link) continue;

          const summary = stripHtml(item.contentSnippet ?? item.content ?? item.summary);
          items.push({
            sourceId: source.id,
            sourceTitle: source.title,
            title,
            link,
            isoDate: item.isoDate ?? item.pubDate,
            summary,
            categories: [...new Set([...(item.categories ?? []), ...source.tags])],
            modalitySlugs: inferModalities(source, title, summary)
          });
        }
      } catch (error) {
        errors.push({
          sourceId: source.id,
          message: error instanceof Error ? error.message : String(error),
          at: new Date().toISOString()
        });
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
