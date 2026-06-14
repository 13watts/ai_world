#!/usr/bin/env bash
set -euo pipefail

REGISTRY_FILE="src/services/feedRegistry.ts"
SERVICE_FILE="src/services/feedService.ts"
ROUTES_FILE="src/routes/siteRoutes.ts"
PACKAGE_FILE="package.json"

if [[ ! -f "$REGISTRY_FILE" || ! -f "$SERVICE_FILE" ]]; then
  echo "ERROR: Run this from the ai_world repo root." >&2
  exit 1
fi

STAMP="$(date +%Y%m%d%H%M%S)"
cp "$REGISTRY_FILE" "${REGISTRY_FILE}.bak.${STAMP}"
cp "$SERVICE_FILE" "${SERVICE_FILE}.bak.${STAMP}"
[[ -f "$ROUTES_FILE" ]] && cp "$ROUTES_FILE" "${ROUTES_FILE}.bak.${STAMP}"
[[ -f "$PACKAGE_FILE" ]] && cp "$PACKAGE_FILE" "${PACKAGE_FILE}.bak.${STAMP}"

cat > "$REGISTRY_FILE" <<'TS'
import fs from 'node:fs/promises';
import path from 'node:path';
import Parser from 'rss-parser';
import { z } from 'zod';
import { feedSources } from '../config/feeds.js';
import type { FeedSource, ModalitySlug } from '../types/content.js';
import { classifyModalitiesFromText } from './modalityClassifier.js';

const customFeedFile = path.resolve(process.cwd(), process.env.CUSTOM_FEEDS_FILE ?? 'data/custom-feeds.json');

const parser = new Parser({
  timeout: 15_000,
  headers: { 'User-Agent': 'AIWorldRSS/0.1 (+https://localhost)' }
});

const modalitySlugSchema = z.enum([
  'text-llms',
  'image-video',
  'audio-speech',
  'code-agents',
  'research-ml',
  'infra-mlops',
  'governance-safety'
]);

const customFeedSchema = z.object({
  id: z.string(),
  title: z.string(),
  url: z.string().url(),
  homepage: z.string().url(),
  modalitySlugs: z.array(modalitySlugSchema),
  tags: z.array(z.string()),
  reliability: z.literal('community'),
  addedAt: z.string().optional(),
  classification: z.object({ scores: z.record(z.number()), rationale: z.array(z.string()) }).optional()
});

const customFeedListSchema = z.array(customFeedSchema);
export type CustomFeedSource = z.infer<typeof customFeedSchema>;

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

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/^https?:\/\//, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

function stripHtml(value: unknown): string {
  const text = safeText(value);
  if (!text) return '';
  return text.replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim();
}

function normalizeCategories(value: unknown): string[] {
  if (!value) return [];
  const values = Array.isArray(value) ? value : [value];

  return [...new Set(values.map((item) => stripHtml(item)).filter(Boolean))];
}

function homepageFromFeedUrl(feedUrl: string, link: unknown): string {
  const parsedLink = safeUrl(link);
  if (parsedLink) return new URL(parsedLink).origin;
  return new URL(feedUrl).origin;
}

async function readCustomFeeds(): Promise<CustomFeedSource[]> {
  try {
    const raw = await fs.readFile(customFeedFile, 'utf8');
    return customFeedListSchema.parse(JSON.parse(raw));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw error;
  }
}

async function writeCustomFeeds(feeds: CustomFeedSource[]): Promise<void> {
  await fs.mkdir(path.dirname(customFeedFile), { recursive: true });
  await fs.writeFile(customFeedFile, JSON.stringify(feeds, null, 2));
}

export async function getAllFeedSources(): Promise<FeedSource[]> {
  const customFeeds = await readCustomFeeds();
  return [...feedSources, ...customFeeds];
}

export async function addCustomFeedFromUrl(feedUrl: string, requestedTitle?: string): Promise<CustomFeedSource> {
  const url = z.string().url().parse(feedUrl.trim());
  const existingFeeds = await readCustomFeeds();
  const allFeeds = [...feedSources, ...existingFeeds];

  if (allFeeds.some((feed) => feed.url === url)) {
    throw new Error('That feed URL is already configured. Duplication: still not a feature.');
  }

  let parsed: Awaited<ReturnType<typeof parser.parseURL>>;
  try {
    parsed = await parser.parseURL(url);
  } catch (error) {
    const message = error instanceof Error ? error.message : safeText(error);
    throw new Error(`Could not parse RSS/Atom feed: ${message}`);
  }

  const feedTitle = requestedTitle?.trim() || stripHtml(parsed.title) || new URL(url).hostname;
  const homepage = homepageFromFeedUrl(url, parsed.link);

  const itemSamples = parsed.items.slice(0, 12).map((item) => {
    const itemTitle = stripHtml(item.title);
    const itemSummary = stripHtml(item.contentSnippet ?? item.content ?? item.summary);
    const categories = normalizeCategories(item.categories).join(' ');
    return [itemTitle, itemSummary, categories].filter(Boolean).join(' ');
  });

  const sampleText = [
    feedTitle,
    stripHtml(parsed.description),
    ...itemSamples
  ].filter(Boolean).join(' ');

  const classification = classifyModalitiesFromText(sampleText);
  const hostname = new URL(url).hostname.replace(/^www\./, '');
  const baseId = `custom-${slugify(`${hostname}-${feedTitle}`) || slugify(hostname)}`;
  let id = baseId;
  let suffix = 2;

  while (allFeeds.some((feed) => feed.id === id)) {
    id = `${baseId}-${suffix}`;
    suffix += 1;
  }

  const feed: CustomFeedSource = {
    id,
    title: feedTitle,
    url,
    homepage,
    modalitySlugs: classification.modalitySlugs,
    tags: [...new Set(['custom', 'rss', ...classification.modalitySlugs])],
    reliability: 'community',
    addedAt: new Date().toISOString(),
    classification: { scores: classification.scores, rationale: classification.rationale }
  };

  existingFeeds.push(feed);
  await writeCustomFeeds(existingFeeds.sort((a, b) => a.title.localeCompare(b.title)));
  return feed;
}
TS

cat > "$SERVICE_FILE" <<'TS'
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
  const items: FeedItem[] = [];
  const errors: FeedCache['errors'] = [];
  const sources = await getAllFeedSources();

  await Promise.allSettled(
    sources.map(async (source) => {
      try {
        const parsed = await parser.parseURL(source.url);
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
            modalitySlugs: classifyItemModalities(source, title, summary, categories)
          });
        }
      } catch (error) {
        errors.push({
          sourceId: source.id,
          message: error instanceof Error ? error.message : safeText(error),
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
TS

# Add a small CLI tester so manual feed onboarding can be tested without the browser.
mkdir -p scripts
cat > scripts/test-add-feed.ts <<'TS'
import 'dotenv/config';
import { addCustomFeedFromUrl } from '../src/services/feedRegistry.js';
import { refreshFeeds } from '../src/services/feedService.js';

const [, , feedUrl, ...titleParts] = process.argv;
const feedTitle = titleParts.join(' ').trim() || undefined;

if (!feedUrl) {
  console.error('Usage: npm run test:add-feed -- <feed-url> [display title]');
  process.exit(1);
}

try {
  const feed = await addCustomFeedFromUrl(feedUrl, feedTitle);
  console.log(JSON.stringify({ added: feed }, null, 2));
  const cache = await refreshFeeds();
  console.log(`Feed refresh completed. Items cached: ${cache.items.length}. Warnings: ${cache.errors.length}.`);
  if (cache.errors.length > 0) {
    for (const error of cache.errors) console.warn(`- ${error.sourceId}: ${error.message}`);
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
TS

python3 - <<'PY'
from pathlib import Path
import json

path = Path('package.json')
if not path.exists():
    raise SystemExit(0)

data = json.loads(path.read_text())
scripts = data.setdefault('scripts', {})
scripts.setdefault('test:add-feed', 'tsx scripts/test-add-feed.ts')
path.write_text(json.dumps(data, indent=2) + '\n')
PY

# Make route errors easier to troubleshoot in the server console.
if [[ -f "$ROUTES_FILE" ]]; then
python3 - <<'PY'
from pathlib import Path

path = Path('src/routes/siteRoutes.ts')
text = path.read_text()
old = """  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    res.redirect(`/feeds?addFeedError=${encodeURIComponent(message)}`);
  }
});"""
new = """  } catch (error) {
    console.error('[feeds] Add feed failed:', error);
    const message = error instanceof Error ? error.message : String(error);
    res.redirect(`/feeds?addFeedError=${encodeURIComponent(message)}`);
  }
});"""
if old in text and "[feeds] Add feed failed" not in text:
    path.write_text(text.replace(old, new))
PY
fi

npm run build

echo "Hardened manual feed ingestion and added npm run test:add-feed."
