# where-ive-been

Your location history is more than a list of coordinates. It is a record of the places you returned to, the roads you took, and how your habits changed over time.

**where-ive-been** turns a Google Maps Timeline export into a private, visual travel journal for macOS. Open your JSON file and explore your history through maps, routes, timelines, and long-term patterns—all without uploading your data anywhere.

<img width="1115" height="827" alt="1" src="https://github.com/user-attachments/assets/2d54e4ac-d5c1-4c25-87cb-1975226df91d" />


## What you can explore

- See your recorded routes on Apple Maps, with year filters and satellite view.
- Browse a searchable, day-by-day timeline of visits and journeys.
- Open any timeline entry to inspect its route and location details.
- Explore the countries, states or regions, and cities in your history.
- Compare distance, visits, journeys, and active days across years.
- Discover your busiest months, common travel times, longest streaks, and favorite travel modes.
- Use the year-by-month heatmap to see how your movement patterns have changed.

Country, region, and city names are matched locally using the bundled GeoNames database. No online geocoding service receives your coordinates.

## Your data stays yours

The app starts empty. It does not include a sample journey, personal location history, or anyone else's travel data.

When you choose a Google Timeline JSON export, **where-ive-been** reads it directly from its original location. The file is never modified, copied into the app, or uploaded to a server. Importing, route processing, geographic matching, and statistics all happen on your Mac.

Apple Maps provides the map imagery, so macOS may request map tiles from Apple while you browse.

## Run from source

You will need macOS 15 or later and Xcode with Swift 6 support.

Open `Package.swift` in Xcode and press Run, or launch it from Terminal:

```sh
swift run
```

The app will open with an import screen where you can select your own JSON export.

## Build the macOS app

```sh
./scripts/build-app.sh
open dist/where-ive-been.app
```

The finished bundle is created at `dist/where-ive-been.app`. This local build is ad-hoc signed and intended for testing. A release for other Macs should be signed with an Apple Developer ID and notarized by Apple.

## Data source and attribution

Offline place matching uses the GeoNames `cities5000`, admin-region, and country datasets. GeoNames data is licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/); full attribution is included with the bundled resources.

Geographic matches are approximate because coordinates are assigned to the nearest indexed locality.
