import { Router } from 'express';
import { getModality, modalities } from '../config/modalities.js';
import { getWatchArea, watchAreas } from '../config/watchAreas.js';
import { addCustomFeedFromUrl, getAllFeedSources } from '../services/feedRegistry.js';
import { getFeedCache, getItemsForModality, getItemsForWatchArea, refreshFeeds } from '../services/feedService.js';
import { getRecentLogEvents } from '../services/activityLog.js';

export const siteRoutes = Router();

siteRoutes.get('/', async (_req, res, next) => {
  try {
    const cache = await getFeedCache();
    res.render('index', { title: 'AI World', modalities, watchAreas, recentItems: cache.items.slice(0, 12), updatedAt: cache.updatedAt });
  } catch (error) {
    next(error);
  }
});


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

siteRoutes.get('/modalities/:slug', async (req, res, next) => {
  try {
    const modality = getModality(req.params.slug);
    if (!modality) {
      res.status(404).render('not-found', { title: 'Not Found', modalities, watchAreas });
      return;
    }

    const items = await getItemsForModality(modality.slug);
    const allFeedSources = await getAllFeedSources();
    const sources = allFeedSources.filter((source) => source.modalitySlugs.includes(modality.slug));

    res.render('modality', { title: `${modality.name} | AI World`, modalities, watchAreas, modality, items, sources });
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
      watchAreas,
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

siteRoutes.post('/admin/feeds/add', async (req, res) => {
  try {
    const feedUrl = typeof req.body.feedUrl === 'string' ? req.body.feedUrl : '';
    const feedTitle = typeof req.body.feedTitle === 'string' ? req.body.feedTitle : undefined;
    const feed = await addCustomFeedFromUrl(feedUrl, feedTitle);
    await refreshFeeds();
    res.redirect(`/feeds?addedFeed=${encodeURIComponent(feed.title)}`);
  } catch (error) {
    console.error('[feeds] Add feed failed:', error);
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
