#!/usr/bin/env bash
set -euo pipefail

SERVICE_FILE="src/services/feedService.ts"
SERVER_FILE="src/server.ts"
ROUTES_FILE="src/routes/siteRoutes.ts"
HEADER_FILE="src/views/partials-header.ejs"
ENV_FILE=".env.example"
GITIGNORE_FILE=".gitignore"
LOG_SERVICE_FILE="src/services/activityLog.ts"
LOG_VIEW_FILE="src/views/logs.ejs"
PACKAGE_FILE="package.json"

if [[ ! -f "$SERVICE_FILE" || ! -f "$SERVER_FILE" || ! -f "$ROUTES_FILE" ]]; then
  echo "ERROR: Run this from the ai_world repo root. Missing src files." >&2
  exit 1
fi

STAMP="$(date +%Y%m%d%H%M%S)"
for file in "$SERVICE_FILE" "$SERVER_FILE" "$ROUTES_FILE" "$HEADER_FILE" "$ENV_FILE" "$GITIGNORE_FILE" "$PACKAGE_FILE"; do
  [[ -f "$file" ]] && cp "$file" "${file}.bak.${STAMP}"
done

mkdir -p src/services src/views data/logs

cat > "$LOG_SERVICE_FILE" <<'TS'
import fs from 'node:fs/promises';
import path from 'node:path';
import type { NextFunction, Request, Response } from 'express';

export type LogKind = 'access' | 'rss-crawl';
export type ActivityLogEvent = Record<string, unknown> & {
  ts?: string;
  event: string;
};

const logRoot = path.resolve(process.cwd(), process.env.AI_WORLD_LOG_DIR ?? 'data/logs');
const logIps = (process.env.AI_WORLD_LOG_IPS ?? 'false').toLowerCase() === 'true';

function dateParts(date: Date): { year: string; month: string; day: string; stamp: string } {
  const year = String(date.getFullYear());
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return { year, month, day, stamp: `${year}-${month}-${day}` };
}

function logFileFor(kind: LogKind, date = new Date()): string {
  const parts = dateParts(date);
  return path.join(logRoot, kind, parts.year, parts.month, `${parts.stamp}.jsonl`);
}

function sanitizeEvent(event: ActivityLogEvent): ActivityLogEvent {
  return Object.fromEntries(
    Object.entries({ ts: new Date().toISOString(), ...event }).filter(([, value]) => value !== undefined)
  ) as ActivityLogEvent;
}

export async function appendActivityLog(kind: LogKind, event: ActivityLogEvent): Promise<void> {
  const file = logFileFor(kind);
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.appendFile(file, `${JSON.stringify(sanitizeEvent(event))}\n`, 'utf8');
}

function shouldSkipAccessLog(req: Request): boolean {
  if (req.method === 'HEAD' || req.method === 'OPTIONS') return true;

  // Static assets are noise. Useful noise sometimes, but still noise.
  return (
    req.path.startsWith('/css/') ||
    req.path.startsWith('/js/') ||
    req.path.startsWith('/images/') ||
    req.path === '/favicon.ico' ||
    req.path === '/robots.txt'
  );
}

export function logPageAccess(req: Request, res: Response, next: NextFunction): void {
  if (shouldSkipAccessLog(req)) {
    next();
    return;
  }

  const startedAt = Date.now();

  res.on('finish', () => {
    const event: ActivityLogEvent = {
      event: 'page_access',
      method: req.method,
      path: req.originalUrl,
      routePath: req.path,
      statusCode: res.statusCode,
      durationMs: Date.now() - startedAt,
      referrer: req.get('referer') ?? null,
      userAgent: req.get('user-agent') ?? null,
      ip: logIps ? req.ip : undefined
    };

    appendActivityLog('access', event).catch((error) => {
      console.error('[logs] Failed to write access log:', error);
    });
  });

  next();
}

export async function logFeedCrawlEvent(event: ActivityLogEvent): Promise<void> {
  await appendActivityLog('rss-crawl', event);
}

async function listJsonlFiles(dir: string): Promise<string[]> {
  let entries: Array<Awaited<ReturnType<typeof fs.readdir>>[number]>;
  try {
    entries = await fs.readdir(dir, { withFileTypes: true });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw error;
  }

  const files: string[] = [];
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await listJsonlFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.jsonl')) {
      files.push(fullPath);
    }
  }

  return files;
}

export async function getRecentLogEvents(kind: LogKind, limit = 200): Promise<ActivityLogEvent[]> {
  const safeLimit = Math.max(1, Math.min(limit, 1000));
  const files = (await listJsonlFiles(path.join(logRoot, kind))).sort().reverse();
  const lines: string[] = [];

  for (const file of files) {
    const raw = await fs.readFile(file, 'utf8');
    const fileLines = raw.split('\n').filter(Boolean).reverse();
    lines.push(...fileLines);
    if (lines.length >= safeLimit) break;
  }

  return lines.slice(0, safeLimit).map((line) => {
    try {
      return JSON.parse(line) as ActivityLogEvent;
    } catch {
      return { event: 'unparseable_log_line', raw: line };
    }
  });
}
TS

cat > "$SERVICE_FILE" <<'TS'
import { randomUUID } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import Parser from 'rss-parser';
import { z } from 'zod';
import type { FeedCache, FeedItem, ModalitySlug } from '../types/content.js';
import { getAllFeedSources } from './feedRegistry.js';
import { logFeedCrawlEvent } from './activityLog.js';
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
            modalitySlugs: classifyItemModalities(source, title, summary, categories)
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
TS

python3 - <<'PY'
from pathlib import Path

path = Path('src/server.ts')
text = path.read_text()

if "./services/activityLog.js" not in text:
    marker = "import { refreshFeeds } from './services/feedService.js';"
    if marker in text:
        text = text.replace(marker, marker + "\nimport { logPageAccess } from './services/activityLog.js';")
    else:
        # Insert after import block.
        lines = text.splitlines()
        insert_at = 0
        while insert_at < len(lines) and lines[insert_at].startswith('import '):
            insert_at += 1
        lines.insert(insert_at, "import { logPageAccess } from './services/activityLog.js';")
        text = "\n".join(lines) + "\n"

if "app.use(logPageAccess);" not in text:
    target = "app.use(express.static(path.join(__dirname, 'public')));"
    if target in text:
        text = text.replace(target, target + "\napp.use(logPageAccess);")
    else:
        target = "app.use(express.urlencoded({ extended: true }));"
        text = text.replace(target, target + "\napp.use(logPageAccess);")

path.write_text(text)
PY

python3 - <<'PY'
from pathlib import Path

path = Path('src/routes/siteRoutes.ts')
text = path.read_text()

if "./activityLog.js" not in text and "../services/activityLog.js" not in text:
    marker = "import { getFeedCache, getItemsForModality, refreshFeeds } from '../services/feedService.js';"
    if marker in text:
        text = text.replace(marker, marker + "\nimport { getRecentLogEvents } from '../services/activityLog.js';")
    else:
        lines = text.splitlines()
        insert_at = 0
        while insert_at < len(lines) and lines[insert_at].startswith('import '):
            insert_at += 1
        lines.insert(insert_at, "import { getRecentLogEvents } from '../services/activityLog.js';")
        text = "\n".join(lines) + "\n"

if "siteRoutes.get('/logs'" not in text:
    route = r'''

siteRoutes.get('/logs', async (req, res, next) => {
  try {
    const kind = req.query.kind === 'rss-crawl' ? 'rss-crawl' : 'access';
    const rawLimit = Number.parseInt(typeof req.query.limit === 'string' ? req.query.limit : '200', 10);
    const limit = Number.isFinite(rawLimit) ? rawLimit : 200;
    const events = await getRecentLogEvents(kind, limit);

    res.render('logs', {
      title: 'Logs | AI World',
      modalities,
      kind,
      limit,
      events
    });
  } catch (error) {
    next(error);
  }
});
'''
    # Place before admin POST routes if possible, otherwise append.
    marker = "siteRoutes.post('/admin/feeds/add'"
    idx = text.find(marker)
    if idx != -1:
        text = text[:idx] + route + "\n" + text[idx:]
    else:
        text = text.rstrip() + route + "\n"

path.write_text(text)
PY

cat > "$LOG_VIEW_FILE" <<'EJS'
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
        <p class="eyebrow">Operational logging</p>
        <h1>Logs</h1>
        <p class="lead">Page access and RSS gather activity written as JSONL under <code>data/logs/</code>.</p>
      </div>
      <form method="get" action="/logs">
        <label>
          Log type
          <select name="kind">
            <option value="access" <%= kind === 'access' ? 'selected' : '' %>>Website access</option>
            <option value="rss-crawl" <%= kind === 'rss-crawl' ? 'selected' : '' %>>RSS crawl/gather</option>
          </select>
        </label>
        <label>
          Limit
          <input name="limit" value="<%= limit %>" size="5">
        </label>
        <button type="submit">View</button>
      </form>
    </div>

    <p class="meta">Showing <%= events.length %> recent <code><%= kind %></code> events.</p>

    <% if (events.length === 0) { %>
      <article class="feed-item warning">
        <h3>No log events yet</h3>
        <p>Refresh feeds or browse the site, then come back. The logs are not going to write themselves, lazy little bytes.</p>
      </article>
    <% } %>

    <div class="feed-list log-list">
      <% events.forEach((event) => { %>
        <article class="feed-item log-event">
          <h3><%= event.event %></h3>
          <p class="meta"><%= event.ts || '' %></p>
          <pre><code><%= JSON.stringify(event, null, 2) %></code></pre>
        </article>
      <% }) %>
    </div>
  </main>
</body>
</html>
EJS

if [[ -f "$HEADER_FILE" ]] && ! grep -q 'href="/logs"' "$HEADER_FILE"; then
python3 - <<'PY'
from pathlib import Path
path = Path('src/views/partials-header.ejs')
text = path.read_text()
text = text.replace('<a href="/feeds">Feeds</a>', '<a href="/feeds">Feeds</a>\n    <a href="/logs">Logs</a>')
path.write_text(text)
PY
fi

if [[ -f "$ENV_FILE" ]]; then
  if ! grep -q '^AI_WORLD_LOG_DIR=' "$ENV_FILE"; then
    cat >> "$ENV_FILE" <<'ENVADD'

# Structured JSONL logs for website access and RSS crawl/gather activity.
AI_WORLD_LOG_DIR=data/logs

# Leave false unless you explicitly want client IPs in access logs.
AI_WORLD_LOG_IPS=false
ENVADD
  fi
fi

if [[ -f "$GITIGNORE_FILE" ]]; then
  grep -q '^data/logs/$' "$GITIGNORE_FILE" || printf '\ndata/logs/\n' >> "$GITIGNORE_FILE"
fi

python3 - <<'PY'
from pathlib import Path
css = Path('src/public/css/site.css')
if not css.exists():
    raise SystemExit(0)
text = css.read_text()
addition = r'''

select,
input {
  border: 1px solid var(--line);
  border-radius: .55rem;
  background: #0c1328;
  color: var(--text);
  padding: .55rem .65rem;
}

.log-event pre {
  max-height: 28rem;
  overflow: auto;
  white-space: pre-wrap;
  word-break: break-word;
  background: #0c1328;
  border: 1px solid var(--line);
  border-radius: .75rem;
  padding: .85rem;
}
'''
if '.log-event pre' not in text:
    css.write_text(text.rstrip() + addition + '\n')
PY

npm run build

echo "Added structured website access and RSS crawl/gather logging."
