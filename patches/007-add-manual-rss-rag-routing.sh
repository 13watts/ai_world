#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "src/server.ts" || ! -f "src/services/feedService.ts" || ! -f "src/routes/siteRoutes.ts" ]]; then
  echo "ERROR: Run this from the ai_world repo root." >&2
  exit 1
fi

STAMP="$(date +%Y%m%d%H%M%S)"
mkdir -p data src/services
cp src/services/feedService.ts "src/services/feedService.ts.bak.${STAMP}"
cp src/routes/siteRoutes.ts "src/routes/siteRoutes.ts.bak.${STAMP}"
cp src/views/feeds.ejs "src/views/feeds.ejs.bak.${STAMP}"
cp src/views/modality.ejs "src/views/modality.ejs.bak.${STAMP}"

cat > src/services/modalityClassifier.ts <<'TS'
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
TS

cat > src/services/feedRegistry.ts <<'TS'
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

const customFeedSchema = z.object({
  id: z.string(),
  title: z.string(),
  url: z.string().url(),
  homepage: z.string().url(),
  modalitySlugs: z.array(z.custom<ModalitySlug>()),
  tags: z.array(z.string()),
  reliability: z.literal('community'),
  addedAt: z.string().optional(),
  classification: z.object({ scores: z.record(z.number()), rationale: z.array(z.string()) }).optional()
});

const customFeedListSchema = z.array(customFeedSchema);
export type CustomFeedSource = z.infer<typeof customFeedSchema>;

function slugify(value: string): string {
  return value.toLowerCase().replace(/^https?:\/\//, '').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80);
}

function stripHtml(value: string | undefined): string {
  if (!value) return '';
  return value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function homepageFromFeedUrl(feedUrl: string, link?: string): string {
  try {
    if (link) return new URL(link).origin;
  } catch {
    // Fall back to feed URL below.
  }
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

  if (allFeeds.some((feed) => feed.url === url)) throw new Error('That feed URL is already configured. Duplication: still not a feature.');

  const parsed = await parser.parseURL(url);
  const title = requestedTitle?.trim() || parsed.title?.trim() || new URL(url).hostname;
  const homepage = homepageFromFeedUrl(url, parsed.link);

  const sampleText = [
    title,
    parsed.description ?? '',
    parsed.items.slice(0, 12).map((item) => [item.title ?? '', stripHtml(item.contentSnippet ?? item.content ?? item.summary), ...(item.categories ?? [])].join(' ')).join(' ')
  ].join(' ');

  const classification = classifyModalitiesFromText(sampleText);
  const hostname = new URL(url).hostname.replace(/^www\./, '');
  const baseId = `custom-${slugify(`${hostname}-${title}`)}`;
  let id = baseId;
  let suffix = 2;
  while (allFeeds.some((feed) => feed.id === id)) {
    id = `${baseId}-${suffix}`;
    suffix += 1;
  }

  const feed: CustomFeedSource = {
    id,
    title,
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

cat > src/services/feedService.ts <<'TS'
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
TS

cat > src/routes/siteRoutes.ts <<'TS'
import { Router } from 'express';
import { getModality, modalities } from '../config/modalities.js';
import { addCustomFeedFromUrl, getAllFeedSources } from '../services/feedRegistry.js';
import { getFeedCache, getItemsForModality, refreshFeeds } from '../services/feedService.js';

export const siteRoutes = Router();

siteRoutes.get('/', async (_req, res, next) => {
  try {
    const cache = await getFeedCache();
    res.render('index', { title: 'AI World', modalities, recentItems: cache.items.slice(0, 12), updatedAt: cache.updatedAt });
  } catch (error) {
    next(error);
  }
});

siteRoutes.get('/modalities/:slug', async (req, res, next) => {
  try {
    const modality = getModality(req.params.slug);
    if (!modality) {
      res.status(404).render('not-found', { title: 'Not Found', modalities });
      return;
    }

    const items = await getItemsForModality(modality.slug);
    const allFeedSources = await getAllFeedSources();
    const sources = allFeedSources.filter((source) => source.modalitySlugs.includes(modality.slug));

    res.render('modality', { title: `${modality.name} | AI World`, modalities, modality, items, sources });
  } catch (error) {
    next(error);
  }
});

siteRoutes.get('/feeds', async (req, res, next) => {
  try {
    const cache = await getFeedCache();
    const allFeedSources = await getAllFeedSources();
    res.render('feeds', {
      title: 'Feeds | AI World',
      modalities,
      feedSources: allFeedSources,
      errors: cache.errors,
      updatedAt: cache.updatedAt,
      addedFeed: req.query.addedFeed,
      addFeedError: req.query.addFeedError
    });
  } catch (error) {
    next(error);
  }
});

siteRoutes.post('/admin/feeds/add', async (req, res) => {
  try {
    const feedUrl = typeof req.body.feedUrl === 'string' ? req.body.feedUrl : '';
    const feedTitle = typeof req.body.feedTitle === 'string' ? req.body.feedTitle : undefined;
    const feed = await addCustomFeedFromUrl(feedUrl, feedTitle);
    await refreshFeeds();
    res.redirect(`/feeds?addedFeed=${encodeURIComponent(feed.title)}`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    res.redirect(`/feeds?addFeedError=${encodeURIComponent(message)}`);
  }
});

siteRoutes.post('/admin/refresh-feeds', async (_req, res, next) => {
  try {
    await refreshFeeds();
    res.redirect('/feeds');
  } catch (error) {
    next(error);
  }
});
TS

cat > src/views/feeds.ejs <<'EJS'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%= title %></title>
  <link rel="stylesheet" href="/css/site.css">
</head>
<body>
  <%- include('partials-header', { modalities }) %>
  <main class="layout">
    <div class="section-heading">
      <div>
        <p class="eyebrow">RSS configuration</p>
        <h1>Feeds</h1>
        <p class="lead">These sources seed the AI World modality pages. Static feeds live in <code>src/config/feeds.ts</code>; manually added feeds are stored in <code>data/custom-feeds.json</code>.</p>
      </div>
      <form method="post" action="/admin/refresh-feeds"><button type="submit">Refresh now</button></form>
    </div>
    <p class="meta">Last refresh: <%= new Date(updatedAt).toLocaleString() %></p>

    <% if (addedFeed) { %><article class="feed-item success"><h3>Feed added</h3><p><%= addedFeed %> was added and classified into the matching modality pages.</p></article><% } %>
    <% if (addFeedError) { %><article class="feed-item warning"><h3>Feed add failed</h3><p><%= addFeedError %></p></article><% } %>

    <section class="panel">
      <h2>Add RSS feed</h2>
      <p>The server fetches the feed, samples recent items, scores the content against modality profiles, and places the feed dynamically. It is RAG in the practical sense: retrieve feed content, augment it with local modality knowledge, classify it, and skip the cloud-oracle ceremony.</p>
      <form method="post" action="/admin/feeds/add" class="feed-form">
        <label>Feed URL<input type="url" name="feedUrl" placeholder="https://example.com/feed.xml" required></label>
        <label>Display title, optional<input type="text" name="feedTitle" placeholder="Use feed title if blank"></label>
        <button type="submit">Add and classify feed</button>
      </form>
    </section>

    <table>
      <thead><tr><th>Source</th><th>Reliability</th><th>Modalities</th><th>Feed URL</th></tr></thead>
      <tbody>
        <% feedSources.forEach((source) => { %>
          <tr>
            <td><a href="<%= source.homepage %>" target="_blank" rel="noopener noreferrer"><%= source.title %></a></td>
            <td><%= source.reliability %></td>
            <td><%= source.modalitySlugs.join(', ') %></td>
            <td><code><%= source.url %></code></td>
          </tr>
        <% }) %>
      </tbody>
    </table>

    <% if (errors.length > 0) { %>
      <h2>Feed refresh warnings</h2>
      <div class="feed-list">
        <% errors.forEach((error) => { %><article class="feed-item warning"><h3><%= error.sourceId %></h3><p><%= error.message %></p></article><% }) %>
      </div>
    <% } %>
  </main>
</body>
</html>
EJS

cat > src/views/modality.ejs <<'EJS'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%= title %></title>
  <link rel="stylesheet" href="/css/site.css">
</head>
<body>
  <%- include('partials-header', { modalities }) %>
  <main class="layout two-column">
    <section>
      <p class="eyebrow">Modality</p>
      <h1><%= modality.name %></h1>
      <p class="lead"><%= modality.summary %></p>

      <h2>Latest resources</h2>
      <div class="feed-list">
        <% if (items.length === 0) { %><p>No feed items found for this modality yet.</p><% } %>
        <% items.forEach((item) => { %>
          <article class="feed-item">
            <h3><a href="<%= item.link %>" target="_blank" rel="noopener noreferrer"><%= item.title %></a></h3>
            <p class="meta"><%= item.sourceTitle %><% if (item.isoDate) { %> · <%= new Date(item.isoDate).toLocaleDateString() %><% } %></p>
            <% if (item.summary) { %><p><%= item.summary %></p><% } %>
            <p class="tags"><%= item.categories.slice(0, 6).join(' · ') %></p>
            <p class="meta">Routed to: <%= item.modalitySlugs.join(', ') %></p>
          </article>
        <% }) %>
      </div>
    </section>

    <aside class="sidebar">
      <h2>Configured feeds</h2>
      <% sources.forEach((source) => { %>
        <article class="source">
          <h3><a href="<%= source.homepage %>" target="_blank" rel="noopener noreferrer"><%= source.title %></a></h3>
          <p><%= source.reliability %> · <%= source.tags.join(', ') %></p>
          <p class="meta">Modalities: <%= source.modalitySlugs.join(', ') %></p>
        </article>
      <% }) %>
    </aside>
  </main>
</body>
</html>
EJS

python3 - <<'PY'
from pathlib import Path
path = Path('src/public/css/site.css')
text = path.read_text()
addition = '''

.panel {
  background: #ffffff;
  border: 1px solid #d7dde8;
  border-radius: 16px;
  padding: 1.25rem;
  margin: 1.5rem 0;
}

.feed-form {
  display: grid;
  gap: 1rem;
  max-width: 760px;
}

.feed-form label {
  display: grid;
  gap: 0.35rem;
  font-weight: 700;
}

.feed-form input {
  border: 1px solid #b8c2d6;
  border-radius: 10px;
  font: inherit;
  padding: 0.7rem 0.85rem;
}

.feed-item.success {
  border-left: 4px solid #1a7f37;
}
'''
if '.feed-form' not in text:
    path.write_text(text.rstrip() + addition + '\n')
PY

if [[ -f .env.example ]] && ! grep -q '^CUSTOM_FEEDS_FILE=' .env.example; then
  cat >> .env.example <<'ENVADD'

# User-added RSS feeds are stored here as JSON.
CUSTOM_FEEDS_FILE=data/custom-feeds.json
ENVADD
fi

mkdir -p data
[[ -f data/custom-feeds.json ]] || printf '[]\n' > data/custom-feeds.json

if [[ -f .gitignore ]] && ! grep -q '^data/feed-cache.json$' .gitignore; then
  cat >> .gitignore <<'GITADD'

data/feed-cache.json
GITADD
fi

npm run build

echo "Added manual RSS feed onboarding with local RAG-style modality classification."
