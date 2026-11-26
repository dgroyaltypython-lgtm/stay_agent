# Serein Escapes — Agent Android App (fixed Codemagic project)

Flutter Android app for Serein Escapes agents to manage guest bookings.

## App features
- Agent login
- Dashboard overview and booking counts
- Booking list with search and status filters
- Booking detail: guest, phone, property, room, dates, guests, total and notes
- Booking status workflow: Enquiry → Confirmed/Cancelled → Checked In → Completed
- Pull-to-refresh
- JWT bearer-token integration
- Demo mode with sample bookings

## Codemagic build
1. Extract this ZIP.
2. Push the contents of the `Serein_Agent_App_Fixed` folder to the root of a new/clean GitHub repository (do not merge into the old repository without removing stale files).
3. Add the repository to Codemagic and select `codemagic.yaml`.
4. Use the `serein-agent-android` workflow and start a build.
5. Download `app-release.apk` from build artifacts.

The workflow uses Flutter stable, Java 17 and the standard Flutter engine. It runs `flutter create` only to generate standard Gradle wrapper files, then immediately runs `tool/prepare_android.sh` to restore the pinned Gradle configuration and remove duplicate `mipmap/ic_launcher.xml` files. This prevents Flutter project regeneration from reintroducing the launcher resource collision.

## Android build versions
- Android Gradle Plugin: 9.3.1
- Gradle wrapper: 9.5.0
- Kotlin Gradle Plugin: 2.4.20
- Java: 17

This project temporarily uses Flutter's documented AGP 9 compatibility flags (`android.builtInKotlin=false` and `android.newDsl=false`) with the Kotlin Gradle Plugin. Do not add another `build.gradle.kts` file; this project uses Groovy Gradle files.

## Connect to Django
The base Serein Django portal needs the companion API patch in `django_api_patch/` before live agent login works.

Set Codemagic environment variable:
- `API_BASE_URL` = public HTTPS Django base URL, without trailing slash.

Do not use `localhost` or `127.0.0.1` in a phone APK.

If `API_BASE_URL` is empty, the app opens in demo mode. Demo changes are in-memory only and are not saved to Django.

## API contract
- POST `/api/agent/token/`
- GET `/api/agent/bookings/` (optional `status` and `q`)
- PATCH `/api/agent/bookings/<id>/status/` with `{"status":"CONFIRMED"}`

## Production security note
The starter Django API patch allows AGENT and ADMIN roles to access the booking list. The current Booking model has no assigned-agent relation, so this is not isolated per agent. Add assignment-based queryset permissions before multiple independent agents use real guest data. Use HTTPS, `DEBUG=False`, strong secrets and token lifecycle controls in production.

## Local Windows build
Install Flutter stable and Android Studio/SDK. From this project folder run:

```powershell
flutter create --platforms=android --org com.serein --project-name agent .
powershell -ExecutionPolicy Bypass -File .\tool\prepare_android.ps1
flutter pub get
flutter build apk --release
```

The Codemagic workflow uses the included Bash script. The Windows PowerShell helper is included for local builds.
