import AVFoundation
import QuartzCore
import UIKit

/// Fabrique la « vidéo de révélation » prête à poster sur TikTok / Reels / Snap :
/// la vidéo de la personne en 9:16 + un habillage animé (scan, score qui monte, tier, roast, logo).
/// Chaque vidéo postée est une pub pour l'app — c'est le principal levier de viralité.
enum RevealVideoExporter {

    enum ExportError: LocalizedError {
        case noVideoTrack, failed
        var errorDescription: String? {
            switch self {
            case .noVideoTrack: return "Impossible de lire la vidéo d'origine."
            case .failed: return "L'export de la vidéo a échoué. Réessaie."
            }
        }
    }

    static let renderSize = CGSize(width: 1080, height: 1920)
    /// Au-delà, la vidéo est coupée : les formats courts performent mieux.
    static let maxDuration: Double = 30

    struct Content {
        let analysis: VideoAura
        let pseudo: String
        let leagueLine: String     // ex. "💡 Ligue Néon"
        let hashtag: String        // ex. "#AuraDuJour"
        let challengeLine: String? // ex. "J'ai battu @leo : 845 vs 812"
    }

    static func export(source: URL, content: Content) async throws -> URL {
        let asset = AVURLAsset(url: source)
        let assetDuration = try await asset.load(.duration)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { throw ExportError.noVideoTrack }

        let total = CMTimeMinimum(assetDuration, CMTime(seconds: maxDuration, preferredTimescale: 600))
        let range = CMTimeRange(start: .zero, duration: total)

        // Pistes vidéo + audio
        let composition = AVMutableComposition()
        guard let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.failed
        }
        try compVideo.insertTimeRange(range, of: videoTrack, at: .zero)
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compAudio.insertTimeRange(range, of: audioTrack, at: .zero)
        }

        // Cadrage « aspect fill » en 1080×1920, en respectant l'orientation d'origine.
        let natural = try await videoTrack.load(.naturalSize)
        let preferred = try await videoTrack.load(.preferredTransform)
        let oriented = CGRect(origin: .zero, size: natural).applying(preferred)
        let orientedSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))
        let scale = max(renderSize.width / orientedSize.width, renderSize.height / orientedSize.height)
        let transform = preferred
            .concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(
                translationX: (renderSize.width - orientedSize.width * scale) / 2,
                y: (renderSize.height - orientedSize.height * scale) / 2
            ))

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideo)
        layerInstruction.setTransform(transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        let (parent, videoLayer) = RevealOverlay.build(size: renderSize, duration: total.seconds, content: content)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)

        // Export MP4
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("aura-\(UUID().uuidString).mp4")
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.failed
        }
        session.outputURL = output
        session.outputFileType = .mp4
        session.videoComposition = videoComposition
        session.shouldOptimizeForNetworkUse = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                if session.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: session.error ?? ExportError.failed)
                }
            }
        }
        return output
    }
}

// MARK: - Habillage animé (Core Animation)

/// Chronologie (en secondes, adaptée à la durée de la vidéo) :
/// scan laser → le score défile → le tier tombe → titre → roast → logo et appel à l'action en continu.
private enum RevealOverlay {

    static func build(size: CGSize, duration: Double, content: RevealVideoExporter.Content) -> (CALayer, CALayer) {
        let a = content.analysis
        let c1 = UIColor(hex: a.auraColor), c2 = UIColor(hex: a.auraColor2)

        let parent = CALayer()
        parent.frame = CGRect(origin: .zero, size: size)
        parent.isGeometryFlipped = true // coordonnées « UIKit » (origine en haut à gauche)
        let videoLayer = CALayer()
        videoLayer.frame = parent.frame
        parent.addSublayer(videoLayer)

        let scanEnd = min(1.4, duration * 0.22)
        let countEnd = scanEnd + min(1.5, duration * 0.25)
        let tierAt = countEnd + 0.1
        let titleAt = tierAt + 0.35
        let roastAt = min(max(titleAt + 1.2, duration - 3.2), max(titleAt + 0.4, duration - 1.0))

        // Assombrissement en bas pour la lisibilité
        let shade = CAGradientLayer()
        shade.frame = CGRect(x: 0, y: size.height * 0.38, width: size.width, height: size.height * 0.62)
        shade.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.78).cgColor]
        parent.addSublayer(shade)

        // Cadre d'aura lumineux qui s'allume après le scan puis pulse
        let glow = CALayer()
        glow.frame = parent.frame.insetBy(dx: 10, dy: 10)
        glow.borderWidth = 14
        glow.cornerRadius = 40
        glow.borderColor = c1.cgColor
        glow.shadowColor = c2.cgColor
        glow.shadowRadius = 40
        glow.shadowOpacity = 1
        glow.shadowOffset = .zero
        glow.opacity = 0
        parent.addSublayer(glow)
        show(glow, at: scanEnd, fade: 0.4)
        let pulse = CABasicAnimation(keyPath: "borderColor")
        pulse.fromValue = c1.cgColor
        pulse.toValue = c2.cgColor
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .greatestFiniteMagnitude
        pulse.beginTime = AVCoreAnimationBeginTimeAtZero + scanEnd
        pulse.isRemovedOnCompletion = false
        glow.add(pulse, forKey: "pulse")

        // Laser de scan
        let laser = CALayer()
        laser.frame = CGRect(x: 0, y: 0, width: size.width, height: 10)
        laser.backgroundColor = UIColor(red: 0.24, green: 0.91, blue: 1, alpha: 1).cgColor
        laser.shadowColor = laser.backgroundColor
        laser.shadowRadius = 30
        laser.shadowOpacity = 1
        laser.shadowOffset = .zero
        parent.addSublayer(laser)
        let sweep = CABasicAnimation(keyPath: "position.y")
        sweep.fromValue = 0
        sweep.toValue = size.height
        sweep.duration = scanEnd / 2
        sweep.autoreverses = true
        sweep.beginTime = AVCoreAnimationBeginTimeAtZero
        sweep.isRemovedOnCompletion = false
        sweep.fillMode = .forwards
        laser.add(sweep, forKey: "sweep")
        hide(laser, at: scanEnd)

        // Logo + pseudo (permanent)
        let logo = textLayer("AuraMaxxing", font: .systemFont(ofSize: 52, weight: .black), color: .white, maxWidth: size.width - 120)
        logo.frame.origin = CGPoint(x: 60, y: 90)
        parent.addSublayer(logo)
        let handle = textLayer("@\(content.pseudo) · \(content.leagueLine)", font: .systemFont(ofSize: 36, weight: .semibold),
                               color: UIColor.white.withAlphaComponent(0.85), maxWidth: size.width - 120)
        handle.frame.origin = CGPoint(x: 60, y: logo.frame.maxY + 8)
        parent.addSublayer(handle)

        // Score qui défile : une couche par palier, masquée sur un dégradé aux couleurs de l'aura.
        let scoreFont = UIFont.systemFont(ofSize: 300, weight: .black)
        let steps = 24
        let scoreTop = size.height * 0.50
        for i in 0..<steps {
            let p = Double(i + 1) / Double(steps)
            let value = Int((Double(a.auraScore) * (1 - pow(1 - p, 3))).rounded())
            let layer = gradientText("\(value)", font: scoreFont, colors: [c1, .white, c2], centerX: size.width / 2, top: scoreTop)
            parent.addSublayer(layer)
            let from = scanEnd + (countEnd - scanEnd) * Double(i) / Double(steps)
            let to = i == steps - 1 ? duration + 1 : scanEnd + (countEnd - scanEnd) * Double(i + 1) / Double(steps)
            visible(layer, from: from, to: to, total: duration)
        }
        let unit = textLayer("POINTS D'AURA", font: .systemFont(ofSize: 40, weight: .heavy), color: UIColor.white.withAlphaComponent(0.8), maxWidth: size.width)
        unit.frame.origin = CGPoint(x: (size.width - unit.frame.width) / 2, y: scoreTop + scoreFont.lineHeight - 20)
        parent.addSublayer(unit)
        show(unit, at: scanEnd, fade: 0.3)

        // Tier qui « tombe »
        let tier = badge("\(a.emoji) \(a.tier.uppercased())", colors: [c1, c2])
        tier.position = CGPoint(x: size.width / 2, y: unit.frame.maxY + 90)
        parent.addSublayer(tier)
        show(tier, at: tierAt, fade: 0.05)
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0.2, 1.18, 1.0]
        pop.keyTimes = [0, 0.6, 1]
        pop.duration = 0.45
        pop.beginTime = AVCoreAnimationBeginTimeAtZero + tierAt
        pop.isRemovedOnCompletion = false
        pop.fillMode = .both
        tier.add(pop, forKey: "pop")

        // Titre
        let title = textLayer("« \(a.title) »", font: .italicSystemFont(ofSize: 46), color: .white, maxWidth: size.width - 140, centered: true)
        title.frame.origin = CGPoint(x: (size.width - title.frame.width) / 2, y: tier.frame.maxY + 40)
        parent.addSublayer(title)
        show(title, at: titleAt, fade: 0.4)

        // Roast (ou résultat du défi) en bas
        let bottomText = content.challengeLine ?? "💀 \(a.roast)"
        let roast = textLayer(bottomText, font: .systemFont(ofSize: 42, weight: .bold), color: .white, maxWidth: size.width - 140, centered: true)
        roast.frame.origin = CGPoint(x: (size.width - roast.frame.width) / 2, y: size.height - 330 - roast.frame.height)
        parent.addSublayer(roast)
        show(roast, at: roastAt, fade: 0.35)

        // Appel à l'action permanent
        let cta = textLayer("T'as combien d'aura ? \(content.hashtag)", font: .systemFont(ofSize: 38, weight: .heavy),
                            color: UIColor.white.withAlphaComponent(0.9), maxWidth: size.width - 120, centered: true)
        cta.frame.origin = CGPoint(x: (size.width - cta.frame.width) / 2, y: size.height - 210)
        parent.addSublayer(cta)

        return (parent, videoLayer)
    }

    // MARK: - Animations

    private static func show(_ layer: CALayer, at time: Double, fade: Double) {
        layer.opacity = 0
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 0
        a.toValue = 1
        a.duration = max(0.01, fade)
        a.beginTime = AVCoreAnimationBeginTimeAtZero + time
        a.isRemovedOnCompletion = false
        a.fillMode = .forwards
        layer.add(a, forKey: "show")
    }

    private static func hide(_ layer: CALayer, at time: Double) {
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 1
        a.toValue = 0
        a.duration = 0.2
        a.beginTime = AVCoreAnimationBeginTimeAtZero + time
        a.isRemovedOnCompletion = false
        a.fillMode = .forwards
        layer.add(a, forKey: "hide")
    }

    /// Visible uniquement entre `from` et `to` (paliers du compteur).
    private static func visible(_ layer: CALayer, from: Double, to: Double, total: Double) {
        layer.opacity = 0
        let end = max(total, to)
        let a = CAKeyframeAnimation(keyPath: "opacity")
        a.values = [0, 0, 1, 1, 0, 0]
        a.keyTimes = [0, from / end, from / end, min(to, end) / end, min(to, end) / end, 1].map { NSNumber(value: $0) }
        a.duration = end
        a.beginTime = AVCoreAnimationBeginTimeAtZero
        a.isRemovedOnCompletion = false
        a.fillMode = .both
        layer.add(a, forKey: "step")
    }

    // MARK: - Couches de texte (rendues en image : nettes et compatibles emoji)

    private static func textImage(_ text: String, font: UIFont, color: UIColor, maxWidth: CGFloat, centered: Bool) -> UIImage {
        let style = NSMutableParagraphStyle()
        style.alignment = centered ? .center : .left
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil
        ).integral
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: bounds.size, format: format).image { _ in
            (text as NSString).draw(with: CGRect(origin: .zero, size: bounds.size),
                                    options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        }
    }

    private static func textLayer(_ text: String, font: UIFont, color: UIColor, maxWidth: CGFloat, centered: Bool = false) -> CALayer {
        let image = textImage(text, font: font, color: color, maxWidth: maxWidth, centered: centered)
        let layer = CALayer()
        layer.contents = image.cgImage
        layer.frame = CGRect(origin: .zero, size: image.size)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.6
        layer.shadowRadius = 8
        layer.shadowOffset = .zero
        return layer
    }

    /// Texte rempli d'un dégradé (le texte sert de masque).
    private static func gradientText(_ text: String, font: UIFont, colors: [UIColor], centerX: CGFloat, top: CGFloat) -> CALayer {
        let image = textImage(text, font: font, color: .white, maxWidth: 2000, centered: true)
        let gradient = CAGradientLayer()
        gradient.frame = CGRect(x: centerX - image.size.width / 2, y: top, width: image.size.width, height: image.size.height)
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        let mask = CALayer()
        mask.frame = gradient.bounds
        mask.contents = image.cgImage
        gradient.mask = mask
        return gradient
    }

    private static func badge(_ text: String, colors: [UIColor]) -> CALayer {
        let label = textImage(text, font: .systemFont(ofSize: 48, weight: .black), color: UIColor(white: 0.04, alpha: 1), maxWidth: 900, centered: true)
        let pill = CAGradientLayer()
        pill.bounds = CGRect(x: 0, y: 0, width: label.size.width + 80, height: label.size.height + 36)
        pill.cornerRadius = pill.bounds.height / 2
        pill.colors = colors.map(\.cgColor)
        pill.startPoint = CGPoint(x: 0, y: 0.5)
        pill.endPoint = CGPoint(x: 1, y: 0.5)
        let text = CALayer()
        text.contents = label.cgImage
        text.frame = CGRect(x: 40, y: 18, width: label.size.width, height: label.size.height)
        pill.addSublayer(text)
        return pill
    }
}

extension UIColor {
    /// "#RRGGBB" → UIColor (violet par défaut si invalide).
    convenience init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        guard clean.count == 6, Scanner(string: clean).scanHexInt64(&value) else {
            self.init(red: 0.706, green: 0.42, blue: 1, alpha: 1)
            return
        }
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}
