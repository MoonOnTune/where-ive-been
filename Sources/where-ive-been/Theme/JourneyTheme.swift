import SwiftUI

enum JourneyTheme {
    static let indigo = Color(red: 0.29, green: 0.27, blue: 0.95)
    static let aqua = Color(red: 0.18, green: 0.82, blue: 0.84)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.36)
    static let gold = Color(red: 1.0, green: 0.73, blue: 0.25)

    static let heroGradient = LinearGradient(
        colors: [indigo, Color(red: 0.48, green: 0.24, blue: 0.88), aqua],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func distance(_ meters: Double, precise: Bool = false) -> String {
        let kilometers = meters / 1_000
        if precise {
            return kilometers.formatted(.number.precision(.fractionLength(kilometers < 100 ? 1 : 0))) + " km"
        }
        return kilometers.formatted(.number.precision(.fractionLength(0))) + " km"
    }

    static func duration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval > 86_400 ? [.day, .hour] : [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: interval) ?? "—"
    }
}

struct JourneyCardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }
}

extension View {
    func journeyCard(padding: CGFloat = 18) -> some View {
        modifier(JourneyCardModifier(padding: padding))
    }
}
