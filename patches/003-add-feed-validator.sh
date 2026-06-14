#!/usr/bin/env bash
set -euo pipefail

# Add npm run validate:feeds for a clean post-patch check.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

cat > scripts/validate-feeds.ts <<'TS'
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
TS

python3 - <<'PY'
import json
from pathlib import Path
p = Path('package.json')
data = json.loads(p.read_text())
data.setdefault('scripts', {})['validate:feeds'] = 'tsx scripts/validate-feeds.ts'
p.write_text(json.dumps(data, indent=2) + '\n')
PY

echo "Added feed validator script."
