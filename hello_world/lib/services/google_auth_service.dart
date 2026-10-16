import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Google login, connected to Supabase.
///
/// How it works on a phone:
///   1. Google shows the account picker and gives us an "ID token".
///   2. We hand that token to Supabase, and Supabase logs the user in.
///
/// On the web, Supabase opens Google's login page and comes back to the app.
///
/// The client IDs come from the .env file:
///   GOOGLE_WEB_CLIENT_ID  (Android + Web)
///   GOOGLE_IOS_CLIENT_ID  (iPhone only)
class GoogleAuthService {
  // One shared object for the whole app: GoogleAuthService.instance
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  SupabaseClient get _supabase => Supabase.instance.client;
  bool _initialized = false;

  String get _webClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
  String get _iosClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Call once in main(), before runApp().
  Future<void> init() async {
    if (_initialized || kIsWeb) return; // the web uses Supabase's own redirect
    await _googleSignIn.initialize(
      clientId: _isIOS ? _iosClientId : null,
      serverClientId: _webClientId,
    );
    _initialized = true;
  }

  /// Opens Google login.
  /// Returns true when the user is logged in to Supabase,
  /// false when the user closed the Google window.
  Future<bool> signIn() async {
    // Web: the page leaves for Google and returns to the app's start page.
    if (kIsWeb) {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
      return false;
    }

    await init();

    try {
      // 1. Google account picker
      final GoogleSignInAccount account = await _googleSignIn.authenticate();

      // 2. The ID token proves who the user is
      final String? idToken = account.authentication.idToken;
      if (idToken == null) {
        throw 'Google did not return an ID token. Check GOOGLE_WEB_CLIENT_ID in .env';
      }

      // 3. Access token (iOS needs it; Android gets it without asking again)
      const scopes = ['email', 'profile'];
      final authorization =
          await account.authorizationClient.authorizationForScopes(scopes) ??
              await account.authorizationClient.authorizeScopes(scopes);

      // 4. Log in to Supabase with the Google tokens
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
      return true;
    } on GoogleSignInException catch (e) {
      // The user closed the account picker: not an error.
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
  }

  /// Logs out of Google and Supabase.
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google sign-out: $e');
      }
    }
    await _supabase.auth.signOut();
  }
}
