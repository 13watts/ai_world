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
