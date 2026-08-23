/**
 * CatalogRepository — the ONE interface the rest of the backend depends on.
 *
 * This is the seam described in the roadmap's "Recommended Backend
 * Components": today it's backed by an in-memory Map (InMemoryCatalogRepository,
 * below), but every route handler in routes/catalog.js only ever calls these
 * methods. Swapping in a PostgresCatalogRepository later (real tables,
 * transactions, a persisted change-log) means implementing this exact same
 * method shape — no route or API contract changes required.
 *
 * Required interface (whatever backs it):
 *   currentVersion(): number
 *   getChangesSince(sinceVersion: number): { upserts: SongRecord[], deletions: {id, version}[] }
 *   getSongById(id: string): SongRecord | undefined
 *   getAllSongs(): SongRecord[]
 *   addSong(data): SongRecord
 *   updateSong(id, patch): SongRecord
 *   deleteSong(id): { id, version }
 *   search(query): SongRecord[]
 */

class NotFoundError extends Error {
  constructor(message) {
    super(message);
    this.name = 'NotFoundError';
    this.statusCode = 404;
  }
}

class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
    this.statusCode = 400;
  }
}

function requiredString(value, field) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new ValidationError(`${field} must be a non-empty string`);
  }
  return value.trim();
}

function optionalString(value, field) {
  if (value === undefined || value === null) return value ?? null;
  if (typeof value !== 'string') throw new ValidationError(`${field} must be a string or null`);
  return value;
}

/**
 * In-memory implementation with a real monotonic change log.
 *
 * The core fix versus the original mock: catalog version is NOT
 * `max(song.version)`. It's a single global counter that only ever goes up,
 * incremented exactly once per mutation (add, update, OR delete) and
 * recorded in `changeLog`. This means:
 *   - Deleting the highest-version song can never make the catalog version
 *     go backwards (the old bug: version was derived from live records only).
 *   - Deletions get their own version, so delta sync can tell a client
 *     "id X was removed as of version N" instead of just silently vanishing
 *     from the songs list.
 *   - A client that has already synced past a given version will correctly
 *     see nothing new for it, even after repeated identical requests.
 */
class InMemoryCatalogRepository {
  constructor(seedSongs = []) {
    this._songs = new Map(); // id -> song record (live only)
    this._changeLog = []; // { version, type: 'add'|'update'|'delete', songId }
    this._counter = 0;

    for (const seed of seedSongs) {
      this._insertSeed(seed);
    }
  }

  _nextVersion() {
    this._counter += 1;
    return this._counter;
  }

  _insertSeed(data) {
    const id = requiredString(data.id, 'id');
    const title = requiredString(data.title, 'title');
    const artist = requiredString(data.artist, 'artist');
    if (this._songs.has(id)) {
      throw new ValidationError(`Duplicate seed song id "${id}"`);
    }
    const version = this._nextVersion();
    const now = Date.now();
    const record = {
      ...data,
      id,
      title,
      artist,
      version,
      createdAt: data.createdAt ?? now,
      updatedAt: now,
    };
    this._songs.set(record.id, record);
    this._changeLog.push({ version, type: 'add', songId: record.id });
    return record;
  }

  currentVersion() {
    // The global counter IS the catalog version — monotonic by
    // construction, since it only ever increments and is never derived
    // from the live song set.
    return this._counter;
  }

  getChangesSince(sinceVersion) {
    const relevant = this._changeLog.filter((c) => c.version > sinceVersion);

    // A song can appear multiple times in the log (e.g. added then updated
    // before the client's next sync) — collapse to its latest state, but
    // only emit it once. If its most recent relevant change is a delete,
    // it belongs in `deletions`, not `upserts`, even if it was also
    // updated earlier in the same window.
    const latestChangeBySong = new Map();
    for (const change of relevant) {
      latestChangeBySong.set(change.songId, change); // later entries overwrite
    }

    const upserts = [];
    const deletions = [];
    for (const [songId, change] of latestChangeBySong) {
      if (change.type === 'delete') {
        deletions.push({ id: songId, version: change.version });
      } else {
        const record = this._songs.get(songId);
        // Defensive: should always exist for add/update entries, but guard
        // against a corrupted log rather than crash the sync response.
        if (record) upserts.push(record);
      }
    }

    return { upserts, deletions };
  }

  getSongById(id) {
    return this._songs.get(id);
  }

  getAllSongs() {
    return Array.from(this._songs.values());
  }

  addSong(data) {
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      throw new ValidationError('request body must be a JSON object');
    }
    const id = requiredString(data.id, 'id');
    if (this._songs.has(id)) {
      throw new ValidationError(`Song with id "${id}" already exists`);
    }
    const title = requiredString(data.title, 'title');
    const artist = requiredString(data.artist, 'artist');
    return this._insertSeed({ ...data, id, title, artist });
  }

  updateSong(id, patch) {
    const existing = this._songs.get(id);
    if (!existing) throw new NotFoundError(`Song "${id}" not found`);
    if (!patch || typeof patch !== 'object' || Array.isArray(patch)) {
      throw new ValidationError('request body must be a JSON object');
    }
    if (Object.prototype.hasOwnProperty.call(patch, 'id') ||
        Object.prototype.hasOwnProperty.call(patch, 'version') ||
        Object.prototype.hasOwnProperty.call(patch, 'createdAt') ||
        Object.prototype.hasOwnProperty.call(patch, 'updatedAt')) {
      throw new ValidationError('id/version/timestamps are server-managed fields');
    }

    const allowed = new Set([
      'title', 'artist', 'artistId', 'albumId', 'albumName', 'artworkUrl',
      'streamUrl', 'downloadUrl', 'durationMs', 'fileSizeBytes', 'mimeType',
    ]);
    for (const key of Object.keys(patch)) {
      if (!allowed.has(key)) throw new ValidationError(`Unsupported song field: ${key}`);
    }

    const nextTitle = patch.title === undefined ? existing.title : requiredString(patch.title, 'title');
    const nextArtist = patch.artist === undefined ? existing.artist : requiredString(patch.artist, 'artist');
    const numericFields = ['durationMs', 'fileSizeBytes'];
    for (const field of numericFields) {
      if (patch[field] !== undefined &&
          (!Number.isInteger(patch[field]) || patch[field] < 0)) {
        throw new ValidationError(`${field} must be a non-negative integer`);
      }
    }
    for (const field of ['artistId', 'albumId', 'albumName', 'artworkUrl', 'streamUrl', 'downloadUrl', 'mimeType']) {
      if (patch[field] !== undefined) optionalString(patch[field], field);
    }

    const version = this._nextVersion();
    const updated = {
      ...existing,
      ...patch,
      id,
      title: nextTitle,
      artist: nextArtist,
      version,
      updatedAt: Date.now(),
    };
    this._songs.set(id, updated);
    this._changeLog.push({ version, type: 'update', songId: id });
    return updated;
  }

  deleteSong(id) {
    if (!this._songs.has(id)) throw new NotFoundError(`Song "${id}" not found`);
    this._songs.delete(id);
    const version = this._nextVersion();
    this._changeLog.push({ version, type: 'delete', songId: id });
    return { id, version };
  }

  search(query) {
    const q = query.toLowerCase().trim();
    if (!q) return [];
    return this.getAllSongs().filter(
      (s) =>
        s.title.toLowerCase().includes(q) ||
        s.artist.toLowerCase().includes(q) ||
        (s.albumName && s.albumName.toLowerCase().includes(q))
    );
  }
}

module.exports = { InMemoryCatalogRepository, NotFoundError, ValidationError };
