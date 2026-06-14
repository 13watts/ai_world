import fs from 'node:fs/promises';
import path from 'node:path';
import Parser from 'rss-parser';
import { z } from 'zod';
import { feedSources } from '../config/feeds.js';
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
    modalitySlugs: z.array(z.custom()),
    tags: z.array(z.string()),
    reliability: z.literal('community'),
    addedAt: z.string().optional(),
    classification: z.object({ scores: z.record(z.number()), rationale: z.array(z.string()) }).optional()
});
const customFeedListSchema = z.array(customFeedSchema);
function slugify(value) {
    return value.toLowerCase().replace(/^https?:\/\//, '').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80);
}
function stripHtml(value) {
    if (!value)
        return '';
    return value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}
function homepageFromFeedUrl(feedUrl, link) {
    try {
        if (link)
            return new URL(link).origin;
    }
    catch {
        // Fall back to feed URL below.
    }
    return new URL(feedUrl).origin;
}
async function readCustomFeeds() {
    try {
        const raw = await fs.readFile(customFeedFile, 'utf8');
        return customFeedListSchema.parse(JSON.parse(raw));
    }
    catch (error) {
        if (error.code === 'ENOENT')
            return [];
        throw error;
    }
}
async function writeCustomFeeds(feeds) {
    await fs.mkdir(path.dirname(customFeedFile), { recursive: true });
    await fs.writeFile(customFeedFile, JSON.stringify(feeds, null, 2));
}
export async function getAllFeedSources() {
    const customFeeds = await readCustomFeeds();
    return [...feedSources, ...customFeeds];
}
export async function addCustomFeedFromUrl(feedUrl, requestedTitle) {
    const url = z.string().url().parse(feedUrl.trim());
    const existingFeeds = await readCustomFeeds();
    const allFeeds = [...feedSources, ...existingFeeds];
    if (allFeeds.some((feed) => feed.url === url))
        throw new Error('That feed URL is already configured. Duplication: still not a feature.');
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
    const feed = {
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
