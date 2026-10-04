import SwiftUI

/// Nombre qui défile de 0 à la valeur cible (ease-out), piloté par le temps.
struct CountingText: View {
    let value: Int
    var duration: Double = 1.8
    var font: Font = .system(size: 96, weight: .black, design: .rounded)

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let p = min(1, context.date.timeIntervalSince(start) / duration)
            let eased = 1 - pow(1 - p, 4)
            Text("\(Int((Double(value) * eased).rounded()))")
                .font(font)
                .monospacedDigit()
        }
        .onAppear { start = Date() }
    }
}

/// Compte à rebours lisible : « 2j 14h », « 5h 12min », « 3min 40s ».
struct CountdownText: View {
    let end: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Self.format(end.timeIntervalSince(context.date)))
                .monospacedDigit()
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        let d = s / 86_400, h = (s % 86_400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d)j \(h)h" }
        if h > 0 { return "\(h)h \(m)min" }
        return "\(m)min \(s % 60)s"
    }
}
