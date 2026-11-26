# Serein Escapes — Agent Android App

Flutter Android project for agents to manage Serein Escapes guest bookings.

## Features
- Agent login
- Dashboard overview and booking counts
- Booking list, search and status filters
- Booking detail: guest, phone, property, room, dates, guests, total and notes
- Booking status workflow: Enquiry → Confirmed/Cancelled → Checked In → Completed
- Pull-to-refresh
- JWT bearer-token integration
- Demo mode with sample bookings
- Codemagic workflow for release APK using Flutter stable and the default Flutter engine

## Build with Codemagic
1. Extract this ZIP and push the `Serein_Agent_App` folder to GitHub.
2. Add the repository to Codemagic.
3. Select the workflow from `codemagic.yaml`. The workflow refreshes the standard Android platform scaffolding and Gradle wrapper using Flutter stable before building.
4. Start the build and download `app-release.apk` from Artifacts.

No custom engine is used. Codemagic uses the standard Flutter stable SDK and Flutter's default engine. If building locally, run `flutter create --platforms=android --org com.serein --project-name agent .` once before `flutter pub get`.

## Demo mode
If `API_BASE_URL` is empty, the app uses sample data. Enter any non-empty username and password. Demo changes exist only in memory and do not update Django.

## Connect to Django
The current Serein Django portal has booking models and SimpleJWT packages, but the agent API routes have not yet been added. The `django_api_patch/` folder contains the companion API code and setup instructions.

Set the Codemagic environment variable:
- `API_BASE_URL` = public HTTPS base URL, no trailing slash (e.g. `https://your-domain.example`)

Do not use `localhost` or `127.0.0.1` in an APK running on a phone.

## API contract
- POST `/api/agent/token/`
- GET `/api/agent/bookings/` (optional `status` and `q`)
- PATCH `/api/agent/bookings/<id>/status/` with `{"status":"CONFIRMED"}`

## Production caveats
The starter API patch grants `AGENT` and `ADMIN` roles access to the booking list. The existing Booking model has no assigned-agent field, so this is not yet isolated per agent. Add assignment-based permissions before multiple independent agents use real guest data. Use HTTPS, `DEBUG=False`, strong secrets, token refresh and operational monitoring in production.


## Gradle compatibility update
This package uses Gradle 9.5.0 and Android Gradle Plugin 9.3.1, matching the current Flutter 3.50 Android toolchain defaults. It uses AGP built-in Kotlin rather than applying the legacy Kotlin Gradle plugin separately.
