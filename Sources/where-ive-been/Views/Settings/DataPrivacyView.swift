import SwiftUI

struct DataPrivacyView: View {
    @Environment(JourneyStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Your history stays yours")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("where-ive-been reads and analyzes your export entirely on this Mac.")
                        .font(.title3).foregroundStyle(.secondary)
                }

                privacyHero
                sourceDetails
                qualityDetails
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Data & Privacy")
    }

    private var privacyHero: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.green.opacity(0.13)).frame(width: 96, height: 96)
                Image(systemName: "lock.shield.fill").font(.system(size: 42)).foregroundStyle(.green)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("100% on-device").font(.title2.bold())
                Text("No account, no upload, no analytics SDK. Map tiles are provided by Apple Maps; your original Google export is never modified.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .journeyCard()
    }

    private var sourceDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Data source")
            detailRow("File", store.dataset.sourceURL.lastPathComponent, "doc.text.fill")
            Divider()
            detailRow("Location", store.dataset.sourceURL.deletingLastPathComponent().path, "folder.fill")
            Divider()
            detailRow("Imported", store.dataset.importedAt.formatted(date: .long, time: .shortened), "clock.fill")
            Button { store.showingImporter = true } label: {
                Label("Choose a different export", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent).tint(JourneyTheme.indigo)
        }
        .journeyCard()
    }

    private var qualityDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Import quality", subtitle: "What was understood from the Google export")
            HStack(spacing: 16) {
                qualityMetric("Normalized moments", store.dataset.events.count.formatted(), .green)
                qualityMetric("Visits", store.analytics.visitCount.formatted(), JourneyTheme.coral)
                qualityMetric("Movements", store.analytics.activityCount.formatted(), JourneyTheme.indigo)
                qualityMetric("Geo-matched", store.geography.matchedEvents.formatted(), JourneyTheme.aqua)
                qualityMetric("Skipped", store.dataset.skippedRecords.formatted(), .secondary)
            }
            Text("Place names are derived offline from GeoNames and licensed under CC BY 4.0.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .journeyCard()
    }

    private func detailRow(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).foregroundStyle(JourneyTheme.indigo).frame(width: 24)
            Text(title).font(.subheadline.weight(.semibold)).frame(width: 80, alignment: .leading)
            Text(value).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled).lineLimit(1)
            Spacer()
        }
    }

    private func qualityMetric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold()).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SettingsView: View {
    @Environment(JourneyStore.self) private var store

    var body: some View {
        Form {
            Section("Location history") {
                LabeledContent("Current file", value: store.dataset.sourceURL.lastPathComponent)
                LabeledContent("Moments", value: store.dataset.events.count.formatted())
                Button("Choose another export…") { store.showingImporter = true }
            }
            Section("Privacy") {
                Label("All analysis runs locally", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                Text("where-ive-been never writes to your source JSON file.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
