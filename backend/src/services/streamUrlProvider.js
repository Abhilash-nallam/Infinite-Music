/**
 * Stream URL provision — deliberately split into an interface and a mock
 * implementation so it's obvious this is NOT production security.
 *
 * The original mock returned `{ url: song.streamUrl, expiresInSeconds: 3600 }`
 * for a public, unauthenticated SoundHelix demo file and called that a
 * "signed URL." It wasn't signed. Nothing verified the expiry, nothing
 * scoped it to a user, and the URL worked identically whether you sent
 * "expiresInSeconds" or not. This file exists so that lie can't happen
 * again by accident.
 *
 * StreamUrlProvider interface (whatever implements it):
 *   getStreamUrl(song, { userId }): { url, mode, isDemoMedia, expiresAt? }
 *
 * `mode` is always present so the Flutter client (or a future admin
 * dashboard) can tell at a glance whether it's talking to mock or real infra.
 */

/**
 * DEV-ONLY. Returns the plain public demo URL with no signing, no auth
 * scoping, and no real expiry enforcement. `isDemoMedia: true` and
 * `mode: 'mock-public-demo'` are always set so nothing downstream can
 * mistake this for a production guarantee.
 */
class MockStreamUrlProvider {
  getStreamUrl(song) {
    return {
      url: song.streamUrl,
      mode: 'mock-public-demo',
      isDemoMedia: true,
      // No real expiresAt — there is nothing enforcing it. Omitted rather
      // than faked with a plausible-looking timestamp.
    };
  }
}

/**
 * NOT IMPLEMENTED. Documented here so the production shape is decided
 * up front and the API contract doesn't need to change when it's built —
 * only StreamUrlProvider swaps, same as CatalogRepository.
 *
 * A real implementation would, per request:
 *   1. Verify the requesting user is authenticated and authorized for
 *      this song (subscription tier, region, etc.)
 *   2. Ask the CDN/object storage for a short-lived signed URL
 *      (e.g. CloudFront signed URL, S3 presigned GET, or a signed
 *      Cloudflare Worker token) scoped to that single object.
 *   3. Return { url, mode: 'signed-cdn', isDemoMedia: false,
 *      expiresAt: <real ISO timestamp matching the signature's actual TTL> }
 *
 * class SignedCdnStreamUrlProvider {
 *   getStreamUrl(song, { userId }) { ...not implemented... }
 * }
 */

module.exports = { MockStreamUrlProvider };
