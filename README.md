# MyFlight

![Platform](https://img.shields.io/badge/platform-iOS-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)
![Persistence](https://img.shields.io/badge/Persistence-SwiftData-34C759)

MyFlight is an open-source iOS flight tracking app focused on clear operational visibility. It combines live route visualization, timeline-based flight events, aircraft enrichment, and local persistence into a fast, native SwiftUI experience.

## Table Of Contents

- [Overview](#overview)
- [Core Features](#core-features)
- [Architecture](#architecture)
- [Project Layout](#project-layout)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Build And Run](#build-and-run)
- [Data Pipeline](#data-pipeline)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

## Overview

MyFlight is designed for people who want more than a basic arrival/departure card. The app supports:

- API-backed flight lookup
- Rich departure and arrival timeline events
- Live map tracking with route context
- Persistent local flight history
- Manual fallback entry when external data is incomplete

## Core Features

- Tab-based navigation: Live Map and Logbook
- Full-screen map with floating controls and map style toggle
- Sheet-driven workflow for flight list, flight details, and add-flight flow
- Search by flight number and date with result ranking
- Manual flight entry fallback when lookup fails
- Timeline rendering for scheduled, revised, estimated, actual, predicted, and runway events
- Aircraft metadata enrichment, including photo and age when available
- Live Activity support through a dedicated widget extension target

## Architecture

### UI Layer

- Built with SwiftUI and a tab-first layout
- `ContentView` orchestrates high-level tab navigation
- `LiveMapTab` manages sheet state and map/list/detail transitions

### Data Layer

- SwiftData models for `Flight` and `Airport`
- Persisted operational timestamps and aircraft metadata
- Query-driven rendering in list, detail, and map surfaces

### Services Layer

- `FlightLookupService` handles provider integration and normalization
- RapidAPI key-pool rotation for 429 resilience
- Provider normalization and request resilience for production usage

## Project Layout

- `MyFlight/`
  - `ContentView.swift`: app shell and interaction orchestration
  - `Views/`: list/detail/map/logbook UI components
  - `Models/`: domain models and business properties
  - `Utilities/`: external API integration and mapping utilities
  - `LiveActivities/`: in-app Live Activity helpers
- `MyFlightLiveActivity/`: WidgetKit extension target for Live Activities
- `Config/`: build configs and local secrets templates

## Getting Started

### Prerequisites

- macOS with Xcode 15+
- iOS Simulator or physical iOS device
- RapidAPI key (AeroDataBox access)

### Clone

```bash
git clone https://github.com/your-org/myflight.git
cd myflight
```

### Open Project

Open `MyFlight.xcodeproj` in Xcode, select the `MyFlight` scheme, then run.

## Configuration

1. Copy the sample secrets file:

```bash
cp Config/Secrets.xcconfig.sample Config/Secrets.xcconfig
```

2. Populate keys in `Config/Secrets.xcconfig`:

```xcconfig
FLIGHT_API_KEY = your_primary_rapidapi_key_here
FLIGHT_API_KEYS = key_one,key_two,key_three
```

Notes:

- `FLIGHT_API_KEYS` is preferred for key rotation support.
- `FLIGHT_API_KEY` remains a single-key fallback.
- Keep `Config/Secrets.xcconfig` local and never commit real secrets.

## Build And Run

### Xcode

- Scheme: `MyFlight`
- Configuration: `Debug` (recommended for local development)

### CLI

```bash
xcodebuild -scheme MyFlight -configuration Debug -sdk iphonesimulator -destination 'name=iPhone 17 Pro'
```

## Data Pipeline

1. User submits flight number and date.
2. `FlightLookupService.lookup(...)` requests provider candidates.
3. Candidates are filtered and ranked for best-fit selection.
4. Optional enrichment fetches aircraft image and age metadata.
5. Normalized result maps into app models and persists through SwiftData.
6. UI reflects updates across map, list, detail, and logbook screens.

## Troubleshooting

- Missing API key error
  - Ensure `FLIGHT_API_KEYS` or `FLIGHT_API_KEY` is configured.
- Frequent 429 errors
  - Add multiple keys to `FLIGHT_API_KEYS`.
- Missing aircraft image
  - Some registrations have no assets; placeholder rendering is expected.

## Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Keep changes scoped and documented.
4. Run a local simulator build before opening a PR.
5. Include screenshots for UI changes.

Recommended contribution areas:

- Timeline visualization improvements
- Caching and offline behavior
- Additional data provider adapters
- Accessibility and localization

## Roadmap

- Better offline-first behavior and cache invalidation policy
- Enhanced Live Activity states and interactions
- Unit tests for lookup normalization and ranking logic
- Snapshot tests for key SwiftUI surfaces

## License

This project is distributed under the MIT License. Add a `LICENSE` file if not already present.
