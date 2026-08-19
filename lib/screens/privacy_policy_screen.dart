import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: const [
          _PolicySection(
            title: 'Overview',
            body:
                'Infinite Music is designed to keep your local music usable on your device. This development build does not require an online account for local playback.',
          ),
          _PolicySection(
            title: 'Device music access',
            body:
                'When you choose My Device, the app requests permission to read the audio library. The permission is used to discover song title, artist, duration, file path and available embedded artwork so the app can display and play songs stored on your phone.',
          ),
          _PolicySection(
            title: 'Network and catalog',
            body:
                'The production architecture will use an HTTPS catalog API for music metadata. Cloud synchronization is not part of the current local-playback test phase.',
          ),
          _PolicySection(
            title: 'Personal information',
            body:
                'The current development build does not implement user accounts, advertising profiles, or cross-device identity synchronization.',
          ),
          _PolicySection(
            title: 'Future services',
            body:
                'When online streaming, downloads, analytics or accounts are added, this policy must be updated before production release to clearly describe what data is collected, why it is used, and how it is protected.',
          ),
          _PolicySection(
            title: 'Contact',
            body:
                'A production contact address and data-controller information should be added here before public distribution.',
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.55,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
