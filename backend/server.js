/**
 * Entry point — binds the Express app (built in src/app.js) to a real port.
 * Kept separate from app.js so tests can import createApp() without
 * opening a network listener.
 */
const { createApp } = require('./src/app');

const PORT = process.env.PORT || 3000;
const isProduction = process.env.NODE_ENV === 'production';
const enableAdminRoutes = !isProduction && process.env.ENABLE_DEV_ADMIN !== 'false';
const app = createApp({ enableAdminRoutes });

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Infinite Music mock backend listening on http://0.0.0.0:${PORT}`);
  console.log(`From the Android emulator, reach it at http://10.0.2.2:${PORT}`);
  console.log('NOTE: streaming URLs are unsigned public demo media (see src/services/streamUrlProvider.js) — not production security.');
});
