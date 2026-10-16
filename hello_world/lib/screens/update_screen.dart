import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_settings_service.dart';
import '../utils/app_colors.dart';
import '../utils/pop_notification.dart';
import 'splash_screen.dart';

/// Shown when the store has a newer build than this app
/// ("app_version" in the app_setting table is bigger than the "+N" in pubspec).
/// With "force_update" true there is no "Later" button.
class UpdateScreen extends StatelessWidget {
  static const routeName = '/update';
  const UpdateScreen({super.key});

  Future<void> _openStore(BuildContext context) async {
    final String url = AppSettingsService.instance.storeUrl;
    final bool opened = url.isNotEmpty &&
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) Pop.error(context, 'Could not open the store.');
  }

  void _later(BuildContext context) {
    AppSettingsService.instance.updateSkipped = true;
    SplashScreen.openNextScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.system_update_outlined, size: 110, color: AppColors.primary),
                const SizedBox(height: 20),
                const Text(
                  "It's time to update",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                const SizedBox(height: 10),
                const Text(
                  "A new version is ready, with improvements and new features we've added for you.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGrey, height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your version: ${settings.currentVersionName} (${settings.currentVersion})',
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _openStore(context),
                  child: const Text('Update Now'),
                ),
                if (!settings.forceUpdate) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => _later(context), child: const Text('Later')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
