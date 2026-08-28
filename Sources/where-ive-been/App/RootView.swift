import SwiftUI
import UniformTypeIdentifiers

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case explore = "Explore"
    case atlas = "Travel Atlas"
    case timeline = "Timeline"
    case insights = "Insights"
    case data = "Data & Privacy"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "sparkles"
        case .explore: return "map.fill"
        case .atlas: return "globe.americas.fill"
        case .timeline: return "calendar.day.timeline.left"
        case .insights: return "chart.xyaxis.line"
        case .data: return "lock.doc.fill"
        }
    }
}

struct RootView: View {
    @Environment(JourneyStore.self) private var store
    @State private var selection: AppSection? = .overview

    var body: some View {
        @Bindable var store = store
        Group {
            switch store.loadState {
            case .idle:
                EmptyDataView { store.showingImporter = true }
            case .loading(let name):
                loadingView(name)
            case .failed(let message):
                failureView(message)
            case .loaded:
                appShell
            }
        }
        .fileImporter(
            isPresented: $store.showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await store.load(url) }
            }
        }
    }

    private var appShell: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                brand
                List(AppSection.allCases, selection: $selection) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .tag(section)
                        .font(.body.weight(section == selection ? .semibold : .regular))
                        .padding(.vertical, 4)
                }
                .listStyle(.sidebar)

                dataBadge
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 280)
        } detail: {
            detailView
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Year", selection: Binding(
                    get: { store.selectedYear },
                    set: { store.selectedYear = $0 }
                )) {
                    Text("All years").tag(Int?.none)
                    ForEach(store.analytics.years.reversed(), id: \.self) { year in
                        Text(String(year)).tag(Int?.some(year))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 125)

                Button { store.showingImporter = true } label: {
                    Label("Open", systemImage: "folder")
                }
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .overview {
        case .overview: OverviewView()
        case .explore: ExploreMapView()
        case .atlas: TravelAtlasView()
        case .timeline: TimelineView()
        case .insights: InsightsView()
        case .data: DataPrivacyView()
        }
    }

    private var brand: some View {
        HStack(spacing: 11) {
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, JourneyTheme.indigo)
            VStack(alignment: .leading, spacing: 0) {
                Text("where-ive-been").font(.headline)
                Text("Your movement story").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var dataBadge: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("On-device", systemImage: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            Text("\(store.dataset.events.count.formatted()) moments loaded")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(12)
    }

    private func loadingView(_ name: String) -> some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text("Reading your journey…").font(.title2.bold())
            Text(name).foregroundStyle(.secondary)
            Text("The original file stays right where it is.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn’t open history", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        } actions: {
            Button("Choose Another File") { store.showingImporter = true }
                .buttonStyle(.borderedProminent)
        }
    }
}
