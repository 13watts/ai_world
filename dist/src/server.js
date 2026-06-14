import path from 'node:path';
import { fileURLToPath } from 'node:url';
import compression from 'compression';
import cron from 'node-cron';
import dotenv from 'dotenv';
import express from 'express';
import helmet from 'helmet';
import { siteRoutes } from './routes/siteRoutes.js';
import { refreshFeeds } from './services/feedService.js';
dotenv.config();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const app = express();
const port = Number(process.env.PORT ?? 8080);
const refreshCron = process.env.FEED_REFRESH_CRON ?? '*/30 * * * *';
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));
app.use(siteRoutes);
app.use((err, _req, res, _next) => {
    console.error(err);
    res.status(500).render('error', { title: 'Server Error', error: err instanceof Error ? err.message : String(err) });
});
if (cron.validate(refreshCron)) {
    cron.schedule(refreshCron, () => {
        refreshFeeds().catch((error) => console.error('Feed refresh failed', error));
    });
}
refreshFeeds().catch((error) => console.error('Initial feed refresh failed', error));
app.listen(port, () => {
    console.log(`AI World listening at http://localhost:${port}`);
});
