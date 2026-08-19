import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/app_preferences.dart';
import '../theme/app_theme.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferences>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _SectionTitle('Playback'),
          _SettingsCard(children: [
            SwitchListTile.adaptive(
              value: settings.autoplay,
              onChanged: settings.setAutoplay,
              title: const Text('Autoplay'),
              subtitle: const Text('Continue with the next song'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.high_quality_rounded),
              title: const Text('Audio quality'),
              subtitle: Text('${settings.audioQuality} · Applies to online playback when available'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showQuality(context, settings),
            ),
          ]),
          _SectionTitle('Downloads & data'),
          _SettingsCard(children: [
            ListTile(
              leading: const Icon(Icons.wifi_rounded),
              title: const Text('Wi-Fi only downloads'),
              subtitle: const Text('Applies when cloud downloads are enabled'),
              trailing: const Icon(Icons.info_outline_rounded),
              onTap: () => _showInfo(
                context,
                'Wi-Fi only downloads',
                'Cloud download management is not enabled in this local-first release, so this setting is intentionally not used for device music.',
              ),
            ),
            const Divider(height: 1),
            SwitchListTile.adaptive(
              value: settings.dataSaver,
              onChanged: settings.setDataSaver,
              title: const Text('Data saver'),
              subtitle: const Text('Reduce network usage for online music'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.storage_rounded),
              title: const Text('Storage'),
              subtitle: const Text('Manage downloaded music'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showInfo(
                context,
                'Storage',
                'Infinite Music does not copy or delete your phone music. Device songs are read directly from Android MediaStore. Cloud download management will be enabled separately when cloud downloads are released.',
              ),
            ),
          ]),
          _SectionTitle('Notifications'),
          _SettingsCard(children: [
            SwitchListTile.adaptive(
              value: settings.notifications,
              onChanged: (value) => _setNotifications(context, settings, value),
              title: const Text('Playback notifications'),
              subtitle: const Text('Keep the preference ready for Android media controls'),
            ),
          ]),
          _SectionTitle('Privacy & account'),
          _SettingsCard(children: [
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy policy'),
              subtitle: const Text('How Infinite Music handles your data'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Permissions'),
              subtitle: const Text('Music access is used for local playback'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showPermissions(context),
            ),
          ]),
          _SectionTitle('About'),
          _SettingsCard(children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About Infinite Music'),
              subtitle: const Text('Version 0.2.2 · Local playback'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Infinite Music',
                applicationVersion: '0.2.2',
                children: const [Text('A local-first music player with persistent likes, playlists, queue controls and Android background playback.')],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms of use'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showInfo(context, 'Terms of use', 'Infinite Music is currently a development build. Online music will only be distributed through the production service when the project has the necessary rights and permissions.'),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _setNotifications(
    BuildContext context,
    AppPreferences settings,
    bool value,
  ) async {
    if (value) {
      final status = await Permission.notification.request();
      if (!status.isGranted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allow notifications in Android Settings to use playback controls.')),
        );
        return;
      }
    }
    await settings.setNotifications(value);
  }

  Future<void> _showPermissions(BuildContext context) async {
    final audio = await Permission.audio.status;
    final notification = await Permission.notification.status;
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permissions'),
        content: Text(
          'Music access: ${audio.isGranted ? 'Allowed' : 'Not allowed'}\n'
          'Notifications: ${notification.isGranted ? 'Allowed' : 'Not allowed'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open system settings'),
          ),
        ],
      ),
    );
  }

  void _showQuality(BuildContext context, AppPreferences settings) {
    const options = ['Standard', 'High', 'Very high'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.bgElevated,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text('Audio quality', style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w700)))),
            for (final option in options)
              ListTile(
                title: Text(option),
                trailing: settings.audioQuality == option ? const Icon(Icons.check_rounded, color: AppColors.violetSoft) : null,
                onTap: () async {
                  await settings.setAudioQuality(option);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 10), child: Text(title.toUpperCase(), style: const TextStyle(color: AppColors.violetSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)));
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.divider)), child: Column(children: children));
}
