import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'library_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF24163D), AppColors.bgElevated],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.violet.withValues(alpha: .25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.violet, AppColors.amber],
                    ),
                  ),
                  child: const AppLogo(size: 58),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Abhilash',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Free plan',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _showPremiumInfo(context),
                  child: const Text('Explore'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _QuickStats(
            onDevice: () => _goToLibrary(context, 1),
            onLiked: () => _goToLibrary(context, 3),
            onPlaylists: () => _goToLibrary(context, 2),
          ),
          const SizedBox(height: 18),
          const _ProfileSectionTitle('Your music'),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.library_music_outlined,
                title: 'My Device',
                subtitle: 'Play music stored on this phone',
                onTap: () => _goToLibrary(context, 1),
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.favorite_border_rounded,
                title: 'Liked songs',
                subtitle: 'Your saved favorites',
                onTap: () => _goToLibrary(context, 3),
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.queue_music_rounded,
                title: 'Playlists',
                subtitle: 'Create and organize playlists',
                onTap: () => _goToLibrary(context, 2),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _ProfileSectionTitle('App'),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Playback, data, notifications and more',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.info_outline_rounded,
                title: 'About Infinite Music',
                subtitle: 'Version 0.2.2',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Infinite Music',
                  applicationVersion: '0.2.2',
                  children: const [
                    Text(
                      'A local-first music experience with persistent library, playlists, device playback and background audio controls.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _ProfileSectionTitle('Privacy'),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy & permissions',
                subtitle: 'Control how the app accesses device music',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _goToLibrary(BuildContext context, int tab) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LibraryScreen(initialTab: tab)),
    );
  }

  void _showPremiumInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 10, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: AppColors.amber, size: 34),
            SizedBox(height: 12),
            Text(
              'Infinite Music plans',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Premium features can be connected after the online service and account system are implemented.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final VoidCallback onDevice;
  final VoidCallback onLiked;
  final VoidCallback onPlaylists;

  const _QuickStats({
    required this.onDevice,
    required this.onLiked,
    required this.onPlaylists,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.music_note_rounded,
            label: 'Device',
            onTap: onDevice,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.favorite_rounded,
            label: 'Liked',
            onTap: onLiked,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.queue_music_rounded,
            label: 'Playlists',
            onTap: onPlaylists,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.violetSoft, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  final String title;

  const _ProfileSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;

  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.violet.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.violetSoft, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.muted,
      ),
        onTap: onTap,
      ),
    );
  }
}
