import SwiftUI

/// Fond animé : halos colorés qui dérivent lentement (effet « aura »).
struct AuraBackground: View {
    var colors: [Color] = [.auraPurple, .auraPink, .auraCyan]
    var intensity: Double = 0.35

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    Color.auraBackground
                    ForEach(Array(colors.enumerated()), id: \.offset) { i, color in
                        let phase = t / (7 + Double(i) * 2) + Double(i) * 2.1
                        Circle()
                            .fill(color.opacity(intensity))
                            .frame(width: geo.size.width * 1.1)
                            .blur(radius: 90)
                            .offset(
                                x: cos(phase) * geo.size.width * 0.35,
                                y: sin(phase * 1.3) * geo.size.height * 0.3 - geo.size.height * 0.15
                            )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
