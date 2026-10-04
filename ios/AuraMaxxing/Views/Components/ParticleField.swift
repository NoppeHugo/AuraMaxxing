import SwiftUI

/// Particules lumineuses qui montent, aux couleurs de l'aura.
/// Position calculée à partir du temps (aucun état) → fluide et léger.
struct ParticleField: View {
    var colors: [Color]
    var count = 60
    var speed: Double = 1

    private struct Seed {
        let x: Double, drift: Double, size: Double, period: Double, offset: Double, color: Int
    }

    private let seeds: [Seed]

    init(colors: [Color], count: Int = 60, speed: Double = 1) {
        self.colors = colors
        self.count = count
        self.speed = speed
        var rng = SystemRandomNumberGenerator()
        seeds = (0..<count).map { _ in
            Seed(
                x: Double.random(in: 0...1, using: &rng),
                drift: Double.random(in: -0.08...0.08, using: &rng),
                size: Double.random(in: 2...6, using: &rng),
                period: Double.random(in: 3...7, using: &rng),
                offset: Double.random(in: 0...10, using: &rng),
                color: Int.random(in: 0..<max(1, colors.count), using: &rng)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate * speed
            Canvas { ctx, size in
                ctx.blendMode = .plusLighter
                for s in seeds {
                    let progress = ((t + s.offset) / s.period).truncatingRemainder(dividingBy: 1)
                    let x = (s.x + s.drift * sin(progress * .pi * 2)) * size.width
                    let y = size.height * (1.05 - progress * 1.1)
                    let alpha = sin(progress * .pi)
                    let r = s.size * (0.6 + alpha * 0.6)
                    let rect = CGRect(x: x - r * 2, y: y - r * 2, width: r * 4, height: r * 4)
                    let color = colors.isEmpty ? Color.white : colors[s.color % colors.count]
                    ctx.opacity = alpha * 0.9
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(Gradient(colors: [color, color.opacity(0)]),
                                              center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
