import { randomUUID } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import Parser from 'rss-parser';
import { z } from 'zod';
import type { FeedCache, FeedItem, ModalitySlug, WatchAreaSlug } from '../types/content.js';
import { getAllFeedSources } from './feedRegistry.js';
import { logFeedCrawlEvent } from './activityLog.js';
import { classifyItemModalities } from './modalityClassifier.js';
import { classifyItemWatchAreas } from './watchAreaClassifier.js';

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

type LooseRecord = Record<string, unknown>;

function isRecord(value: unknown): value is LooseRecord {
  return typeof value === 'object' && value !== null;
}

function safeText(value: unknown): string {
  if (value === null || value === undefined) return '';

  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean' || typeof value === 'bigint') return String(value);
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map((item) => safeText(item)).filter(Boolean).join(' ');

  if (isRecord(value)) {
    const preferredKeys = ['_', '#', '$text', 'text', 'value', 'name', 'title', 'label', 'href', 'url'];
    for (const key of preferredKeys) {
      if (key in value) {
        const converted = safeText(value[key]);
        if (converted) return converted;
      }
    }

    return Object.values(value).map((item) => safeText(item)).filter(Boolean).join(' ');
  }

  try {
    return String(value);
  } catch {
    return '';
  }
}

function safeUrl(value: unknown): string | undefined {
  const raw = safeText(value).trim();
  if (!raw) return undefined;

  try {
    return new URL(raw).toString();
  } catch {
    return undefined;
  }
}

function stripHtml(value: unknown): string | undefined {
  const text = safeText(value);
  if (!text) return undefined;
  return text.replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 400);
}

function normalizeCategories(value: unknown): string[] {
  if (!value) return [];
  const values = Array.isArray(value) ? value : [value];
  return [...new Set(values.map((item) => stripHtml(item)).filter((item): item is string => Boolean(item)))];
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
  const crawlId = randomUUID();
  const startedAtMs = Date.now();
  const items: FeedItem[] = [];
  const errors: FeedCache['errors'] = [];
  const sources = await getAllFeedSources();

  await logFeedCrawlEvent({
    event: 'rss_crawl_start',
    crawlId,
    sourceCount: sources.length,
    maxItemsPerFeed: env.MAX_ITEMS_PER_FEED,
    cacheFile
  });

  await Promise.allSettled(
    sources.map(async (source) => {
      await logFeedCrawlEvent({
        event: 'rss_feed_fetch_start',
        crawlId,
        sourceId: source.id,
        sourceTitle: source.title,
        feedUrl: source.url,
        homepage: source.homepage,
        configuredModalities: source.modalitySlugs,
        reliability: source.reliability
      });

      try {
        const parsed = await parser.parseURL(source.url);

        await logFeedCrawlEvent({
          event: 'rss_feed_fetch_success',
          crawlId,
          sourceId: source.id,
          sourceTitle: source.title,
          feedUrl: source.url,
          itemCount: parsed.items.length,
          feedTitle: stripHtml(parsed.title) ?? source.title,
          feedLink: safeUrl(parsed.link) ?? source.homepage
        });

        for (const item of parsed.items.slice(0, env.MAX_ITEMS_PER_FEED)) {
          const title = stripHtml(item.title);
          const link = safeUrl(item.link);
          if (!title || !link) continue;

          const summary = stripHtml(item.contentSnippet ?? item.content ?? item.summary);
          const categories = [...new Set([...normalizeCategories(item.categories), ...source.tags])];
          items.push({
            sourceId: source.id,
            sourceTitle: source.title,
            title,
            link,
            isoDate: safeText(item.isoDate ?? item.pubDate) || undefined,
            summary,
            categories,
            modalitySlugs: classifyItemModalities(source, title, summary, categories),
            watchAreaSlugs: classifyItemWatchAreas(source, title, summary, categories)
          });
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : safeText(error);
        errors.push({
          sourceId: source.id,
          message,
          at: new Date().toISOString()
        });

        await logFeedCrawlEvent({
          event: 'rss_feed_fetch_error',
          crawlId,
          sourceId: source.id,
          sourceTitle: source.title,
          feedUrl: source.url,
          message
        });
      }
    })
  );

  const uniqueByLink = new Map<string, FeedItem>();
  for (const item of items) uniqueByLink.set(item.link, item);

  for (const item of uniqueByLink.values()) {
    await logFeedCrawlEvent({
      event: 'rss_item_discovered',
      crawlId,
      sourceId: item.sourceId,
      sourceTitle: item.sourceTitle,
      title: item.title,
      link: item.link,
      isoDate: item.isoDate ?? null,
      routedModalities: item.modalitySlugs,
      categories: item.categories.slice(0, 12)
    });
  }

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

  await logFeedCrawlEvent({
    event: 'rss_crawl_complete',
    crawlId,
    sourceCount: sources.length,
    discoveredItemCount: items.length,
    uniqueItemCount: uniqueByLink.size,
    errorCount: errors.length,
    elapsedMs: Date.now() - startedAtMs,
    cacheUpdatedAt: cache.updatedAt
  });

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


export async function getItemsForWatchArea(slug: string, limit = 50): Promise<FeedItem[]> {
  const cache = await getFeedCache();
  return cache.items.filter((item) => (item.watchAreaSlugs ?? []).includes(slug as WatchAreaSlug)).slice(0, limit);
}
