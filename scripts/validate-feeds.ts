import 'dotenv/config';
import { refreshFeeds } from '../src/services/feedService.js';

const cache = await refreshFeeds();

console.log(`Feed refresh completed at ${cache.updatedAt}`);
console.log(`Items cached: ${cache.items.length}`);

if (cache.errors.length > 0) {
  console.error('\nFeed warnings:');
  for (const error of cache.errors) {
    console.error(`- ${error.sourceId}: ${error.message}`);
  }
  process.exitCode = 1;
} else {
  console.log('No feed warnings. The machines have briefly behaved.');
}
