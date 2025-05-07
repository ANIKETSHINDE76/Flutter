# LazyBot Deployment Guide

This guide provides step-by-step instructions for deploying the LazyBot Flutter application across different platforms.

## Prerequisites

Before deploying the app, ensure you have the following installed:

- Flutter SDK (latest stable version)
- Android Studio / VS Code
- Xcode (for iOS deployment)
- Git
- Superbase CLI
- Firebase CLI (if using Firebase services)

## Environment Setup

1. Clone the repository:
   ```bash
   git clone [repository-url]
   cd lazybot
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure environment variables:
   - Create a `.env` file in the project root
   - Add necessary API keys and configurations:
     ```
     SUPERBASE_URL=your_superbase_url
     SUPERBASE_ANON_KEY=your_anon_key
     ```

## Android Deployment

### Generate Release Build

1. Create keystore:
   ```bash
   keytool -genkey -v -keystore android/app/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Configure signing:
   - Create `key.properties` in `android/` folder:
     ```
     storePassword=<password>
     keyPassword=<password>
     keyAlias=upload
     storeFile=keystore.jks
     ```

3. Build release APK:
   ```bash
   flutter build apk --release
   ```

4. Build App Bundle:
   ```bash
   flutter build appbundle
   ```

### Google Play Store Deployment

1. Create a Google Play Developer account
2. Create a new application in Google Play Console
3. Upload the App Bundle
4. Fill in store listing details
5. Submit for review

## iOS Deployment

### Prerequisites

- Apple Developer Account
- Xcode installed
- iOS Certificates and Provisioning Profiles

### Build Steps

1. Open iOS project:
   ```bash
   cd ios
   pod install
   cd ..
   ```

2. Configure signing in Xcode:
   - Open `Runner.xcworkspace`
   - Set Bundle Identifier
   - Configure Team and Signing

3. Build release IPA:
   ```bash
   flutter build ios --release
   ```

### App Store Deployment

1. In Xcode:
   - Select Product > Archive
   - Open Organizer
   - Upload to App Store

2. In App Store Connect:
   - Configure app details
   - Submit for review

## Web Deployment

1. Build web release:
   ```bash
   flutter build web --release
   ```

2. Deploy to hosting service (e.g., Firebase Hosting):
   ```bash
   firebase deploy --only hosting
   ```

## Continuous Integration/Deployment (CI/CD)

### GitHub Actions Setup

Create `.github/workflows/main.yml`:

```yaml
name: CI/CD
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test
      - run: flutter build apk
```

## Post-Deployment

### Monitoring

- Set up crash reporting
- Configure analytics
- Monitor app performance

### Updates

1. Version bump in `pubspec.yaml`
2. Update changelog
3. Follow platform-specific update procedures

## Troubleshooting

Common issues and solutions:

1. Build Failures
   - Clean build files: `flutter clean`
   - Update dependencies: `flutter pub upgrade`

2. Signing Issues
   - Verify certificates
   - Check provisioning profiles
   - Ensure correct bundle ID

3. Performance Issues
   - Run Flutter DevTools
   - Profile app performance
   - Check memory leaks

## Support

For deployment issues:
- Create GitHub issue
- Contact development team
- Check documentation

---

*Note: Keep this document updated with any changes to the deployment process.* 