#!/usr/bin/env bash
set -euo pipefail

# Patch feed source definitions that generated known warnings:
# - anthropic-news: old /news/rss.xml returned 404, use RSSHub route with fallback.
# - google-deepmind: old deepmind.google/discover/blog/rss.xml returned 404, use Google Blog RSS category.
# - FeedSource type: add fallbackUrls and enabled flags.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

python3 - <<'PY'
from pathlib import Path

content_ts = Path('src/types/content.ts')
text = content_ts.read_text()
text = text.replace("""export interface FeedSource {
  id: string;
  title: string;
  url: string;
  homepage: string;
  modalitySlugs: ModalitySlug[];
  tags: string[];
  reliability: 'official' | 'research' | 'editorial' | 'community';
}""", """export interface FeedSource {
  id: string;
  title: string;
  url: string;
  homepage: string;
  fallbackUrls?: string[];
  enabled?: boolean;
  modalitySlugs: ModalitySlug[];
  tags: string[];
  reliability: 'official' | 'research' | 'editorial' | 'community';
}""")
content_ts.write_text(text)

feeds_ts = Path('src/config/feeds.ts')
text = feeds_ts.read_text()
text = text.replace("""  {
    id: 'anthropic-news',
    title: 'Anthropic News',
    url: 'https://www.anthropic.com/news/rss.xml',
    homepage: 'https://www.anthropic.com/news',
    modalitySlugs: ['text-llms', 'code-agents', 'research-ml', 'governance-safety'],
    tags: ['Claude', 'agents', 'AI safety'],
    reliability: 'official'
  },""", """  {
    id: 'anthropic-news',
    title: 'Anthropic News',
    url: 'https://rsshub.app/anthropic/news',
    homepage: 'https://www.anthropic.com/news',
    fallbackUrls: ['https://rsshub.rssforever.com/anthropic/news'],
    modalitySlugs: ['text-llms', 'code-agents', 'research-ml', 'governance-safety'],
    tags: ['Claude', 'agents', 'AI safety'],
    reliability: 'community'
  },""")
text = text.replace("""  {
    id: 'google-deepmind',
    title: 'Google DeepMind Blog',
    url: 'https://deepmind.google/discover/blog/rss.xml',
    homepage: 'https://deepmind.google/discover/blog/',
    modalitySlugs: ['research-ml', 'text-llms', 'image-video', 'governance-safety'],
    tags: ['research', 'frontier models', 'science'],
    reliability: 'official'
  },""", """  {
    id: 'google-deepmind',
    title: 'Google DeepMind via Google Blog',
    url: 'https://blog.google/innovation-and-ai/models-and-research/google-deepmind/rss/',
    homepage: 'https://blog.google/innovation-and-ai/models-and-research/google-deepmind/',
    fallbackUrls: ['https://blog.google/technology/ai/rss/'],
    modalitySlugs: ['research-ml', 'text-llms', 'image-video', 'governance-safety'],
    tags: ['research', 'frontier models', 'science'],
    reliability: 'official'
  },""")
feeds_ts.write_text(text)
PY

echo "Patched feed source definitions."
