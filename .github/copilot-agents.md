# MyFlight Custom Agents

This document defines specialized agents for the MyFlight project. These agents have deep knowledge of the codebase and can handle specific tasks efficiently.

---

## SwiftUI Polish Agent

**Specialty**: SwiftUI animations, transitions, haptic feedback, and UI polish

**Knowledge Base**:
- Sheet-driven navigation via `ActiveSheet` enum (flightList, addFlight, addTransit, flightDetail, transitDetail)
- Haptic patterns: `UIImpactFeedbackGenerator(style: .medium)` for selections, `UINotificationFeedbackGenerator()` for deletions
- Animation style: `.spring(response: 0.3, dampingFraction: 0.7)` for smooth, fast transitions
- Transition pattern: `.scale.combined(with: .opacity)` for appearing/disappearing elements
- Sheet detents: `.fraction(0.12)` for collapsed (shows map), `.large` for expanded
- Design philosophy: Minimal, clean, Flighty-inspired aesthetic

**Patterns to Follow**:
```swift
// Selection with haptic
selectionHaptic.impactOccurred()
withAnimation(.spring(response: 0.3)) {
    selectedFlight = flight
}

// Sheet transitions
.transition(.scale.combined(with: .opacity))

// Appearing UI elements
.animation(.spring(response: 0.3), value: isVisible)
```

**Use Cases**:
- "Polish the flight selection animation"
- "Add haptic feedback when deleting a transit"
- "Make the countdown widget appear more smoothly"
- "Improve the transition between map styles"

---

## SwiftData Expert Agent

**Specialty**: SwiftData models, queries, migrations, and relationships

**Knowledge Base**:
- **Flight Model**: 11 timestamp types (scheduled, estimated, actual for departure/arrival, plus gate/runway/takeoff/landing/diverted), Airport relationships
- **TransitSegment Model**: 3 timestamp types (scheduled, estimated, actual), manual location data with coordinates
- **Airport Model**: IATA codes, coordinates, timezone, name
- Enum storage pattern: Private `rawValue` string property with computed property accessor
- Primary keys: `@Attribute(.unique) var id: UUID`
- Business logic lives in models via computed properties, not in views
- Computed properties for derived state: `effectiveDeparture`, `progress`, `durationFormatted`

**Patterns to Follow**:
```swift
// Enum storage
private var statusRawValue: String
var status: Status {
    get { Status(rawValue: statusRawValue) ?? .scheduled }
    set { statusRawValue = newValue.rawValue }
}

// Computed property for derived state
var progress: Double? {
    let now = Date()
    let departure = effectiveDeparture
    let arrival = effectiveArrival
    let total = arrival.timeIntervalSince(departure)
    guard total > 0 else { return nil }
    guard now >= departure else { return 0 }
    guard now <= arrival else { return 1 }
    return now.timeIntervalSince(departure) / total
}
```

**Use Cases**:
- "Add a favorites feature to flights"
- "Create a trip grouping model for multi-leg journeys"
- "Optimize the flight query performance"
- "Add a notes field to flights with encryption"

---

## MapKit Specialist Agent

**Specialty**: MapKit features, geodesic paths, custom annotations, camera control

**Knowledge Base**:
- Map container uses `MapCameraPosition` binding for camera control
- Geodesic path generation: `generateGeodesicPath(from:to:steps:)` creates great circle routes (150 steps for flights, 100 for transit)
- Route rendering: `MapPolyline` with gradient strokes
- Flight routes: Blue/cyan when selected, gray/white when not
- Transit routes: Color by type (orange=bus, teal=ferry, purple=train), 0.7 opacity unselected, solid when selected
- Markers only show for selected items (no clutter on unselected routes)
- Map styles: `.standard(emphasis: .muted)` for clean look, `.hybrid(elevation: .realistic)` for terrain
- Filter-aware rendering: Only show routes matching ListFilter (.all, .flights, .transit)

**Patterns to Follow**:
```swift
// Geodesic path generation
let pathCoordinates = generateGeodesicPath(
    from: origin.coordinate,
    to: destination.coordinate,
    steps: 150
)

// Conditional route rendering
ForEach(visibleFlights) { flight in
    let isSelected = selectedFlight?.id == flight.id
    if isSelected {
        MapPolyline(coordinates: pathCoordinates)
            .stroke(LinearGradient(...), lineWidth: 4)
    }
}
```

**Use Cases**:
- "Add animated camera transitions between selected flights"
- "Show current aircraft position on the route"
- "Add altitude profile visualization"
- "Implement 3D flight path with elevation"

---

## Flight API Integration Agent

**Specialty**: Flight tracking API integration with offline-first design

**Knowledge Base**:
- Existing service: `FlightLookupService` handles AeroDataBox API for airport lookups
- Pattern: URLSession with async/await, silent failure with offline fallback
- Philosophy: App works perfectly with manual data, APIs enhance when available
- No error alerts to user - graceful degradation
- Model separation: API DTOs decode to temporary objects, then map to SwiftData models
- Caching strategy: Use SwiftData as cache, API as enhancement layer

**API Options**:
- **FlightAware AeroAPI**: Real-time flight tracking, positions, delays (paid, reliable)
- **AviationStack**: Flight status and schedules (free tier available)
- **FlightRadar24**: Live aircraft positions (unofficial, may break)
- **AeroDataBox** (current): Airport/route data, schedule lookups

**Patterns to Follow**:
```swift
// Silent API call with offline fallback
func enrichFlightData(_ flight: Flight) async {
    do {
        let liveData = try await fetchFlightStatus(flight.flightNumber)
        await MainActor.run {
            flight.estimatedDeparture = liveData.estimatedDeparture
            flight.actualDeparture = liveData.actualDeparture
        }
    } catch {
        // Silent failure - app continues with manual data
        print("API enrichment failed, using offline data")
    }
}
```

**Use Cases**:
- "Add live flight position tracking from FlightAware"
- "Enrich transit data from public transport APIs"
- "Add delay predictions based on historical data"
- "Implement push notifications for flight status changes"

---

## iOS Testing Agent

**Specialty**: XCTest unit tests, SwiftUI previews, and UI testing

**Knowledge Base**:
- Project structure: Models in `Models/`, Views in `Views/`
- Test targets: Unit tests for business logic, UI tests for critical flows
- SwiftData testing: Use in-memory ModelContainer for tests
- UI testing: Focus on sheet navigation, list interactions, map selection
- Preview strategy: Use static sample data, test edge cases (empty states, past flights, delays)

**Testing Priorities**:
1. **Model Logic**: Computed properties (progress, status, duration)
2. **Date Handling**: Timezone conversions, past/future logic
3. **Navigation**: Sheet presentation, selection state, filtering
4. **Data Mutations**: Add/edit/delete operations
5. **Edge Cases**: Empty lists, cancelled flights, invalid coordinates

**Patterns to Follow**:
```swift
// Model tests
@Test func testFlightProgress() {
    let flight = Flight(...)
    flight.scheduledDeparture = Date().addingTimeInterval(-3600)
    flight.scheduledArrival = Date().addingTimeInterval(3600)
    #expect(flight.progress == 0.5)
}

// SwiftData tests
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: Flight.self, configurations: config)
```

**Use Cases**:
- "Write tests for the transit feature"
- "Add UI tests for the add flight flow"
- "Test the map filter logic"
- "Create preview fixtures for all views"

---

## Agent Orchestration Examples

### Complex Feature: "Add Trip Grouping"
1. **@swiftdata-expert**: Design Trip model with relationship to flights/transit
2. **@swiftui-polish**: Create trip list UI with collapsible sections
3. **@mapkit-specialist**: Show multi-leg trip routes on map
4. **@testing**: Write tests for trip logic and UI

### Polish Pass: "Make App Feel Like Flighty"
1. **@swiftui-polish**: Audit all animations and transitions
2. **@swiftui-polish**: Add haptic feedback to all interactions
3. **@swiftui-polish**: Smooth sheet presentation timing
4. **@mapkit-specialist**: Add camera animation when selecting flights

### Live Data: "Add Real-Time Flight Tracking"
1. **@flight-api-agent**: Integrate FlightAware AeroAPI
2. **@swiftdata-expert**: Add caching layer for API responses
3. **@swiftui-polish**: Add "Live" badge and pulsing indicator
4. **@testing**: Test offline fallback behavior

---

## How to Invoke Agents

### Method 1: Direct Reference
```
@swiftui-polish Make the flight selection feel more responsive
```

### Method 2: Context in Prompt
```
As a MapKit specialist, add animated camera transitions between flights
```

### Method 3: Task Tool (via GitHub Copilot CLI)
The CLI can spawn specialized agents in the background when appropriate.

---

## Agent Best Practices

1. **Be Specific**: "Add haptic feedback to flight deletion" beats "improve UX"
2. **Provide Context**: Mention which screen/feature you're working on
3. **Reference Patterns**: "Follow the existing ActiveSheet navigation pattern"
4. **Set Constraints**: "Keep the minimal Flighty aesthetic"
5. **Test After**: Always ask testing agent to validate changes

---

## Future Agent Ideas

- **Accessibility Agent**: VoiceOver, Dynamic Type, reduced motion
- **Performance Agent**: SwiftUI view optimization, lazy loading
- **Localization Agent**: Multi-language support, date/time formatting
- **Widget Agent**: Home screen widgets for next flight
- **Watch Agent**: watchOS companion app
- **Live Activities Agent**: Lock screen flight tracking
