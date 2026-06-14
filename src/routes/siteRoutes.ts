import { Router } from 'express';
import { getModality, modalities } from '../config/modalities.js';
import { addCustomFeedFromUrl, getAllFeedSources } from '../services/feedRegistry.js';
import { getFeedCache, getItemsForModality, refreshFeeds } from '../services/feedService.js';

export const siteRoutes = Router();

siteRoutes.get('/', async (_req, res, next) => {
  try {
    const cache = await getFeedCache();
    res.render('index', { title: 'AI World', modalities, recentItems: cache.items.slice(0, 12), updatedAt: cache.updatedAt });
  } catch (error) {
    next(error);
  }
});

siteRoutes.get('/modalities/:slug', async (req, res, next) => {
  try {
    const modality = getModality(req.params.slug);
    if (!modality) {
      res.status(404).render('not-found', { title: 'Not Found', modalities });
      return;
    }

    const items = await getItemsForModality(modality.slug);
    const allFeedSources = await getAllFeedSources();
    const sources = allFeedSources.filter((source) => source.modalitySlugs.includes(modality.slug));

    res.render('modality', { title: `${modality.name} | AI World`, modalities, modality, items, sources });
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

siteRoutes.post('/admin/feeds/add', async (req, res) => {
  try {
    const feedUrl = typeof req.body.feedUrl === 'string' ? req.body.feedUrl : '';
    const feedTitle = typeof req.body.feedTitle === 'string' ? req.body.feedTitle : undefined;
    const feed = await addCustomFeedFromUrl(feedUrl, feedTitle);
    await refreshFeeds();
    res.redirect(`/feeds?addedFeed=${encodeURIComponent(feed.title)}`);
  } catch (error) {
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
