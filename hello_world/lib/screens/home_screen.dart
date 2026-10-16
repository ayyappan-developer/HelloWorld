import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'account_screen.dart';

/// Home screen. Empty for now — add your content in the body.
class HomeScreen extends StatelessWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 28, color: AppColors.primary),
            onPressed: () => Navigator.pushNamed(context, AccountScreen.routeName),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const SizedBox.shrink(), // TODO: home screen content
    );
  }
}
