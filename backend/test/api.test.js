const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { createApp } = require('../src/app');
const { InMemoryCatalogRepository } = require('../src/repository/catalogRepository');

const seed = [
  { id: 's1', title: 'Midnight Drift', artist: 'Arka Sen', streamUrl: 'https://example.test/1.mp3', downloadUrl: 'https://example.test/1.mp3' },
  { id: 's2', title: 'Neon Hours', artist: 'Levit', streamUrl: 'https://example.test/2.mp3', downloadUrl: 'https://example.test/2.mp3' },
  { id: 's3', title: 'Static Bloom', artist: 'Rhea K.', streamUrl: 'https://example.test/3.mp3', downloadUrl: 'https://example.test/3.mp3' },
];

// Fresh app + repository per test — no shared mutable state leaking
// between tests, which the earlier ad-hoc curl testing had no way to
// guarantee.
function freshApp() {
  const repository = new InMemoryCatalogRepository(seed);
  return createApp({ repository });
}

describe('GET /api/v1/catalog/sync', () => {
  test('version=0 returns the full seeded catalog', async () => {
    const res = await request(freshApp()).get('/api/v1/catalog/sync?version=0');
    assert.equal(res.status, 200);
    assert.equal(res.body.songs.length, 3);
    assert.equal(res.body.deletions.length, 0);
    assert.equal(res.body.catalogVersion, 3);
  });

  test('delta sync from a mid version returns only later changes', async () => {
    const app = freshApp();
    await request(app).post('/api/v1/admin/songs/s2/touch'); // version 4
    const res = await request(app).get('/api/v1/catalog/sync?version=3');
    assert.equal(res.status, 200);
    assert.equal(res.body.songs.length, 1);
    assert.equal(res.body.songs[0].id, 's2');
  });

  test('repeated sync at the current version returns an empty diff both times', async () => {
    const app = freshApp();
    const first = await request(app).get('/api/v1/catalog/sync?version=3');
    const second = await request(app).get('/api/v1/catalog/sync?version=3');
    assert.deepEqual(first.body.songs, []);
    assert.deepEqual(second.body.songs, []);
    assert.equal(first.body.catalogVersion, second.body.catalogVersion);
  });

  test('rejects a non-numeric version with 400, not a silent fallback to 0', async () => {
    const res = await request(freshApp()).get('/api/v1/catalog/sync?version=notanumber');
    assert.equal(res.status, 400);
    assert.equal(res.body.error.code, 'validation_error');
  });

  test('rejects a negative version with 400', async () => {
    const res = await request(freshApp()).get('/api/v1/catalog/sync?version=-1');
    assert.equal(res.status, 400);
  });
});

describe('Admin mutation endpoints -> reflected correctly in next sync', () => {
  test('POST add -> shows up as an upsert in the next delta sync', async () => {
    const app = freshApp();
    const checkpoint = (await request(app).get('/api/v1/catalog/sync?version=0')).body.catalogVersion;
    const addRes = await request(app)
      .post('/api/v1/admin/songs')
      .send({ id: 's4', title: 'Amber Skies', artist: 'Nova Loop' });
    assert.equal(addRes.status, 201);

    const sync = await request(app).get(`/api/v1/catalog/sync?version=${checkpoint}`);
    assert.equal(sync.body.songs.length, 1);
    assert.equal(sync.body.songs[0].id, 's4');
  });

  test('PATCH update -> shows up as an upsert, not a duplicate add', async () => {
    const app = freshApp();
    const checkpoint = (await request(app).get('/api/v1/catalog/sync?version=0')).body.catalogVersion;
    const patchRes = await request(app).patch('/api/v1/admin/songs/s1').send({ title: 'Midnight Drift (Remix)' });
    assert.equal(patchRes.status, 200);
    assert.equal(patchRes.body.title, 'Midnight Drift (Remix)');

    const sync = await request(app).get(`/api/v1/catalog/sync?version=${checkpoint}`);
    assert.equal(sync.body.songs.length, 1);
    assert.equal(sync.body.songs[0].title, 'Midnight Drift (Remix)');
  });

  test('DELETE -> shows up in deletions[] with its own version, not in songs[]', async () => {
    const app = freshApp();
    const checkpoint = (await request(app).get('/api/v1/catalog/sync?version=0')).body.catalogVersion;
    const delRes = await request(app).delete('/api/v1/admin/songs/s3');
    assert.equal(delRes.status, 200);
    assert.equal(delRes.body.id, 's3');
    assert.ok(delRes.body.version > checkpoint);

    const sync = await request(app).get(`/api/v1/catalog/sync?version=${checkpoint}`);
    assert.equal(sync.body.songs.some((s) => s.id === 's3'), false);
    assert.equal(sync.body.deletions.some((d) => d.id === 's3'), true);
  });

  test('updating a non-existent song returns 404', async () => {
    const res = await request(freshApp()).patch('/api/v1/admin/songs/nope').send({ title: 'x' });
    assert.equal(res.status, 404);
    assert.equal(res.body.error.code, 'not_found');
  });

  test('deleting a non-existent song returns 404', async () => {
    const res = await request(freshApp()).delete('/api/v1/admin/songs/nope');
    assert.equal(res.status, 404);
  });

  test('adding without title/artist returns 400', async () => {
    const res = await request(freshApp()).post('/api/v1/admin/songs').send({ id: 'bad' });
    assert.equal(res.status, 400);
    assert.equal(res.body.error.code, 'validation_error');
  });
});

describe('Admin route safety and validation', () => {
  test('production-mode app disables development admin mutations', async () => {
    const repository = new InMemoryCatalogRepository(seed);
    const app = createApp({ repository, enableAdminRoutes: false });
    const res = await request(app).post('/api/v1/admin/songs').send({
      id: 'blocked', title: 'Blocked', artist: 'Nope',
    });
    assert.equal(res.status, 404);
    assert.equal(res.body.error.message, 'Admin API is disabled');
  });

  test('touch endpoint bumps version without accepting client-controlled timestamps', async () => {
    const app = freshApp();
    const before = (await request(app).get('/api/v1/catalog/sync?version=0')).body.catalogVersion;
    const res = await request(app).post('/api/v1/admin/songs/s1/touch');
    assert.equal(res.status, 200);
    assert.equal(res.body.version, before + 1);
  });
});

describe('GET /api/v1/songs/:id and /stream and /download', () => {
  test('fetches a single song', async () => {
    const res = await request(freshApp()).get('/api/v1/songs/s1');
    assert.equal(res.status, 200);
    assert.equal(res.body.title, 'Midnight Drift');
  });

  test('404 for a missing song', async () => {
    const res = await request(freshApp()).get('/api/v1/songs/does-not-exist');
    assert.equal(res.status, 404);
  });

  test('stream endpoint explicitly marks the URL as demo/mock, not signed', async () => {
    const res = await request(freshApp()).get('/api/v1/songs/s1/stream');
    assert.equal(res.status, 200);
    assert.equal(res.body.mode, 'mock-public-demo');
    assert.equal(res.body.isDemoMedia, true);
    // Must NOT claim a real expiry it doesn't enforce.
    assert.equal(res.body.expiresAt, undefined);
  });

  test('download endpoint also marks isDemoMedia', async () => {
    const res = await request(freshApp()).get('/api/v1/songs/s1/download');
    assert.equal(res.status, 200);
    assert.equal(res.body.isDemoMedia, true);
  });
});

describe('GET /api/v1/search (secondary/backend search)', () => {
  test('matches by title', async () => {
    const res = await request(freshApp()).get('/api/v1/search?q=neon');
    assert.equal(res.status, 200);
    assert.equal(res.body.songs.length, 1);
    assert.equal(res.body.songs[0].id, 's2');
  });

  test('missing query param returns 400, not an empty-catalog dump', async () => {
    const res = await request(freshApp()).get('/api/v1/search');
    assert.equal(res.status, 400);
  });
});

describe('Unknown routes', () => {
  test('return structured 404 JSON, not Express default HTML', async () => {
    const res = await request(freshApp()).get('/api/v1/nonexistent');
    assert.equal(res.status, 404);
    assert.equal(res.body.error.code, 'not_found');
  });
});
