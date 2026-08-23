// Demo catalog. Streaming URLs are public SoundHelix files, used ONLY so
// playback works end-to-end during development. Not licensed content, not
// production media — see src/services/streamUrlProvider.js for why these
// are explicitly marked as demo media rather than pretending they're real.
const SEED_SONGS = [
  { id: 's1', title: 'Midnight Drift', artist: 'Arka Sen', artistId: 'a1', albumId: null, albumName: null, artworkUrl: '', streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', durationMs: 233000, fileSizeBytes: 9400000, mimeType: 'audio/mpeg' },
  { id: 's2', title: 'Neon Hours', artist: 'Levit', artistId: 'a2', albumId: null, albumName: null, artworkUrl: '', streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3', downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3', durationMs: 227000, fileSizeBytes: 9100000, mimeType: 'audio/mpeg' },
  { id: 's3', title: 'Static Bloom', artist: 'Rhea K.', artistId: 'a3', albumId: null, albumName: null, artworkUrl: '', streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3', downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3', durationMs: 199000, fileSizeBytes: 8000000, mimeType: 'audio/mpeg' },
  { id: 's4', title: 'Amber Skies', artist: 'Nova Loop', artistId: 'a4', albumId: 'alb1', albumName: 'Loop Diaries', artworkUrl: '', streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3', downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3', durationMs: 258000, fileSizeBytes: 10400000, mimeType: 'audio/mpeg' },
  { id: 's5', title: 'Echo Chamber', artist: 'Wiit', artistId: 'a5', albumId: null, albumName: null, artworkUrl: '', streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3', downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3', durationMs: 216000, fileSizeBytes: 8700000, mimeType: 'audio/mpeg' },
  { id: 's6', title: 'Glass Petals', artist: 'Anya M.', artistId: 'a6', albumId: 'alb2', albumName: 'Petal Sessions', artworkUrl: '', streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3', downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3', durationMs: 241000, fileSizeBytes: 9700000, mimeType: 'audio/mpeg' },
  { id: 's7', title: 'Paper Moon Radio', artist: 'Kade Ellis', artistId: 'a7', albumId: null, albumName: null, artworkUrl: '', streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3', downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3', durationMs: 249000, fileSizeBytes: 10000000, mimeType: 'audio/mpeg' },
  { id: 's8', title: 'Velvet Static', artist: 'Ines Cho', artistId: 'a8', albumId: null, albumName: null, artworkUrl: '', streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3', downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3', durationMs: 264000, fileSizeBytes: 10600000, mimeType: 'audio/mpeg' },
];

module.exports = { SEED_SONGS };
