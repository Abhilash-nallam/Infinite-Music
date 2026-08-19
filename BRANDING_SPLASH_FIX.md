# Branding / Splash Fix

- Replaced the in-app logo asset with the supplied red Infinite Music logo.
- Replaced launcher bitmap densities with the supplied logo.
- Replaced native splash source and generated Android splash resources.
- Kept the supplied 1.5s 720x1280 intro MP4.
- Native splash now remains visible until the MP4 is initialized, preventing the previous blank/instant handoff.
- Intro video is rendered full-screen with BoxFit.cover.
- App startup falls back to the logo/app if video initialization fails.
