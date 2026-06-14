# AI World

AI World is a Node.js and TypeScript web site that organizes AI resources by modality and aggregates AI-related RSS feeds into the correct modality pages.

The first version includes:

- A front page listing AI modalities
- A dedicated page for each modality
- A configurable RSS source registry
- Feed fetching, de-duplication, keyword-based modality inference, and local JSON cache
- Manual feed refresh page
- Scheduled feed refresh using cron

## GitHub repository

Repository URL:

```text
https://github.com/13watts/ai_world
```

Initial commit and push:

```bash
cd ai_world
git init
git branch -M main
git add .
git commit -m "Initial AI World site"
git remote add origin https://github.com/13watts/ai_world.git
git push -u origin main
```

If the remote already exists locally:

```bash
git remote set-url origin https://github.com/13watts/ai_world.git
git push -u origin main
```

## Project layout

```text
ai_world/
├── src/
│   ├── config/
│   │   ├── feeds.ts
│   │   └── modalities.ts
│   ├── routes/
│   │   └── siteRoutes.ts
│   ├── services/
│   │   └── feedService.ts
│   ├── types/
│   │   └── content.ts
│   ├── views/
│   ├── public/css/site.css
│   └── server.ts
├── scripts/refresh-feeds.ts
├── data/
├── package.json
├── tsconfig.json
└── .env.example
```

## Modalities

The seed modalities are:

- Text & Large Language Models
- Image & Video Generation
- Audio & Speech
- Code & Agents
- Research & Machine Learning
- Infrastructure & MLOps
- Governance, Safety & Policy

Edit `src/config/modalities.ts` to add or rename categories.

## RSS feeds

Edit `src/config/feeds.ts` to add or remove sources. Each feed can be assigned to one or more modalities. During refresh, the service also performs simple keyword-based inference so one source can feed multiple pages when an article clearly belongs elsewhere.

The seed list intentionally mixes official, research, and editorial sources. Some publishers change RSS endpoints without warning, because apparently chaos is a product strategy now. Failed feeds are shown on `/feeds` after refresh.

## Setup

```bash
cd ai_world
cp .env.example .env
npm install
npm run dev
```

Open:

```text
http://localhost:8080
```

## Production build

```bash
npm run build
npm start
```

## Refresh feeds manually

```bash
npm run refresh:feeds
```

Or use the web page:

```text
http://localhost:8080/feeds
```

## Environment variables

```bash
PORT=8080
FEED_REFRESH_CRON=*/30 * * * *
FEED_CACHE_FILE=data/feed-cache.json
MAX_ITEMS_PER_FEED=20
```

## Next useful upgrades

- Add SQLite or PostgreSQL storage instead of JSON cache
- Add admin authentication before exposing refresh controls outside localhost
- Add full-text search
- Add source reliability scoring
- Add OPML export/import
- Add per-feed enable/disable flags
- Add article tagging review workflow
- Add image thumbnails using OpenGraph metadata
