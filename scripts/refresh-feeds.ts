import dotenv from 'dotenv';
import { refreshFeeds } from '../src/services/feedService.js';

dotenv.config();

const cache = await refreshFeeds();
console.log(`Refreshed ${cache.items.length} feed items at ${cache.updatedAt}`);
if (cache.errors.length > 0) {
  console.warn('Feed errors:');
  for (const error of cache.errors) console.warn(`- ${error.sourceId}: ${error.message}`);
}
