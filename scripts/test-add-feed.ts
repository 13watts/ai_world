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
