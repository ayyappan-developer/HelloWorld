import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../utils/app_colors.dart';
import '../utils/pop_notification.dart';
import 'splash_screen.dart';

/// Shown when "maintenance_mode" is true in the app_setting table.
/// The user cannot go back; "Try again" checks the setting once more.
class MaintenanceScreen extends StatefulWidget {
  static const routeName = '/maintenance';
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _checking = false;

  Future<void> _tryAgain() async {
    setState(() => _checking = true);
    final settings = AppSettingsService.instance;
    final bool ok = await settings.load();
    if (!mounted) return;
    setState(() => _checking = false);

    if (!ok) {
      Pop.error(context, 'Could not connect. Check your internet.');
    } else if (settings.maintenanceMode) {
      Pop.info(context, 'We are still working on it. Please try again later.');
    } else {
      SplashScreen.openNextScreen(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String message = AppSettingsService.instance.maintenanceMessage;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.engineering_outlined, size: 110, color: AppColors.primary),
                const SizedBox(height: 20),
                const Text(
                  'Under Maintenance',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                const SizedBox(height: 10),
                Text(
                  message.isNotEmpty
                      ? message
                      : 'We are doing some scheduled work to make the app better. Please check back soon.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textGrey, height: 1.5),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _checking ? null : _tryAgain,
                  child: _checking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
