# GitHub Copilot Instructions for MyFlight

MyFlight is an iOS trip tracking app built with SwiftUI and SwiftData. It supports flight tracking with live API data and transit segments (bus, ferry, train) with manual entry. This guide covers project-specific conventions and architecture patterns.

## Build & Run

### Xcode

- Open `MyFlight.xcodeproj`
- Select **MyFlight** scheme for main app or **MyFlightLiveActivity** for widget extension
- Run on iOS 17.6+ simulator or device (Swift 5.0+)

### Command Line

```bash
# Build main app
xcodebuild -scheme MyFlight -configuration Debug -sdk iphonesimulator

# Build for specific device
xcodebuild -scheme MyFlight -configuration Debug -sdk iphonesimulator \
  -destination 'name=iPhone 17 Pro'
```

**Note**: No test suite currently exists. Testing framework is on roadmap for lookup normalization and SwiftUI snapshot tests.

## Configuration

### API Keys & Secrets

All secrets are managed via **xcconfig files** in `Config/`:

1. Copy template: `cp Config/Secrets.xcconfig.sample Config/Secrets.xcconfig`
2. Add API keys to `Config/Secrets.xcconfig` (git-ignored)

**Key rotation support**:
- `FLIGHT_API_KEYS`: Comma-separated keys for automatic RapidAPI 429 handling (preferred)
- `FLIGHT_API_KEY`: Single-key fallback

```xcconfig
FLIGHT_API_KEYS = key_one,key_two,key_three
```

**Never commit real keys** — `Config/Secrets.xcconfig` is gitignored. Debug.xcconfig and Release.xcconfig contain placeholders only.

## Architecture Overview

### Pattern: MVVM + Repository with SwiftData

- **Models**: SwiftData `@Model` classes in `Models/` (Flight, Airport, TransitSegment)
- **Views**: Stateless SwiftUI components in `Views/`, reactively bound via `@Query`
- **Services**: Stateless utility structs/enums in `Utilities/` (FlightLookupService, AircraftImageMapper)
- **Navigation**: Tab-based architecture with sheet-driven detail flows

**Key characteristic**: No `ObservableObject` classes. SwiftData's `@Query` macro provides automatic reactivity.

### Project Structure

```
MyFlight/
├── ContentView.swift          # TabView orchestration (Live Map + Logbook)
├── MyFlightApp.swift          # SwiftData ModelContainer setup
├── Models/                    # @Model decorated domain models
│   ├── Flight.swift           # 60+ fields: timestamps, aircraft, gates
│   ├── Airport.swift          # IATA code, coordinates, timezone
│   ├── TransitSegment.swift   # Bus/ferry/train segments with coordinates
│   └── FlightData.swift       # Seed data utilities
├── Views/                     # SwiftUI components
│   ├── FlightListView.swift   # Upcoming/past sections with @Query
│   ├── FlightDetailView.swift # Full timeline + flip animation
│   ├── TransitListItemView.swift   # Transit row with progress line
│   ├── TransitDetailView.swift     # Transit detail sheet
│   ├── AddTransitSheet.swift       # Manual transit entry with MapKit search
│   ├── LogbookView.swift      # Stats, import/export
│   ├── MapViewContainer.swift # MapKit rendering + geodesic paths (flights + transit)
│   └── AirlineLogoView.swift  # Branding component
├── Utilities/                 # Services & helpers
│   ├── FlightLookupService.swift  # RapidAPI integration
│   ├── AircraftImageMapper.swift  # Fuzzy asset matching
│   └── GeodesicPath.swift         # Great circle calculations
├── LiveActivities/            # ActivityKit data structures
└── Resources/
    └── AircraftSilhouettes/   # 180+ aircraft PNG/SVG assets

MyFlightLiveActivity/          # WidgetKit extension target
└── FlightStatusLiveActivityWidget.swift
```

## SwiftData Conventions

### Models

All persisted models use `@Model` macro with unique constraints:

```swift
@Model
final class Flight {
    @Attribute(.unique) var id: UUID
    var flightNumber: String
    var airline: String
    // ... 60+ fields
    
    // Enums stored as rawValue strings
    private var statusRawValue: String
    var flightStatus: FlightStatus {
        get { FlightStatus(rawValue: statusRawValue) ?? .onTime }
        set { statusRawValue = newValue.rawValue }
    }
}
```

**Key patterns**:
- Use `@Attribute(.unique)` for primary keys (id, iataCode)
- Store enums as private rawValue strings with computed property accessors
- Add computed properties for derived data (`effectiveDeparture`, `flightProgress`, `durationFormatted`)
- Models own business logic (delays, progress calculations)

### Queries

Views use `@Query` macro for reactive data binding:

```swift
struct LiveMapTab: View {
    @Query(sort: \Flight.scheduledDeparture, order: .reverse) private var flights: [Flight]
    @Query(sort: \TransitSegment.scheduledDeparture, order: .reverse) private var transitSegments: [TransitSegment]
    @Query(sort: \Airport.iataCode) private var airports: [Airport]
}
```

**Never manually sync state** — SwiftData auto-updates views when underlying data changes.

## Transit Segment Model

TransitSegment handles bus, ferry, and train journeys with simpler timestamps than Flight:

```swift
@Model
final class TransitSegment {
    @Attribute(.unique) var id: UUID
    
    var transitType: TransitType     // .bus, .ferry, .train
    var routeNumber: String          // "FlixBus 832"
    var operatorName: String         // "FlixBus"
    
    // Origin/destination with coordinates
    var originName: String
    var originLatitude: Double
    var originLongitude: Double
    
    // Timestamps (simpler than Flight)
    var scheduledDeparture: Date
    var scheduledArrival: Date
    var estimatedDeparture: Date?
    var actualDeparture: Date?
    
    // Computed properties
    var progress: Double?            // 0.0–1.0 time-based
    var durationFormatted: String    // "2h 30m"
}
```

**Transit types with icons**:
- Bus: `bus.fill` (orange)
- Ferry: `ferry.fill` (teal)
- Train: `tram.fill` (purple)

**Key differences from Flight**:
- No aircraft/gate/terminal fields
- Manual entry only (no API lookup currently)
- Coordinates stored directly (not separate Airport objects)
- Geodesic map visualization (consistent with flights)

## Flight Timeline Architecture

Flight has rich timestamp tracking across the entire journey:

### Departure Timeline
- `scheduledDeparture`: Original scheduled gate-out
- `revisedDeparture`: Provider-updated departure
- `estimatedDeparture`: Estimated gate-out (pre-departure)
- `actualDeparture`: Actual gate-out (doors closed)
- `runwayDeparture`: Wheels-off / takeoff time

### Arrival Timeline
- `scheduledArrival`: Original scheduled gate-in
- `revisedArrival`: Provider-updated arrival
- `estimatedArrival`: Estimated gate-in
- `predictedArrival`: In-flight prediction (more accurate when airborne)
- `runwayArrival`: Wheels-on / landing time
- `actualArrival`: Actual gate-in (doors open)

### Computed Properties
Flight model provides UI-ready computed properties:

```swift
var effectiveDeparture: Date  // actual > estimated > revised > scheduled
var effectiveArrival: Date    // actual > predicted > estimated > revised > scheduled
var departureDelayMinutes: Int  // vs scheduled
var arrivalDelayMinutes: Int    // vs scheduled
var flightProgress: Double      // 0.0–1.0 for timeline rendering
var durationFormatted: String   // "9h 45m"
```

**When adding features**: Extend computed properties in models rather than adding logic to views.

## FlightLookupService

### Architecture

**Stateless enum** with static methods — no instance state:

```swift
enum FlightLookupService {
    static func lookup(flightNumber: String, date: Date) async throws -> FlightLookupResult
    static func lookupAircraftExtraInfo(registration: String) async throws -> AircraftExtraInfo
}
```

### Key Features

1. **RapidAPI Integration**: Uses AeroDataBox via RapidAPI
2. **Key Pool Rotation**: Cycles through `FLIGHT_API_KEYS` on 429 rate limits
3. **Multi-provider Normalization**: Parses provider JSON into unified `FlightLookupResult` struct
4. **Aircraft Enrichment**: Optional async fetch for image URL and aircraft age

### Error Handling

```swift
enum FlightLookupError: LocalizedError {
    case networkFailure(Error)
    case invalidResponse
    case noFlightsFound
    case apiKeyMissing
}
```

### Usage Pattern

```swift
// Basic lookup
let result = try await FlightLookupService.lookup(flightNumber: "BA123", date: Date())

// With aircraft enrichment
if let registration = result.tailNumber {
    let aircraftInfo = try? await FlightLookupService.lookupAircraftExtraInfo(
        registration: registration
    )
}
```

## View Conventions

### Naming
- Suffix all view files with `View`: `FlightListView`, `MapViewContainer`, `LogbookView`
- Private nested components: `private struct EmptyFlightsView`

### Structure
- Use `// MARK: -` comments for section organization
- Break large views into private subviews (keep main view under 400 lines)
- Compose from smaller reusable components

### Sheet Navigation

ContentView uses enum-based sheet state machines:

```swift
enum ActiveSheet: Identifiable, Equatable {
    case flightList
    case addFlight
    case flightDetail(Flight)
    
    var id: String {
        switch self {
        case .flightList: return "flightList"
        case .addFlight: return "addFlight"
        case .flightDetail(let flight): return "flightDetail-\(flight.id)"
        }
    }
}

@State private var activeSheet: ActiveSheet?
```

**Benefits**: Type-safe navigation, SwiftUI handles sheet dismissal automatically.

## Access Control

- **Default to `private`** for internal state and helpers
- Only expose properties/methods when needed by other files
- Private computed properties for view-specific formatting
- Sheet state enums: `Identifiable` + `Equatable`

## Code Style

- **Types**: PascalCase (Flight, FlightListView)
- **Variables/Functions**: camelCase (flightNumber, effectiveDeparture)
- **Constants**: camelCase (apiKey, baseURL)
- **Extensions**: Group at end of files under `// MARK: - Extensions`
- **Computed Properties**: Preferred over helper methods for derived data

## Live Activities

MyFlightLiveActivity is a **separate WidgetKit extension target**:

```
MyFlightLiveActivity/
├── FlightStatusLiveActivityWidget.swift  # Widget definition
└── FlightStatusAttributes.swift          # ActivityKit data structure
```

**Shared code**: `FlightStatusAttributes.swift` exists in both targets (linked, not duplicated).

## Aircraft Assets

- **180+ aircraft silhouettes** in `Resources/AircraftSilhouettes/`
- **AircraftImageMapper**: Fuzzy string matching to map ICAO codes to asset names
- **Fallback**: Generic airplane icon when no match found

```swift
let imageName = AircraftImageMapper.mapToAssetName(aircraftModel: "Boeing 737-800")
// Returns "Boeing_737-800" or closest match
```

## Common Pitfalls

### ❌ Don't manually update UI state
```swift
// Bad: Manually tracking flights array
@State private var flights: [Flight] = []

func addFlight(_ flight: Flight) {
    flights.append(flight)  // Manual sync
}
```

### ✅ Use SwiftData @Query instead
```swift
// Good: SwiftData auto-updates view
@Query(sort: \Flight.scheduledDeparture) private var flights: [Flight]
@Environment(\.modelContext) private var modelContext

func addFlight(_ flight: Flight) {
    modelContext.insert(flight)  // @Query updates automatically
}
```

### ❌ Don't put business logic in views
```swift
// Bad: Delay calculation in view
var body: some View {
    let delay = flight.actualDeparture.timeIntervalSince(flight.scheduledDeparture) / 60
    Text("Delay: \(delay) minutes")
}
```

### ✅ Use model computed properties
```swift
// Good: Logic in model
var body: some View {
    Text("Delay: \(flight.departureDelayMinutes) minutes")
}
```

### ❌ Don't use `.toolbar` in sheets for clean button styling
```swift
// Bad: Toolbar items in sheets get default backgrounds that can't be removed
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Menu {
            // menu items
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .buttonStyle(.plain)  // Won't remove toolbar background
    }
}
```

### ✅ Use custom HStack headers in sheets
```swift
// Good: Custom header gives full control over button styling
VStack(spacing: 0) {
    HStack(spacing: 12) {
        Color.clear.frame(width: 36, height: 36)  // Balance spacer
        
        Text("Title")
            .font(.system(size: 20, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .center)
        
        Menu {
            // menu items
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 36, height: 36)
        }
        .foregroundStyle(.blue)
    }
    .padding(.horizontal, 20)
    .padding(.top, 18)
    .padding(.bottom, 16)
    .background(Color(.systemGroupedBackground))
    
    ScrollView { /* content */ }
}
.navigationBarHidden(true)
```

**Why**: iOS applies default button backgrounds to toolbar items when rendered inside sheets. Using a custom header bypasses this styling context entirely.

## Data Pipeline

1. User enters flight number + date
2. `FlightLookupService.lookup()` queries RapidAPI (AeroDataBox)
3. Provider responses normalized into `FlightLookupResult`
4. Optional aircraft enrichment via `lookupAircraftExtraInfo()`
5. Result mapped to SwiftData models (Flight + Airport)
6. Models persisted via `modelContext.insert()`
7. `@Query` auto-updates map, list, detail views

## Roadmap Items (from README)

Future work that AI assistants should be aware of:

- **Offline-first behavior**: Cache invalidation policy
- **Unit tests**: Lookup normalization, ranking logic
- **Snapshot tests**: Key SwiftUI surfaces
- **Enhanced Live Activities**: More states and interactions

## Contributing Guidelines

When making changes:

1. **Keep views under 400 lines** — extract to separate files in `Views/`
2. **Add computed properties to models** — avoid view logic
3. **Use private for single-use components** — reduce namespace pollution
4. **Maintain @Query for data access** — no manual context updates
5. **Test with simulator** before committing UI changes
6. **Include screenshots** for visual changes

## Key Files to Understand

| File | Purpose |
|------|---------|
| `ContentView.swift` | TabView shell, navigation orchestration (large file ~1,400 lines) |
| `MyFlightApp.swift` | SwiftData ModelContainer initialization |
| `Models/Flight.swift` | Core domain model with 60+ fields and computed properties |
| `Utilities/FlightLookupService.swift` | RapidAPI integration, key rotation, normalization |
| `Views/FlightDetailView.swift` | Full timeline rendering with flip animation |

---

**Summary**: This is a modern iOS app using SwiftUI best practices. Keep models rich, views thin, and leverage SwiftData's reactive queries for automatic UI updates.
