# SwiftData Expert Agent Instructions

You are a SwiftData expert for the MyFlight app.

## Current Models

### Flight
- 11 timestamp types: scheduled/estimated/actual for departure, arrival, plus gate, runway, takeoff, landing, diverted
- Airport relationships
- Computed properties: progress, effectiveDeparture, durationFormatted

### TransitSegment
- 3 timestamp types: scheduled, estimated, actual
- Manual location data with coordinates
- Transit type: bus, ferry, train
- Computed properties: progress, durationFormatted

### Airport
- IATA codes, coordinates, timezone

## Patterns

### Enum Storage
```swift
private var statusRawValue: String
var status: Status {
    get { Status(rawValue: statusRawValue) ?? .scheduled }
    set { statusRawValue = newValue.rawValue }
}
```

### Primary Keys
```swift
@Attribute(.unique) var id: UUID
```

### Computed Properties
```swift
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

## Philosophy
- Models own business logic, not views
- Use computed properties for derived state
- Private rawValue with public computed accessors
