/**
 * Express app factory — separated from server.js (which just calls
 * app.listen) so tests can import the app directly without binding a real
 * port, and so a fresh repository can be injected per test for isolation.
 */
const express = require('express');
const cors = require('cors');
const { InMemoryCatalogRepository, NotFoundError, ValidationError } = require('./repository/catalogRepository');
const { MockStreamUrlProvider } = require('./services/streamUrlProvider');
const { SEED_SONGS } = require('./seedData');

function createApp({ repository, streamUrlProvider, enableAdminRoutes = true } = {}) {
  const repo = repository ?? new InMemoryCatalogRepository(SEED_SONGS);
  const streamProvider = streamUrlProvider ?? new MockStreamUrlProvider();

  const app = express();
  app.use(cors());
  app.use(express.json());

  function sendError(res, err) {
    if (err instanceof NotFoundError) {
      return res.status(404).json({ error: { code: 'not_found', message: err.message } });
    }
    if (err instanceof ValidationError) {
      return res.status(400).json({ error: { code: 'validation_error', message: err.message } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'internal_error', message: 'Unexpected server error' } });
  }

  function parseVersionParam(raw) {
    if (raw === undefined) return 0;
    const n = Number(raw);
    if (!Number.isInteger(n) || n < 0) return null; // signals invalid
    return n;
  }

  // --- Delta sync — the core of Phase A ---
  app.get('/api/v1/catalog/sync', (req, res) => {
    const since = parseVersionParam(req.query.version);
    if (since === null) {
      return sendError(res, new ValidationError('`version` must be a non-negative integer'));
    }
    const { upserts, deletions } = repo.getChangesSince(since);
    res.json({
      songs: upserts,
      deletions, // [{ id, version }] — each deletion carries its own version now
      catalogVersion: repo.currentVersion(),
    });
  });

  // Alias: full catalog is just a sync from version 0.
  app.get('/api/v1/catalog', (req, res) => {
    const { upserts } = repo.getChangesSince(0);
    res.json({ songs: upserts, deletions: [], catalogVersion: repo.currentVersion() });
  });

  app.get('/api/v1/songs/:id', (req, res) => {
    const song = repo.getSongById(req.params.id);
    if (!song) return sendError(res, new NotFoundError(`Song "${req.params.id}" not found`));
    res.json(song);
  });

  // See streamUrlProvider.js — this is explicitly a dev mock, not a signed URL.
  app.get('/api/v1/songs/:id/stream', (req, res) => {
    const song = repo.getSongById(req.params.id);
    if (!song) return sendError(res, new NotFoundError(`Song "${req.params.id}" not found`));
    res.json(streamProvider.getStreamUrl(song));
  });

  app.get('/api/v1/songs/:id/download', (req, res) => {
    const song = repo.getSongById(req.params.id);
    if (!song) return sendError(res, new NotFoundError(`Song "${req.params.id}" not found`));
    res.json({
      url: song.downloadUrl,
      fileSizeBytes: song.fileSizeBytes,
      mimeType: song.mimeType,
      isDemoMedia: true,
    });
  });

  app.get('/api/v1/home', (req, res) => {
    const all = repo.getAllSongs();
    res.json({
      recentlyPlayed: all.slice(0, 3),
      forYou: all.slice(3, 6),
      newUploads: all.slice(6),
    });
  });

  // Secondary/future capability per the audit — local Drift search on the
  // client is the primary offline search path. This exists for parity /
  // future server-side ranking, not as the main search mechanism.
  app.get('/api/v1/search', (req, res) => {
    const q = req.query.q;
    if (typeof q !== 'string' || q.trim().length === 0) {
      return sendError(res, new ValidationError('`q` query parameter is required'));
    }
    res.json({ songs: repo.search(q) });
  });

  if (enableAdminRoutes) {
    // Development-only admin/test helpers. Production must use an
    // authenticated admin service instead of exposing these mutations.
    app.post('/api/v1/admin/songs', (req, res) => {
      try {
        const song = repo.addSong(req.body);
        res.status(201).json(song);
      } catch (err) {
        sendError(res, err);
      }
    });

    app.patch('/api/v1/admin/songs/:id', (req, res) => {
      try {
        const song = repo.updateSong(req.params.id, req.body);
        res.json(song);
      } catch (err) {
        sendError(res, err);
      }
    });

    // Back-compat alias for the earlier "touch" endpoint used in manual testing.
    app.post('/api/v1/admin/songs/:id/touch', (req, res) => {
      try {
        const song = repo.updateSong(req.params.id, {});
        res.json(song);
      } catch (err) {
        sendError(res, err);
      }
    });

    app.delete('/api/v1/admin/songs/:id', (req, res) => {
      try {
        const result = repo.deleteSong(req.params.id);
        res.json(result);
      } catch (err) {
        sendError(res, err);
      }
    });
  } else {
    app.use('/api/v1/admin', (req, res) => {
      res.status(404).json({ error: { code: 'not_found', message: 'Admin API is disabled' } });
    });
  }


  // 404 fallback for anything else, kept as structured JSON rather than
  // Express's default HTML error page.
  app.use((req, res) => {
    res.status(404).json({ error: { code: 'not_found', message: `No route for ${req.method} ${req.path}` } });
  });

  return app;
}

module.exports = { createApp };
