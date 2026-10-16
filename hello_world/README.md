# hello_world

Simple Flutter app with Supabase + Google login.
Screens: Splash -> Auth -> Home -> Account -> Edit Profile (one file each in `lib/screens/`).

## Setup (one time)

1. **Supabase**
   - Open your project -> SQL Editor -> paste `supabase/setup.sql` -> Run.
   - Authentication -> Sign In / Providers -> enable **Email** and **Google**.
   - For Google, add the Web Client ID and Client Secret there.
     Also add your Android/iOS client IDs to "Authorized Client IDs" (comma separated).
   - Email OTP: Authentication -> Emails -> the "Magic Link" and "Confirm signup" templates must contain `{{ .Token }}`
     so the email shows a code.
   - Web only: Authentication -> URL Configuration -> add `http://localhost:<port>` to Redirect URLs.

2. **Google Cloud Console** -> APIs & Services -> Credentials
   - Create a **Web application** OAuth client -> `GOOGLE_WEB_CLIENT_ID` + `GOOGLE_CLIENT_SECRET`.
   - Create an **Android** OAuth client: package `com.myapps.hello_world` + your SHA-1
     (`cd android && ./gradlew signingReport`).
   - iPhone only: create an **iOS** client -> `GOOGLE_IOS_CLIENT_ID`, and add its
     "reversed client ID" as a URL scheme in `ios/Runner/Info.plist`.

3. **.env** - fill in the values (copy from `.env.example` if missing).

4. Run:
   ```
   flutter pub get
   flutter run
   ```

## Files

```
lib/
  main.dart                         loads .env, starts Supabase, runs the app
  utils/app_theme.dart              fonts, colors, button + text field style
  utils/app_router.dart             list of screens (named routes)
  screens/splash_screen.dart        logo, decides Home or Auth
  screens/auth_screen.dart          intro, Google / email OTP login, create profile
  screens/home_screen.dart          empty home
  screens/account_screen.dart       profile card, menu, logout
  screens/edit_profile_screen.dart  photo, name, phone
  services/google_auth_service.dart Google login -> Supabase
  utils/pop_notification.dart       Pop.success / Pop.error / Pop.info / Pop.toast
  utils/app_colors.dart             colors
supabase/setup.sql                  table + storage bucket
```
