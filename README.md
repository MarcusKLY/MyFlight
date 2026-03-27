# MyFlight

MyFlight is an iOS flight-tracking app built with SwiftUI, SwiftData, and MapKit. You can search flights by number and date, save them locally, follow them on a live map, and inspect rich operational details including timeline events, route progress, gate data, and aircraft metadata.

## Highlights

- Tab-based app flow with `Live Map` and `Logbook`.
- Full-screen map experience with floating controls and flight tracking.
- Sheet-driven UX for:
  - flight list
  - add flight
  - flight detail
- Flight search with API-backed lookup and manual-entry fallback.
- SwiftData persistence for `Flight` and `Airport` models.
- Event timeline with scheduled, estimated, revised, actual, and runway timestamps.
- Aircraft enrichment (image + age metadata when available).
- Live Activity widget target included (`MyFlightLiveActivity`).

## Tech Stack

- SwiftUI
- SwiftData
- MapKit
- WidgetKit / ActivityKit (Live Activity target)
- Xcode project with `.xcconfig`-based secrets

## Project Structure

- `MyFlight/`
  - `ContentView.swift`: main tab architecture and sheet orchestration
  - `Views/`: list/detail/map/logbook UI
  - `Utilities/FlightLookupService.swift`: API integration and response normalization
  - `Models/`: domain models (`Flight`, `Airport`, etc.)
  - `LiveActivities/`: in-app activity integration
- `MyFlightLiveActivity/`: Live Activity widget extension target
- `Config/`
  - `Debug.xcconfig`
  - `Release.xcconfig`
  - `Secrets.xcconfig.sample`

## API Integration

MyFlight combines two providers:

1. AeroDataBox (via RapidAPI)
- Flight lookup by number/date
- Airport and operational time fields
- Aircraft image endpoint

2. AirLabs
- Optional aircraft enrichment from tail number
- Used to derive aircraft age/build metadata when available

### Key Rotation for RapidAPI (429 Handling)

`FlightLookupService` supports rotating keys when a request hits `429 Too Many Requests`.

Resolution order:
1. `FLIGHT_API_KEYS` (comma-separated key pool)
2. `FLIGHT_API_KEY` (single fallback key)

Behavior:
- Retry with next key on `429`
- Return a rate-limit error after all keys are exhausted
- Return invalid-response errors for non-429 HTTP failures

## Setup

1. Create a local secrets file:
- Copy `Config/Secrets.xcconfig.sample` to `Config/Secrets.xcconfig`

2. Add API keys in `Config/Secrets.xcconfig`:

```xcconfig
FLIGHT_API_KEY = your_primary_rapidapi_key_here
FLIGHT_API_KEYS = key_one,key_two,key_three
AIRLABS_API_KEY = your_airlabs_api_key_here
```

3. Open `MyFlight.xcodeproj` in Xcode and run the `MyFlight` scheme.

Notes:
- `Secrets.xcconfig` should stay local and private.
- `FLIGHT_API_KEYS` is recommended for better resilience against rate limits.
- If `AIRLABS_API_KEY` is missing, flight lookup still works and enrichment is skipped.

## Data Flow

1. User enters flight number + date.
2. `FlightLookupService.lookup(...)` fetches flight candidates.
3. Candidates are filtered and ranked for best match.
4. Optional enrichment fetches aircraft image/age metadata.
5. Result is mapped to `FlightDraft` and persisted as `Flight`.
6. Views render from SwiftData into map/list/detail/logbook surfaces.

## Build (CLI)

```bash
xcodebuild -scheme MyFlight -configuration Debug -sdk iphonesimulator -destination 'name=iPhone 17 Pro'
```

## Troubleshooting

- `Flight API key missing`
  - Ensure `FLIGHT_API_KEYS` or `FLIGHT_API_KEY` is configured.
- Frequent 429 responses
  - Add multiple keys to `FLIGHT_API_KEYS`.
- Missing aircraft age
  - Verify `AIRLABS_API_KEY` and tail-number availability.
- Missing aircraft image
  - Not all registrations have photo assets; placeholder rendering is expected.

## Development Notes

- Keep provider DTO parsing private to `FlightLookupService`.
- Normalize into app-facing models before UI consumption.
- Prefer optional-safe rendering for all provider data fields.
- When adding flight fields, thread changes through:
  - lookup result
  - draft model
  - persisted `Flight`
  - detail/list views
