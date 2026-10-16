import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../main.dart';
import '../services/app_settings_service.dart';
import '../utils/app_colors.dart';
import '../widgets/network_aware.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'maintenance_screen.dart';
import 'update_screen.dart';

/// First screen.
///   1. Shows the splash image from the cloud (saved on the phone last time),
///      or the logo the very first time.
///   2. Loads the app settings from Supabase (table "app_setting").
///   3. Opens the next screen, in this order:
///        maintenance on      -> Maintenance
///        newer app in store  -> Update
///        not logged in       -> Auth
///        no profile yet      -> Auth (it opens the registration step)
///        otherwise           -> Home
class SplashScreen extends StatefulWidget {
  static const routeName = '/';
  const SplashScreen({super.key});

  /// Picks the next screen from the loaded settings and the logged-in user.
  /// Also used by the Maintenance and Update screens.
  static Future<void> openNextScreen(BuildContext context) async {
    final settings = AppSettingsService.instance;
    String route;

    if (settings.maintenanceMode) {
      route = MaintenanceScreen.routeName;
    } else if (settings.hasUpdate && !settings.updateSkipped) {
      route = UpdateScreen.routeName;
    } else if (supabase.auth.currentUser == null) {
      route = AuthScreen.routeName;
    } else {
      // Logged in: did the user finish their profile?
      final profile = await supabase
          .from('profiles')
          .select('name')
          .eq('id', supabase.auth.currentUser!.id)
          .maybeSingle();
      final String name = (profile?['name'] ?? '').toString().trim();
      // No name: the auth screen opens the registration step by itself
      route = name.isNotEmpty ? HomeScreen.routeName : AuthScreen.routeName;
    }

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with NetworkAware {
  final settings = AppSettingsService.instance;
  bool _failed = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  // No internet on launch: start again by itself when it comes back
  @override
  void onNetworkRestored() {
    if (_failed) _start();
  }

  Future<void> _start() async {
    setState(() {
      _failed = false;
      _message = '';
    });

    // Friendly reminder when the .env file still has the sample values
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    if (url.isEmpty || url.contains('your-project-ref')) {
      _showError('Add your Supabase keys in the .env file, then restart the app.');
      return;
    }

    // Show the splash image saved last time
    await settings.loadCachedSplash();
    if (!mounted) return;
    setState(() {});

    // Load the settings while the splash is on screen (at least splash_time seconds)
    final results = await Future.wait([
      settings.load(),
      Future.delayed(Duration(seconds: settings.splashTime)),
    ]);
    if (!mounted) return;

    if (results.first != true) {
      _showError('Could not connect. Check your internet and try again.');
      return;
    }

    try {
      await SplashScreen.openNextScreen(context);
    } catch (e) {
      debugPrint('Splash error: $e');
      _showError('Could not connect. Check your internet and try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = settings.splashImage.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Splash image from the cloud, or the logo
          Positioned.fill(
            child: hasImage
                ? Image.network(
                    settings.splashImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _logo(),
                  )
                : _logo(),
          ),

          // Loader, or the error with a Retry button
          Positioned(
            left: 24,
            right: 24,
            bottom: 30,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_failed)
                    const CircularProgressIndicator(color: AppColors.primary)
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _start, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() => Center(child: Image.asset('assets/images/logo.png', width: 200));
}
