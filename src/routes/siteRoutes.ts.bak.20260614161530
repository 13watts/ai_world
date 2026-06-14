import { Router } from 'express';
import { feedSources } from '../config/feeds.js';
import { getModality, modalities } from '../config/modalities.js';
import { getFeedCache, getItemsForModality, refreshFeeds } from '../services/feedService.js';

export const siteRoutes = Router();

siteRoutes.get('/', async (_req, res, next) => {
  try {
    const cache = await getFeedCache();
    res.render('index', {
      title: 'AI World',
      modalities,
      recentItems: cache.items.slice(0, 12),
      updatedAt: cache.updatedAt
    });
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
    const sources = feedSources.filter((source) => source.modalitySlugs.includes(modality.slug));

    res.render('modality', {
      title: `${modality.name} | AI World`,
      modalities,
      modality,
      items,
      sources
    });
  } catch (error) {
    next(error);
  }
});

siteRoutes.get('/feeds', async (_req, res, next) => {
  try {
    const cache = await getFeedCache();
    res.render('feeds', {
      title: 'Feeds | AI World',
      modalities,
      feedSources,
      errors: cache.errors,
      updatedAt: cache.updatedAt
    });
  } catch (error) {
    next(error);
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
