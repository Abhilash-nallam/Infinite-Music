const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { InMemoryCatalogRepository, NotFoundError, ValidationError } = require('../src/repository/catalogRepository');

const seed = [
  { id: 'x1', title: 'A', artist: 'Artist A' },
  { id: 'x2', title: 'B', artist: 'Artist B' },
  { id: 'x3', title: 'C', artist: 'Artist C' },
];

describe('InMemoryCatalogRepository — versioning core', () => {
  test('initial full sync (version=0) returns every seeded song', () => {
    const repo = new InMemoryCatalogRepository(seed);
    const { upserts, deletions } = repo.getChangesSince(0);
    assert.equal(upserts.length, 3);
    assert.equal(deletions.length, 0);
    assert.equal(repo.currentVersion(), 3); // one version per seed insert
  });

  test('delta sync only returns changes strictly after the requested version', () => {
    const repo = new InMemoryCatalogRepository(seed); // versions 1,2,3 used
    repo.updateSong('x2', { title: 'B updated' }); // version 4
    const { upserts, deletions } = repo.getChangesSince(3);
    assert.equal(upserts.length, 1);
    assert.equal(upserts[0].id, 'x2');
    assert.equal(upserts[0].title, 'B updated');
    assert.equal(deletions.length, 0);
  });

  test('add assigns a new, unique, increasing version', () => {
    const repo = new InMemoryCatalogRepository(seed); // versions 1-3
    const before = repo.currentVersion();
    const added = repo.addSong({ id: 'x4', title: 'D', artist: 'Artist D' });
    assert.equal(added.version, before + 1);
    assert.equal(repo.currentVersion(), before + 1);
  });

  test('update assigns a new version and changes updatedAt', () => {
    const repo = new InMemoryCatalogRepository(seed);
    const original = repo.getSongById('x1');
    const updated = repo.updateSong('x1', { title: 'A renamed' });
    assert.equal(updated.title, 'A renamed');
    assert.ok(updated.version > original.version);
    assert.ok(updated.updatedAt >= original.updatedAt);
  });

  test('delete removes the song from live results AND carries its own version', () => {
    const repo = new InMemoryCatalogRepository(seed);
    const versionBeforeDelete = repo.currentVersion();
    const { id, version } = repo.deleteSong('x1');
    assert.equal(id, 'x1');
    assert.equal(version, versionBeforeDelete + 1);
    assert.equal(repo.getSongById('x1'), undefined);

    const { upserts, deletions } = repo.getChangesSince(versionBeforeDelete);
    assert.equal(upserts.length, 0);
    assert.equal(deletions.length, 1);
    assert.deepEqual(deletions[0], { id: 'x1', version: versionBeforeDelete + 1 });
  });

  test('repeated sync at the current version returns nothing new (idempotent)', () => {
    const repo = new InMemoryCatalogRepository(seed);
    const v = repo.currentVersion();
    const first = repo.getChangesSince(v);
    const second = repo.getChangesSince(v);
    assert.deepEqual(first, { upserts: [], deletions: [] });
    assert.deepEqual(second, { upserts: [], deletions: [] });
  });

  test('catalog version NEVER decreases, even after deleting the highest-version song', () => {
    const repo = new InMemoryCatalogRepository(seed);
    repo.addSong({ id: 'x4', title: 'D', artist: 'Artist D' }); // highest version now
    const versionBeforeDelete = repo.currentVersion();
    repo.deleteSong('x4'); // deletes the song that WAS the max-version record
    assert.ok(
      repo.currentVersion() > versionBeforeDelete,
      'version must increase, not fall back to the next-highest live record'
    );
  });

  test('a song updated then deleted before the next sync only shows up as a deletion', () => {
    const repo = new InMemoryCatalogRepository(seed);
    const checkpoint = repo.currentVersion();
    repo.updateSong('x1', { title: 'A updated' });
    repo.deleteSong('x1');
    const { upserts, deletions } = repo.getChangesSince(checkpoint);
    assert.equal(upserts.find((s) => s.id === 'x1'), undefined);
    assert.equal(deletions.some((d) => d.id === 'x1'), true);
  });

  test('local search matches title, artist, and album name, case-insensitively', () => {
    const repo = new InMemoryCatalogRepository([
      { id: 'y1', title: 'Neon Hours', artist: 'Levit', albumName: null },
      { id: 'y2', title: 'Static Bloom', artist: 'Rhea K.', albumName: 'Bloom Sessions' },
    ]);
    assert.equal(repo.search('neon').length, 1);
    assert.equal(repo.search('RHEA').length, 1);
    assert.equal(repo.search('bloom sessions').length, 1);
    assert.equal(repo.search('nonexistent').length, 0);
  });

  test('addSong rejects a duplicate id', () => {
    const repo = new InMemoryCatalogRepository(seed);
    assert.throws(() => repo.addSong({ id: 'x1', title: 'dup', artist: 'x' }), ValidationError);
  });

  test('addSong rejects missing required fields', () => {
    const repo = new InMemoryCatalogRepository([]);
    assert.throws(() => repo.addSong({ id: 'z1' }), ValidationError);
  });

  test('updateSong on a missing id throws NotFoundError', () => {
    const repo = new InMemoryCatalogRepository(seed);
    assert.throws(() => repo.updateSong('nope', { title: 'x' }), NotFoundError);
  });

  test('deleteSong on a missing id throws NotFoundError', () => {
    const repo = new InMemoryCatalogRepository(seed);
    assert.throws(() => repo.deleteSong('nope'), NotFoundError);
  });
});


describe('InMemoryCatalogRepository — mutation validation', () => {
  test('update rejects attempts to forge server-managed fields', () => {
    const repo = new InMemoryCatalogRepository(seed);
    assert.throws(() => repo.updateSong('x1', { version: 999 }), ValidationError);
    assert.throws(() => repo.updateSong('x1', { id: 'x9' }), ValidationError);
    assert.throws(() => repo.updateSong('x1', { title: '' }), ValidationError);
  });

  test('update rejects unsupported fields and invalid numeric values', () => {
    const repo = new InMemoryCatalogRepository(seed);
    assert.throws(() => repo.updateSong('x1', { randomField: true }), ValidationError);
    assert.throws(() => repo.updateSong('x1', { durationMs: -1 }), ValidationError);
    assert.throws(() => repo.updateSong('x1', { fileSizeBytes: 1.5 }), ValidationError);
  });

  test('touch-style empty update still creates a new catalog version', () => {
    const repo = new InMemoryCatalogRepository(seed);
    const before = repo.currentVersion();
    const song = repo.updateSong('x1', {});
    assert.equal(song.version, before + 1);
    assert.equal(repo.currentVersion(), before + 1);
  });
});
