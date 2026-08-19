import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

/// Production startup sequence:
/// 1. Android/iOS native startup shows the branded dark background.
/// 2. As soon as Flutter draws its first frame, the native splash is
///    removed and replaced by this screen showing the exact, un-cropped
///    app icon (assets/icon/app_icon.png) centered on the same dark
///    background — no gap, no flash, no second logo.
/// 3. The icon stays on screen for exactly 1.5 seconds, then the real app
///    fades in.
class BrandedSplashScreen extends StatefulWidget {
  final Widget child;

  const BrandedSplashScreen({super.key, required this.child});

  @override
  State<BrandedSplashScreen> createState() => _BrandedSplashScreenState();
}

class _BrandedSplashScreenState extends State<BrandedSplashScreen> {
  static const _splashDuration = Duration(milliseconds: 1500);
  bool _showApp = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Remove the native splash right after the first Flutter frame draws,
    // so the handoff from native background to this screen is seamless
    // (both are the same background color, so there's no visible cut).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    await Future<void>.delayed(_splashDuration);
    if (!mounted) return;
    setState(() => _showApp = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _showApp
          ? KeyedSubtree(
              key: const ValueKey('infinite-music-app'),
              child: widget.child,
            )
          : KeyedSubtree(
              key: const ValueKey('infinite-music-splash'),
              child: _buildSplash(),
            ),
    );
  }

  Widget _buildSplash() {
    return const ColoredBox(
      color: Color(0xFF0B0B14),
      child: Center(
        // BoxFit.contain + fixed box: the exact supplied icon, shown in
        // full, never cropped, stretched, or zoomed.
        child: Image(
          image: AssetImage('assets/icon/app_icon.png'),
          width: 220,
          height: 220,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
