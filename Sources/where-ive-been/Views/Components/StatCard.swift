import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            Text(value)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .journeyCard()
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())
            if let subtitle {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyDataView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(JourneyTheme.heroGradient).frame(width: 112, height: 112)
                Image(systemName: "map.fill")
                    .font(.system(size: 43, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: JourneyTheme.indigo.opacity(0.35), radius: 30, y: 12)

            VStack(spacing: 8) {
                Text("Your story, mapped")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Choose your Google Maps Timeline export to turn years of movement into a private, visual journal.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            Button(action: action) {
                Label("Choose location-history.json", systemImage: "folder.badge.plus")
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(JourneyTheme.indigo)

            Label("Processed entirely on this Mac", systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
