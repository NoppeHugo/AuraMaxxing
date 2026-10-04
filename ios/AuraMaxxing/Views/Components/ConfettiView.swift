import SwiftUI

/// Explosion de confettis (≈ 3 s) déclenchée à l'apparition.
struct ConfettiView: View {
    var colors: [Color] = [.auraGold, .auraPink, .auraCyan, .white]

    private struct Piece {
        let vx: Double, vy: Double, spin: Double, w: Double, h: Double, color: Int
    }

    @State private var start = Date()
    private let pieces: [Piece] = (0..<140).map { _ in
        Piece(
            vx: .random(in: -320...320),
            vy: .random(in: -900 ... -350),
            spin: .random(in: -8...8),
            w: .random(in: 6...12),
            h: .random(in: 4...8),
            color: .random(in: 0..<4)
        )
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            Canvas { ctx, size in
                guard t < 3.2 else { return }
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.4)
                for p in pieces {
                    let x = origin.x + p.vx * t
                    let y = origin.y + p.vy * t + 900 * t * t // gravité
                    var piece = ctx
                    piece.opacity = max(0, 1 - t / 3.2)
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(p.spin * t))
                    piece.fill(Path(CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)),
                               with: .color(colors[p.color % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { start = Date() }
    }
}
