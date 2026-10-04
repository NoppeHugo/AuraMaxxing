import AVFoundation
import UIKit

/// Extrait des images clés d'une vidéo sur l'iPhone.
/// Seules ces images (≈ 8 JPEG légers) partent vers le serveur, jamais la vidéo complète :
/// upload rapide, coût IA maîtrisé, et rien de lourd à stocker.
enum FrameExtractor {

    struct Result {
        let frames: [UIImage]
        let timestamps: [Double]
        let duration: Double
    }

    enum ExtractionError: LocalizedError {
        case tooLong(Double), tooShort, unreadable

        var errorDescription: String? {
            switch self {
            case .tooLong(let max): return "Ta vidéo doit faire moins de \(Int(max)) secondes."
            case .tooShort: return "Ta vidéo est trop courte (2 secondes minimum)."
            case .unreadable: return "Impossible de lire cette vidéo."
            }
        }
    }

    static let maxDuration: Double = 60
    static let frameCount = 8

    static func extract(from url: URL, count: Int = frameCount, maxSide: CGFloat = 768) async throws -> Result {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite else { throw ExtractionError.unreadable }
        guard duration >= 2 else { throw ExtractionError.tooShort }
        guard duration <= maxDuration else { throw ExtractionError.tooLong(maxDuration) }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true // respecte l'orientation portrait
        generator.maximumSize = CGSize(width: maxSide, height: maxSide)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)

        // Répartition régulière entre 5 % et 95 % de la vidéo.
        let times = (0..<count).map { i in
            duration * (0.05 + 0.9 * Double(i) / Double(max(1, count - 1)))
        }

        var frames: [UIImage] = []
        var stamps: [Double] = []
        for t in times {
            guard let frame = try? await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)) else { continue }
            frames.append(UIImage(cgImage: frame.image))
            stamps.append(frame.actualTime.seconds)
        }
        guard frames.count >= 3 else { throw ExtractionError.unreadable }
        return Result(frames: frames, timestamps: stamps, duration: duration)
    }
}

extension UIImage {
    /// "data:image/jpeg;base64,…" pour l'API.
    func jpegDataURL(quality: CGFloat = 0.7) -> String? {
        jpegData(compressionQuality: quality).map { "data:image/jpeg;base64," + $0.base64EncodedString() }
    }

    /// Miniature carrée (pour le classement, si la personne l'accepte).
    func squareThumbnail(side: CGFloat = 128) -> UIImage {
        let edge = min(size.width, size.height)
        let crop = CGRect(x: (size.width - edge) / 2, y: (size.height - edge) / 2, width: edge, height: edge)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let scale = side / edge
            draw(in: CGRect(x: -crop.minX * scale, y: -crop.minY * scale, width: size.width * scale, height: size.height * scale))
        }
    }
}
