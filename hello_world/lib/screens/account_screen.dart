import 'package:flutter/material.dart';

import '../main.dart';
import '../services/app_settings_service.dart';
import '../services/google_auth_service.dart';
import '../utils/app_colors.dart';
import '../utils/pop_notification.dart';
import '../widgets/network_aware.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';

/// My Account: profile card, menu rows and logout.
class AccountScreen extends StatefulWidget {
  static const routeName = '/account';
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with NetworkAware {
  bool _loading = true;
  String _name = '';
  String _email = '';
  String _phone = '';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // Internet is back: reload the profile
  @override
  void onNetworkRestored() => _loadProfile();

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final profile = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (!mounted) return;
      setState(() {
        _name = (profile?['name'] ?? '').toString();
        _phone = (profile?['phone'] ?? '').toString();
        _avatarUrl = (profile?['avatar_url'] ?? '').toString();
        _email = user.email ?? '';
      });
    } catch (e) {
      debugPrint('Account load error: $e');
      if (mounted) Pop.error(context, 'Could not load your profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditProfile() async {
    // Wait until the edit screen closes. It returns true when something was saved.
    final saved = await Navigator.pushNamed(context, EditProfileScreen.routeName);
    if (saved == true) _loadProfile();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout?', textAlign: TextAlign.center),
        content: const Text(
          'Are you sure you want to logout from your profile?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _logout();
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await GoogleAuthService.instance.signOut();
    if (!mounted) return;
    Pop.success(context, 'You have been logged out');
    // Remove every screen and go back to login
    Navigator.pushNamedAndRemoveUntil(context, AuthScreen.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _profileCard(),

                  _sectionTitle('Account'),
                  _group([
                    _row(icon: Icons.person_outline, label: 'Edit Profile', onTap: _openEditProfile),
                    _row(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: _phone.isEmpty ? 'Add' : _phone,
                      onTap: _openEditProfile,
                    ),
                  ]),

                  _sectionTitle('Support'),
                  _group([
                    _row(
                      icon: Icons.info_outline,
                      label: 'About',
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'Hello World',
                        applicationVersion: AppSettingsService.instance.currentVersionName,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _group([
                    _row(
                      icon: Icons.power_settings_new,
                      label: 'Log out',
                      color: AppColors.error,
                      onTap: _confirmLogout,
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _profileCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.card,
              backgroundImage: _avatarUrl.isNotEmpty
                  ? NetworkImage(_avatarUrl)
                  : const AssetImage('assets/images/blank.png') as ImageProvider,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Hello $_name',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 3),
          Text(_email, style: const TextStyle(color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      );

  /// A rounded grey box holding a few rows, with lines between them.
  Widget _group(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    String value = '',
    Color color = AppColors.textDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty) Text(value, style: const TextStyle(color: AppColors.textGrey)),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ],
      ),
    );
  }
}
