import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Parcours complet : choisir / filmer une vidéo → aperçu → analyse IA → résultat.
struct UploadFlowView: View {

    /// Défi relevé (lien reçu d'un pote), sinon nil.
    var challenge: ChallengeInfo? = nil

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    private enum Stage {
        case pick
        case preview(URL)
        case analyzing([UIImage])
        case result(UploadResult, [UIImage], URL)
    }

    @State private var stage: Stage = .pick
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var caption = ""
    @State private var showCover = false
    @State private var error: String?
    @State private var loadingVideo = false

    var body: some View {
        ZStack {
            switch stage {
            case .pick:
                pickView
            case .preview(let url):
                previewView(url)
            case .analyzing(let frames):
                AnalyzingView(frames: frames)
            case .result(let result, let frames, let url):
                ResultView(
                    result: result,
                    frames: frames,
                    sourceURL: url,
                    pseudo: session.profile?.user.pseudo ?? "",
                    leagueLine: session.profile.map { "\($0.league.emoji) \($0.league.name)" } ?? "",
                    hashtag: session.profile?.today.hashtag ?? "#AuraDuJour"
                ) {
                    if challenge != nil { session.pendingChallenge = nil }
                    Task { await session.refresh() }
                    dismiss()
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: stageKey)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPicked(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraRecorder { url in
                showCamera = false
                if let url { stage = .preview(url) }
            }
            .ignoresSafeArea()
        }
    }

    private var stageKey: Int {
        switch stage {
        case .pick: 0
        case .preview: 1
        case .analyzing: 2
        case .result: 3
        }
    }

    // MARK: - Étape 1 : choisir

    private var pickView: some View {
        ZStack {
            AuraBackground()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).padding(10).background(Color.auraCard, in: Circle())
                    }
                }
                Spacer()
                Text(challenge == nil ? "Montre ton aura" : "Relève le défi")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                if let challenge {
                    HStack(spacing: 12) {
                        Text("⚔️").font(.largeTitle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(challenge.from?.pseudo ?? "?") a fait \(challenge.score)").font(.headline)
                            Text("Fais plus pour le battre. Ta vidéo compte aussi pour ta ligue.")
                                .font(.subheadline).foregroundStyle(Color.auraMuted)
                        }
                    }
                    .auraCard()
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(hex: challenge.auraColor).opacity(0.6)))
                }
                if let today = session.profile?.today {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("⚡ THÈME DU JOUR · +25 %").font(.caption.weight(.heavy)).foregroundStyle(Color.auraGold)
                        Text(today.theme).font(.title2.weight(.bold))
                        Text(today.hint).foregroundStyle(Color.auraMuted)
                    }
                    .auraCard()
                }
                Label("Vidéo de 2 à 60 secondes, en vertical c'est mieux", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(Color.auraMuted)
                if let error {
                    Text(error).font(.subheadline).foregroundStyle(Color.auraRed)
                }
                Spacer()
                Button {
                    Haptics.tap()
                    showCamera = true
                } label: {
                    Label("Filmer maintenant", systemImage: "video.fill")
                }
                .buttonStyle(GlowButtonStyle())

                PhotosPicker(selection: $pickerItem, matching: .videos, preferredItemEncoding: .current) {
                    if loadingVideo {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Label("Choisir dans ma galerie", systemImage: "photo.on.rectangle")
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(24)
        }
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        loadingVideo = true
        error = nil
        defer { loadingVideo = false; pickerItem = nil }
        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                error = "Impossible d'importer cette vidéo."
                return
            }
            Analytics.track(.videoPicked, ["source": "library"])
            stage = .preview(movie.url)
        } catch {
            self.error = "Impossible d'importer cette vidéo."
        }
    }

    // MARK: - Étape 2 : aperçu

    private func previewView(_ url: URL) -> some View {
        VStack(spacing: 16) {
            HStack {
                Button("Changer") { stage = .pick }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }
            .font(.headline)

            LoopingPlayer(url: url)
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(LinearGradient.auraBrand, lineWidth: 2))

            TextField("Légende (optionnel) — ex. fit du jour", text: $caption)
                .padding(14)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

            Toggle("Afficher ma miniature dans le classement", isOn: $showCover)
                .font(.subheadline)
                .toggleStyle(SwitchToggleStyle(tint: .auraPurple))

            if let error {
                Text(error).font(.subheadline).foregroundStyle(Color.auraRed)
            }
            Spacer(minLength: 0)
            Button("🔮 Lancer l'analyse") {
                Task { await analyze(url) }
            }
            .buttonStyle(GlowButtonStyle())
        }
        .padding(20)
        .background(Color.auraBackground.ignoresSafeArea())
    }

    // MARK: - Étape 3 : analyse

    private func analyze(_ url: URL) async {
        error = nil
        Haptics.thud()
        do {
            let extracted = try await FrameExtractor.extract(from: url)
            stage = .analyzing(extracted.frames)

            let frames = extracted.frames.compactMap { $0.jpegDataURL() }
            let middle = extracted.frames[extracted.frames.count / 2]
            let body = VideoBody(
                frames: frames,
                timestamps: extracted.timestamps,
                duration: extracted.duration,
                caption: caption,
                coverConsent: showCover,
                cover: showCover ? middle.squareThumbnail().jpegDataURL(quality: 0.6) : nil,
                challengeCode: challenge?.code
            )
            let result: UploadResult = try await APIClient.shared.post("videos", body)
            Analytics.track(.videoAnalyzed, ["score": result.analysis.auraScore, "points": result.video.points])
            Haptics.success()
            stage = .result(result, extracted.frames, url)
        } catch {
            Analytics.track(.analysisFailed)
            Haptics.error()
            self.error = error.localizedDescription
            stage = .preview(url)
        }
    }
}

// MARK: - Import depuis la galerie

/// Copie la vidéo choisie dans un fichier temporaire lisible par AVFoundation.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

// MARK: - Lecteur en boucle

struct LoopingPlayer: View {
    let url: URL
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                let queue = AVQueuePlayer()
                looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
                queue.isMuted = true
                queue.play()
                player = queue
            }
            .onDisappear { player?.pause() }
    }
}

// MARK: - Caméra

/// Caméra système en mode vidéo (selfie par défaut, 60 s max).
struct CameraRecorder: UIViewControllerRepresentable {
    let onFinish: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoMaximumDuration = FrameExtractor.maxDuration
        picker.videoQuality = .typeHigh
        if picker.sourceType == .camera, UIImagePickerController.isCameraDeviceAvailable(.front) {
            picker.cameraDevice = .front
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (URL?) -> Void
        init(onFinish: @escaping (URL?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            Analytics.track(.videoPicked, ["source": "camera"])
            onFinish(info[.mediaURL] as? URL)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
