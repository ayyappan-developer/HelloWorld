import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/google_auth_service.dart';
import '../utils/app_colors.dart';
import '../utils/pop_notification.dart';
import 'home_screen.dart';

/// Login screen, same flow as KSR Connect but with Google only.
/// 5 steps (pages):
///   0. Intro     - logo + "Get Started"
///   1. Sign in   - "Sign in with Google"
///   2. Terms     - accept Terms + Privacy        (first time only)
///   3. Register  - name + phone number           (first time only)
///   4. Success   - "Welcome (name)!" + "Explore Now"
/// An old user goes straight from step 1 to Home.
class AuthScreen extends StatefulWidget {
  static const routeName = '/auth';
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Page numbers, so the code reads better
  static const int pageIntro = 0;
  static const int pageSignIn = 1;
  static const int pageTerms = 2;
  static const int pageRegister = 3;
  static const int pageSuccess = 4;

  final PageController _pageController = PageController();
  int _currentPage = pageIntro;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _loading = false; // register button
  bool _googleLoading = false; // Google button
  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  String _avatarUrl = ''; // Google profile photo, shown on the success page

  @override
  void initState() {
    super.initState();
    // Already logged in (back from Google on the web, or the app was closed
    // before the profile was saved): continue from the sign-in step.
    if (supabase.auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _afterLogin());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // Navigation between the pages
  // ---------------------------------------------------------------

  void _goToPage(int page) {
    FocusManager.instance.primaryFocus?.unfocus();
    _pageController.jumpToPage(page);
    setState(() => _currentPage = page);
  }

  Future<void> _onBack() async {
    if (_currentPage == pageSignIn) {
      _goToPage(pageIntro);
    } else if (_currentPage == pageTerms || _currentPage == pageRegister) {
      // Leaving signup: log out so the user can pick another Google account
      await GoogleAuthService.instance.signOut();
      setState(() {
        _acceptTerms = false;
        _acceptPrivacy = false;
      });
      _goToPage(pageSignIn);
    }
    // Success page: no going back, use "Explore Now"
  }

  void _openHome() {
    Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (route) => false);
  }

  // ---------------------------------------------------------------
  // Login logic
  // ---------------------------------------------------------------

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      final bool ok = await GoogleAuthService.instance.signIn();
      if (kIsWeb) return; // the browser is leaving for Google
      if (!ok) {
        if (mounted) Pop.info(context, 'Google sign-in was cancelled');
        return;
      }
      await _afterLogin();
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      if (mounted) Pop.error(context, 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  /// Runs after Google login.
  /// Old user -> Home.  First time -> Terms, then Register.
  Future<void> _afterLogin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (!mounted) return;

      final String name = (profile?['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        Pop.success(context, 'Welcome back, $name!');
        _openHome();
        return;
      }

      // First time: fill the form with what Google gave us
      final meta = user.userMetadata ?? {};
      _nameController.text = (meta['full_name'] ?? meta['name'] ?? '').toString();
      _avatarUrl = (meta['avatar_url'] ?? meta['picture'] ?? '').toString();
      _goToPage(pageTerms);
    } catch (e) {
      debugPrint('Load profile error: $e');
      if (mounted) Pop.error(context, 'Could not load your profile. Please try again.');
    }
  }

  bool get _canRegister =>
      _nameController.text.trim().length >= 2 && _phoneController.text.trim().length == 10;

  Future<void> _register() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': user.email,
        'avatar_url': _avatarUrl.isEmpty ? null : _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      _goToPage(pageSuccess);
    } catch (e) {
      debugPrint('Register error: $e');
      if (mounted) Pop.error(context, 'Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool showBack = _currentPage == pageSignIn || _currentPage == pageTerms || _currentPage == pageRegister;

    return PopScope(
      canPop: _currentPage == pageIntro, // Android back button
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: showBack
            ? AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack))
            : null,
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // only buttons change the page
            children: [
              _introPage(),
              _signInPage(),
              _termsPage(),
              _registerPage(),
              _successPage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo() => Image.asset('assets/images/logo.png', width: 200);

  Widget _introPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(child: Center(child: _logo())),
          const Text('Welcome to', style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
          const SizedBox(height: 6),
          const Text(
            'Hello World',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _goToPage(pageSignIn),
            child: const Text('Get Started'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _signInPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(child: Center(child: _logo())),
          const Text(
            'Sign in to continue',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          const Text('Use your Google account', style: TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _googleLoading ? null : _googleSignIn,
            child: _googleLoading
                ? _buttonLoader()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/google_ico.png', width: 22, height: 22),
                      const SizedBox(width: 10),
                      const Text('Sign in with Google'),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _termsPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          const Text(
            'Legal & Privacy',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text('Please review and accept to continue.', style: TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
              child: const SingleChildScrollView(
                padding: EdgeInsets.all(16),
                // TODO: replace with your real Terms and Privacy Policy
                child: Text(
                  'Terms and Conditions\n\n'
                  'By using Hello World you agree to use the app lawfully and to keep your '
                  'account details correct and up to date.\n\n'
                  'Privacy Policy\n\n'
                  'We store your name, phone number, email and profile photo to run your account. '
                  'We do not sell your data. You can ask us to delete your account at any time.',
                  style: TextStyle(color: AppColors.textDark, height: 1.6, fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _agreeRow('I agree to the Terms and Conditions', _acceptTerms,
              (value) => setState(() => _acceptTerms = value)),
          _agreeRow('I agree to the Privacy Policy', _acceptPrivacy,
              (value) => setState(() => _acceptPrivacy = value)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: (_acceptTerms && _acceptPrivacy) ? () => _goToPage(pageRegister) : null,
            child: const Text('Agree all and continue'),
          ),
        ],
      ),
    );
  }

  Widget _agreeRow(String text, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              color: value ? AppColors.primary : AppColors.textGrey,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: AppColors.textDark))),
          ],
        ),
      ),
    );
  }

  Widget _registerPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create your profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text('Just two details to finish signup.', style: TextStyle(color: AppColors.textGrey)),
                  const SizedBox(height: 24),
                  _label('Name'),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(hintText: 'Your name here', suffixIcon: _tick(_nameController.text.trim().length >= 2)),
                    onChanged: (_) => setState(() {}), // re-check the button
                  ),
                  const SizedBox(height: 16),
                  _label('Phone Number'),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Your phone number here',
                      prefixText: '+91 ',
                      suffixIcon: _tick(_phoneController.text.trim().length == 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: (_canRegister && !_loading) ? _register : null,
            child: _loading ? _buttonLoader() : const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _successPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: AppColors.card,
                  backgroundImage: _avatarUrl.isNotEmpty
                      ? NetworkImage(_avatarUrl)
                      : const AssetImage('assets/images/blank.png') as ImageProvider,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome ${_nameController.text.trim()}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                const Text('Your account is ready. Enjoy the app.', style: TextStyle(color: AppColors.textGrey)),
              ],
            ),
          ),
          ElevatedButton(onPressed: _openHome, child: const Text('Explore Now')),
        ],
      ),
    );
  }

  Widget _tick(bool ok) => Icon(
        ok ? Icons.check_circle : Icons.circle_outlined,
        color: ok ? AppColors.success : AppColors.textGrey,
        size: 20,
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
      );

  Widget _buttonLoader() => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
}
