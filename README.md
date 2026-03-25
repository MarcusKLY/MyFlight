# MyFlight

MyFlight is an iOS flight-tracking app built with SwiftUI and SwiftData. It lets you search flights by number and date, save them locally, and inspect rich operational details such as route, timeline events, delay deltas, map route visualization, gates/terminals, and aircraft information.

## Architecture Overview

### UI Layer (SwiftUI)
- Main entry: `MyFlightApp` and `ContentView`
- Flight list/map interactions: list + map container with selection-driven detail sheets
- Flight detail: `FlightDetailView`
  - route + progress + timeline + gate/terminal + aircraft sections
  - dual-time display (airport local + optional device-local fallback)
  - event-based timeline rendering with deduplication and precedence

### Persistence Layer (SwiftData)
- Domain model: `Flight` (`@Model`) and `Airport`
- Stores both schedule and operational timestamps:
  - departure: scheduled/revised/estimated/actual/runway
  - arrival: scheduled/revised/estimated/predicted/actual/runway
- Stores aircraft metadata:
  - model, tail number, image URL, aircraft age, call sign

### Mapping Layer (MapKit)
- `MapViewContainer` renders airport markers and route paths
- Geodesic path utilities provide realistic long-haul arc rendering

## API Architecture

MyFlight combines two APIs:

1. AeroDataBox (RapidAPI)
- Flight operations, airport metadata, and base aircraft info
- Endpoint used for lookup:
  - `/flights/number/{flightNumber}/{yyyy-MM-dd}`
- Aircraft image fetch:
  - `/aircrafts/reg/{reg}/image/image`

2. AirLabs
- Deep aircraft metadata enrichment
- Endpoint used:
  - `/api/v9/fleets?reg={tail_number}`
- Used to derive `aircraftAge` from age/built fields when available

### RapidAPI Key Rotation (429 Fallback)
`FlightLookupService` supports a key pool and rotates automatically when a request returns `429 Too Many Requests`.

Resolution order:
1. `FLIGHT_API_KEYS` (comma-separated list)
2. Fallback to `FLIGHT_API_KEY` (single key)

Behavior:
- On `429`, retry with the next key
- If all keys are rate-limited, return a user-facing rate-limit error
- Non-429 HTTP failures return invalid-response errors

## Configuration

### 1. Add your secrets file
Copy:
- `Config/Secrets.xcconfig.sample` -> `Config/Secrets.xcconfig`

`Secrets.xcconfig` is git-ignored and should remain local/private.

### 2. Set API keys in `Config/Secrets.xcconfig`

```xcconfig
FLIGHT_API_KEY = your_primary_rapidapi_key_here
FLIGHT_API_KEYS = key_one,key_two,key_three
AIRLABS_API_KEY = your_airlabs_api_key_here
```

Notes:
- `FLIGHT_API_KEYS` is preferred for production usage.
- `FLIGHT_API_KEY` is still supported as fallback.
- If `AIRLABS_API_KEY` is empty, aircraft age enrichment is skipped gracefully.

### 3. Build settings wiring
The project already wires these through:
- `Config/Debug.xcconfig`
- `Config/Release.xcconfig`
- `MyFlight-Info.plist` keys:
  - `FLIGHT_API_KEY`
  - `FLIGHT_API_KEYS`
  - `AIRLABS_API_KEY`

## Data Flow

1. User searches by flight number + date.
2. `FlightLookupService.lookup(...)` fetches AeroDataBox flight candidates.
3. Service filters candidates by selected departure date.
4. Service enriches aircraft fields:
- image URL from AeroDataBox aircraft image endpoint
- age metadata from AirLabs fleets endpoint
5. Result maps into `FlightDraft` then persisted as `Flight`.
6. UI reads from SwiftData and renders list, map, and detail timeline.

## Extending the Codebase

### Add new provider data
- Start in `FlightLookupService`.
- Keep provider-specific DTOs private to the service file.
- Map into `FlightLookupResult` only after normalization.
- Add optional fields to `Flight` model and thread through `FlightDraft`.

### Timeline logic changes
- Centralize event generation in `FlightDetailView`:
  - departure/arrival event arrays
  - deduplication precedence
  - view-only formatting in helper methods
- Preserve baseline semantics:
  - scheduled event anchored at top
  - suppress expected rows when confirmed events exist

### UI additions
- Place new detail blocks as separate computed views in `FlightDetailView`.
- Keep icons/labels in `infoRow(...)` for visual consistency.
- Prefer optional-safe rendering (empty/missing API fields should not break layout).

## Maintenance Checklist

- Validate keys are set in local `Secrets.xcconfig`.
- Test with at least one flight that returns:
  - revised times without actuals
  - multi-candidate same-day results
  - missing aircraft image
- Run simulator build:

```bash
xcodebuild -scheme MyFlight -configuration Debug -sdk iphonesimulator -destination 'name=iPhone 17 Pro'
```

## Troubleshooting

- "Flight API key missing"
  - Ensure `FLIGHT_API_KEYS` or `FLIGHT_API_KEY` is configured.
- Frequent rate limits
  - Add multiple keys to `FLIGHT_API_KEYS`.
- No aircraft age shown
  - Confirm `AIRLABS_API_KEY` is valid and the tail number exists in AirLabs fleets data.
- No aircraft photo shown
  - Some tail numbers do not have image assets; UI falls back to placeholder automatically.
