# where-ive-been

A private, native macOS visual journal for Google Maps Timeline exports. where-ive-been turns `location-history.json` into an interactive map, a searchable daily timeline, and long-range travel insights without uploading the file anywhere.

## Highlights

- SwiftUI interface designed specifically for macOS
- Apple Maps route explorer with year filtering and satellite mode
- Balanced route rendering across the complete history, including standalone Timeline paths
- Offline country, state/region, and city enrichment
- Travel Atlas with geographic maps, rankings, date ranges, and drill-down details
- Overview dashboard for distance, visits, journeys, and active days
- Expandable, searchable day-by-day timeline
- Clickable timeline moments with full route and location detail maps
- Charts for monthly rhythm, yearly distance, travel modes, and personal records
- All-years seasonal rankings with total and per-year normalization
- Year-by-month travel heatmap plus weekday, hourly, streak, average, and median patterns
- Google export normalization and analytics run entirely on-device
- Starts with no data and lets each user explicitly choose their own JSON export

## Run

Open `Package.swift` in Xcode and press Run, or use:

```sh
swift run
```

## Build the app bundle

```sh
./scripts/build-app.sh
open dist/where-ive-been.app
```

The generated app lives at `dist/where-ive-been.app`. It is ad-hoc/local and intended for this Mac. For distribution to other Macs, sign and notarize it with an Apple Developer identity.

## Privacy

No location history, sample journey, personal path, or user identity is included in this repository or the built app. Each installation starts empty and asks the user to import their own Google Timeline JSON export.

The selected source JSON is read-only. Importing, normalization, grouping, and statistics happen locally, and the app does not copy the export into its bundle. The map itself uses Apple Maps tiles.

Place names use the bundled [GeoNames](https://www.geonames.org/) `cities5000`, admin-region, and country extracts under the [Creative Commons Attribution 4.0 license](https://creativecommons.org/licenses/by/4.0/). Geographic matching is approximate to the nearest indexed locality and does not send coordinates to a geocoding server.
