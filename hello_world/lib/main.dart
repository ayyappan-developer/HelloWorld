import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/connectivity_service.dart';
import 'services/google_auth_service.dart';
import 'utils/app_router.dart';
import 'utils/app_theme.dart';
import 'widgets/no_internet_bar.dart';

/// Short name for the Supabase client. Use it anywhere: supabase.from('profiles')...
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Read the keys from the .env file
  await dotenv.load(fileName: '.env');

  // 2. Connect to Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '',
  );

  // 3. Get Google login ready
  await GoogleAuthService.instance.init();

  // 4. Start the network listener (does not wait, so the launch stays fast)
  ConnectivityService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello World',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // lib/utils/app_theme.dart
      initialRoute: AppRouter.initialRoute, // lib/utils/app_router.dart
      routes: AppRouter.routes,
      // Red "No internet" bar at the bottom of every screen
      builder: (context, child) => NoInternetBar(child: child!),
    );
  }
}
