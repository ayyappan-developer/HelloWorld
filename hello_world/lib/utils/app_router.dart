import 'package:flutter/material.dart';

import '../screens/account_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/maintenance_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/update_screen.dart';

/// All the screens of the app.
/// Open one with: Navigator.pushNamed(context, HomeScreen.routeName)
/// To add a screen: give it a routeName and add one line below.
class AppRouter {
  static const String initialRoute = SplashScreen.routeName;

  static Map<String, WidgetBuilder> routes = {
    SplashScreen.routeName: (context) => const SplashScreen(),
    AuthScreen.routeName: (context) => const AuthScreen(),
    HomeScreen.routeName: (context) => const HomeScreen(),
    AccountScreen.routeName: (context) => const AccountScreen(),
    EditProfileScreen.routeName: (context) => const EditProfileScreen(),
    MaintenanceScreen.routeName: (context) => const MaintenanceScreen(),
    UpdateScreen.routeName: (context) => const UpdateScreen(),
  };
}
