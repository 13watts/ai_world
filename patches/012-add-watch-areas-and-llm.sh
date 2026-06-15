#!/usr/bin/env bash
set -euo pipefail

# Adds dynamic Watch Areas alongside modality pages.
# This keeps modalities as “how AI behaves” and watch areas as “what we track.”

ROOT="$(pwd)"
	required=(
  "src/types/content.ts"
  "src/services/feedService.ts"
  "src/routes/siteRoutes.ts"
  "src/views/index.ejs"
  "src/views/partials-header.ejs"
)

for f in "${required[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: $f not found. Run this from the ai_world repo root." >&2
    exit 1
  fi
done

stamp="$(date +%Y%m%d%H%M%S)"
for f in "${required[@]}"; do
  cp "$f" "$f.bak.$stamp"
done

mkdir -p src/config src/services src/views

cat > src/config/watchAreas.ts <<'TS'
import type { WatchArea } from '../types/content.js';

export const watchAreas: WatchArea[] = [
  {
    slug: 'llms',
    name: 'Large Language Models',
    summary: 'Model releases, LLM architecture, reasoning, context windows, alignment, inference, fine-tuning, and deployment patterns.',
    modalitySlugs: ['text-llms', 'research-ml', 'infra-mlops', 'governance-safety'],
    keywords: [
      'llm', 'large language model', 'language model', 'foundation model', 'frontier model',
      'gpt', 'claude', 'gemini', 'llama', 'mistral', 'mixtral', 'qwen', 'deepseek',
      'reasoning model', 'context window', 'tokens', 'fine-tuning', 'instruction tuning',
      'alignment', 'prompting', 'inference', 'model release', 'benchmark'
    ]
  },
  {
    slug: 'agents',
    name: 'Agents & Tool Use',
    summary: 'Autonomous agents, tool calling, browser/computer use, MCP, coding agents, workflow execution, and long-running tasks.',
    modalitySlugs: ['code-agents', 'text-llms', 'infra-mlops', 'governance-safety'],
    keywords: [
      'agent', 'agents', 'agentic', 'tool use', 'tool calling', 'function calling',
      'mcp', 'model context protocol', 'computer use', 'browser use', 'workflow automation',
      'coding agent', 'autonomous', 'planner', 'multi-agent', 'orchestration'
    ]
  },
  {
    slug: 'rag-knowledge',
    name: 'RAG & Knowledge Systems',
    summary: 'Retrieval-augmented generation, vector search, embeddings, semantic search, document intelligence, and grounding.',
    modalitySlugs: ['text-llms', 'infra-mlops', 'research-ml'],
    keywords: [
      'rag', 'retrieval augmented generation', 'retrieval-augmented generation', 'retrieval',
      'vector database', 'vector search', 'semantic search', 'embedding', 'embeddings',
      'chunking', 'grounding', 'citations', 'knowledge base', 'document intelligence',
      'hybrid search', 'reranker', 'reranking'
    ]
  },
  {
    slug: 'multimodal-ai',
    name: 'Multimodal AI',
    summary: 'Systems combining text, image, video, audio, documents, charts, spatial context, and cross-modal reasoning.',
    modalitySlugs: ['text-llms', 'image-video', 'audio-speech', 'research-ml'],
    keywords: [
      'multimodal', 'multi-modal', 'vision language', 'vision-language', 'vlm', 'mlm',
      'image understanding', 'video understanding', 'audio understanding', 'document understanding',
      'ocr', 'layout', 'cross-modal', 'speech', 'vision', 'video'
    ]
  },
  {
    slug: 'evaluation-benchmarks',
    name: 'Evaluation & Benchmarks',
    summary: 'Model evaluation, benchmarks, safety testing, factuality, hallucination measurement, and real-world performance tracking.',
    modalitySlugs: ['research-ml', 'governance-safety', 'infra-mlops'],
    keywords: [
      'benchmark', 'benchmarks', 'eval', 'evaluation', 'leaderboard', 'mmlu', 'gpqa',
      'swe-bench', 'humaneval', 'mmmu', 'helm', 'safety benchmark', 'factuality',
      'hallucination', 'red team', 'red-teaming', 'model card', 'scorecard'
    ]
  },
  {
    slug: 'ai-infrastructure',
    name: 'AI Infrastructure & Inference',
    summary: 'GPUs, accelerators, inference servers, model serving, quantization, orchestration, observability, and production AI operations.',
    modalitySlugs: ['infra-mlops', 'code-agents', 'research-ml'],
    keywords: [
      'gpu', 'nvidia', 'cuda', 'accelerator', 'inference', 'serving', 'model serving',
      'quantization', 'distillation', 'latency', 'throughput', 'vllm', 'triton', 'onnx',
      'kubernetes', 'observability', 'mlops', 'monitoring', 'deployment'
    ]
  },
  {
    slug: 'ai-safety-governance',
    name: 'AI Safety, Governance & Policy',
    summary: 'AI regulation, safety research, governance frameworks, model risk, privacy, compliance, and responsible AI.',
    modalitySlugs: ['governance-safety', 'research-ml'],
    keywords: [
      'safety', 'governance', 'policy', 'regulation', 'regulatory', 'compliance',
      'privacy', 'security', 'responsible ai', 'model risk', 'risk management',
      'alignment', 'jailbreak', 'misuse', 'incident', 'transparency', 'audit'
    ]
  },
  {
    slug: 'data-datasets',
    name: 'Data, Datasets & Synthetic Data',
    summary: 'Training data, dataset releases, data quality, data governance, synthetic data, labeling, licensing, and provenance.',
    modalitySlugs: ['research-ml', 'infra-mlops', 'governance-safety'],
    keywords: [
      'dataset', 'datasets', 'training data', 'data quality', 'synthetic data', 'labeling',
      'annotation', 'data governance', 'provenance', 'license', 'licensing', 'copyright',
      'data curation', 'data pipeline'
    ]
  },
  {
    slug: 'robotics-embodied-ai',
    name: 'Robotics & Embodied AI',
    summary: 'Robotics, embodied agents, spatial reasoning, autonomous vehicles, manipulation, simulation, and physical-world AI.',
    modalitySlugs: ['research-ml', 'image-video', 'code-agents'],
    keywords: [
      'robot', 'robotics', 'embodied', 'embodied ai', 'autonomous vehicle', 'self-driving',
      'manipulation', 'simulator', 'simulation', 'navigation', 'spatial reasoning',
      'world model', 'humanoid', 'control policy'
    ]
  },
  {
    slug: 'edge-on-device-ai',
    name: 'Edge & On-Device AI',
    summary: 'Local inference, small models, NPUs, mobile AI, browser AI, private inference, and disconnected/low-latency deployment.',
    modalitySlugs: ['infra-mlops', 'text-llms', 'image-video', 'audio-speech'],
    keywords: [
      'edge ai', 'on-device', 'local ai', 'mobile ai', 'npu', 'small language model',
      'slm', 'tinyml', 'browser ai', 'webgpu', 'local inference', 'private inference',
      'offline', 'low latency'
    ]
  }
];

export function getWatchArea(slug: string): WatchArea | undefined {
  return watchAreas.find((watchArea) => watchArea.slug === slug);
}
TS

cat > src/services/watchAreaClassifier.ts <<'TS'
import type { FeedItem, FeedSource, WatchAreaSlug } from '../types/content.js';
import { watchAreas } from '../config/watchAreas.js';

function normalize(value: string | undefined): string {
  return (value ?? '').toLowerCase();
}

function countKeywordMatches(haystack: string, keywords: string[]): number {
  let score = 0;

  for (const keyword of keywords) {
    const needle = keyword.toLowerCase();
    if (!needle) continue;

    if (haystack.includes(needle)) {
      score += needle.includes(' ') || needle.includes('-') ? 3 : 2;
    }
  }

  return score;
}

export function classifyItemWatchAreas(
  source: FeedSource,
  title: string,
  summary: string | undefined,
  categories: string[]
): WatchAreaSlug[] {
  const titleText = normalize(title);
  const summaryText = normalize(summary);
  const categoryText = categories.map((category) => normalize(category)).join(' ');
  const sourceText = [source.title, source.tags.join(' '), source.modalitySlugs.join(' ')].map(normalize).join(' ');
  const combined = `${titleText} ${titleText} ${summaryText} ${categoryText} ${sourceText}`;

  const scored = watchAreas
    .map((watchArea) => {
      let score = countKeywordMatches(combined, watchArea.keywords);

      for (const modalitySlug of source.modalitySlugs) {
        if (watchArea.modalitySlugs.includes(modalitySlug)) score += 1;
      }

      return { slug: watchArea.slug, score };
    })
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score);

  const selected = scored.slice(0, 4).map((entry) => entry.slug as WatchAreaSlug);

  if (selected.length > 0) return selected;

  // Reasonable fallback when a feed item is relevant but too generic to score cleanly.
  if (source.modalitySlugs.includes('text-llms')) return ['llms'];
  if (source.modalitySlugs.includes('infra-mlops')) return ['ai-infrastructure'];
  if (source.modalitySlugs.includes('governance-safety')) return ['ai-safety-governance'];
  return ['llms'];
}

export function getWatchAreaNamesForItem(item: FeedItem): string[] {
  const slugs = item.watchAreaSlugs ?? [];
  return slugs
    .map((slug) => watchAreas.find((watchArea) => watchArea.slug === slug)?.name)
    .filter((name): name is string => Boolean(name));
}
TS

cat > src/views/watch-index.ejs <<'EJS'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%= title %></title>
  <link rel="stylesheet" href="/css/site.css">
</head>
<body>
  <%- include('partials-header', { modalities, watchAreas }) %>
  <main class="layout">
    <section class="hero">
      <p class="eyebrow">Dynamic watch areas</p>
      <h1>Track cross-cutting AI topics without turning modalities into alphabet soup.</h1>
      <p>Watch areas are generated from RSS item titles, summaries, tags, and source metadata. A single item can appear in multiple watch areas when it crosses boundaries.</p>
    </section>

    <section>
      <h2>Watch areas</h2>
      <div class="cards">
        <% watchAreas.forEach((watchArea) => { %>
          <article class="card">
            <h3><a href="/watch/<%= watchArea.slug %>"><%= watchArea.name %></a></h3>
            <p><%= watchArea.summary %></p>
            <p class="tags"><%= watchArea.keywords.slice(0, 8).join(' · ') %></p>
          </article>
        <% }) %>
      </div>
    </section>
  </main>
</body>
</html>
EJS

cat > src/views/watch-area.ejs <<'EJS'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%= title %></title>
  <link rel="stylesheet" href="/css/site.css">
</head>
<body>
  <%- include('partials-header', { modalities, watchAreas }) %>
  <main class="layout two-column">
    <section>
      <p class="eyebrow">Watch area</p>
      <h1><%= watchArea.name %></h1>
      <p class="lead"><%= watchArea.summary %></p>

      <h2>Latest resources</h2>
      <div class="feed-list">
        <% if (items.length === 0) { %><p>No feed items found for this watch area yet.</p><% } %>
        <% items.forEach((item) => { %>
          <article class="feed-item">
            <h3><a href="<%= item.link %>" target="_blank" rel="noopener noreferrer"><%= item.title %></a></h3>
            <p class="meta"><%= item.sourceTitle %><% if (item.isoDate) { %> · <%= new Date(item.isoDate).toLocaleDateString() %><% } %></p>
            <% if (item.summary) { %><p><%= item.summary %></p><% } %>
            <p class="tags"><%= item.categories.slice(0, 6).join(' · ') %></p>
            <p class="meta">Modalities: <%= item.modalitySlugs.join(', ') %></p>
            <p class="meta">Watch areas: <%= (item.watchAreaSlugs ?? []).join(', ') %></p>
          </article>
        <% }) %>
      </div>
    </section>

    <aside class="sidebar">
      <h2>Routing profile</h2>
      <p><strong>Related modalities:</strong> <%= watchArea.modalitySlugs.join(', ') %></p>
      <p><strong>Keywords:</strong></p>
      <p class="tags"><%= watchArea.keywords.join(' · ') %></p>
    </aside>
  </main>
</body>
</html>
EJS

cat > src/views/partials-header.ejs <<'EJS'
<header class="site-header">
  <a class="brand" href="/">AI World</a>
  <nav>
    <a href="/feeds">Feeds</a>
    <a href="/watch">Watch</a>
    <% modalities.forEach((modality) => { %>
      <a href="/modalities/<%= modality.slug %>"><%= modality.name.split('&')[0].trim() %></a>
    <% }) %>
  </nav>
</header>
EJS

python3 - <<'PY'
from pathlib import Path

# Patch content types.
path = Path('src/types/content.ts')
text = path.read_text()

if 'export type WatchAreaSlug' not in text:
    insert_after = """export type ModalitySlug =\n  | 'text-llms'\n  | 'image-video'\n  | 'audio-speech'\n  | 'code-agents'\n  | 'research-ml'\n  | 'infra-mlops'\n  | 'governance-safety';\n"""
    watch_type = """

export type WatchAreaSlug =
  | 'llms'
  | 'agents'
  | 'rag-knowledge'
  | 'multimodal-ai'
  | 'evaluation-benchmarks'
  | 'ai-infrastructure'
  | 'ai-safety-governance'
  | 'data-datasets'
  | 'robotics-embodied-ai'
  | 'edge-on-device-ai';
"""
    if insert_after not in text:
        raise SystemExit('ERROR: Could not find ModalitySlug block to patch.')
    text = text.replace(insert_after, insert_after + watch_type)

if 'export interface WatchArea' not in text:
    marker = """export interface Modality {\n  slug: ModalitySlug;\n  name: string;\n  summary: string;\n  examples: string[];\n}\n"""
    addition = """

export interface WatchArea {
  slug: WatchAreaSlug;
  name: string;
  summary: string;
  modalitySlugs: ModalitySlug[];
  keywords: string[];
}
"""
    if marker not in text:
        raise SystemExit('ERROR: Could not find Modality interface to patch.')
    text = text.replace(marker, marker + addition)

if 'watchAreaSlugs?: WatchAreaSlug[];' not in text:
    text = text.replace(
        '  modalitySlugs: ModalitySlug[];\n}',
        '  modalitySlugs: ModalitySlug[];\n  watchAreaSlugs?: WatchAreaSlug[];\n}',
        1,
    )

path.write_text(text)

# Patch feed service.
path = Path('src/services/feedService.ts')
text = path.read_text()
text = text.replace(
    "import type { FeedCache, FeedItem, ModalitySlug } from '../types/content.js';",
    "import type { FeedCache, FeedItem, ModalitySlug, WatchAreaSlug } from '../types/content.js';"
)
if "import { classifyItemWatchAreas } from './watchAreaClassifier.js';" not in text:
    text = text.replace(
        "import { classifyItemModalities } from './modalityClassifier.js';\n",
        "import { classifyItemModalities } from './modalityClassifier.js';\nimport { classifyItemWatchAreas } from './watchAreaClassifier.js';\n"
    )

needle = "modalitySlugs: classifyItemModalities(source, title, summary, categories)"
if needle in text and "watchAreaSlugs: classifyItemWatchAreas" not in text:
    text = text.replace(
        needle,
        "modalitySlugs: classifyItemModalities(source, title, summary, categories),\n            watchAreaSlugs: classifyItemWatchAreas(source, title, summary, categories)"
    )

if 'export async function getItemsForWatchArea' not in text:
    text += """

export async function getItemsForWatchArea(slug: string, limit = 50): Promise<FeedItem[]> {
  const cache = await getFeedCache();
  return cache.items.filter((item) => (item.watchAreaSlugs ?? []).includes(slug as WatchAreaSlug)).slice(0, limit);
}
"""
path.write_text(text)

# Patch routes.
path = Path('src/routes/siteRoutes.ts')
text = path.read_text()
if "import { getWatchArea, watchAreas } from '../config/watchAreas.js';" not in text:
    text = text.replace(
        "import { getModality, modalities } from '../config/modalities.js';\n",
        "import { getModality, modalities } from '../config/modalities.js';\nimport { getWatchArea, watchAreas } from '../config/watchAreas.js';\n"
    )

text = text.replace(
    "import { getFeedCache, getItemsForModality, refreshFeeds } from '../services/feedService.js';",
    "import { getFeedCache, getItemsForModality, getItemsForWatchArea, refreshFeeds } from '../services/feedService.js';"
)

text = text.replace(
    "res.render('index', { title: 'AI World', modalities, recentItems: cache.items.slice(0, 12), updatedAt: cache.updatedAt });",
    "res.render('index', { title: 'AI World', modalities, watchAreas, recentItems: cache.items.slice(0, 12), updatedAt: cache.updatedAt });"
)

text = text.replace(
    "res.status(404).render('not-found', { title: 'Not Found', modalities });",
    "res.status(404).render('not-found', { title: 'Not Found', modalities, watchAreas });"
)

text = text.replace(
    "res.render('modality', { title: `${modality.name} | AI World`, modalities, modality, items, sources });",
    "res.render('modality', { title: `${modality.name} | AI World`, modalities, watchAreas, modality, items, sources });"
)

text = text.replace(
    "title: 'Feeds | AI World',\n      modalities,",
    "title: 'Feeds | AI World',\n      modalities,\n      watchAreas,"
)

if "siteRoutes.get('/watch'" not in text:
    insert = """

siteRoutes.get('/watch', async (_req, res, next) => {
  try {
    res.render('watch-index', { title: 'Watch Areas | AI World', modalities, watchAreas });
  } catch (error) {
    next(error);
  }
});

siteRoutes.get('/watch/:slug', async (req, res, next) => {
  try {
    const watchArea = getWatchArea(req.params.slug);
    if (!watchArea) {
      res.status(404).render('not-found', { title: 'Not Found', modalities, watchAreas });
      return;
    }

    const items = await getItemsForWatchArea(watchArea.slug);
    res.render('watch-area', { title: `${watchArea.name} | AI World`, modalities, watchAreas, watchArea, items });
  } catch (error) {
    next(error);
  }
});
"""
    marker = "\nsiteRoutes.get('/modalities/:slug'"
    if marker in text:
        text = text.replace(marker, insert + marker)
    else:
        text += insert

path.write_text(text)

# Patch index page to show watch areas.
path = Path('src/views/index.ejs')
text = path.read_text()
if '<h2>Watch areas</h2>' not in text:
    section = """

    <section>
      <h2>Watch areas</h2>
      <div class="cards">
        <% watchAreas.forEach((watchArea) => { %>
          <article class="card">
            <h3><a href="/watch/<%= watchArea.slug %>"><%= watchArea.name %></a></h3>
            <p><%= watchArea.summary %></p>
            <p class="tags"><%= watchArea.keywords.slice(0, 6).join(' · ') %></p>
          </article>
        <% }) %>
      </div>
    </section>
"""
    marker = "\n    <section>\n      <div class=\"section-heading\">\n        <h2>Latest AI items</h2>"
    if marker in text:
        text = text.replace(marker, section + marker)
    else:
        text = text.replace('</main>', section + '\n  </main>')
path.write_text(text)
PY

# Add a little styling only if not already present.
if ! grep -q "watch-area" src/public/css/site.css 2>/dev/null; then
  cat >> src/public/css/site.css <<'CSS'

.watch-area-pill {
  display: inline-block;
  margin: 0.15rem 0.25rem 0.15rem 0;
  padding: 0.2rem 0.45rem;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 999px;
  font-size: 0.85rem;
}
CSS
fi

npm run build

echo "Added dynamic Watch Areas with LLM tracking."
echo "Open /watch or /watch/llms after refreshing feeds."
