import AetherEngine
import AVKit
import SwiftUI

/// The one AetherEngine for the app's lifetime (the engine is built to be reused), and the
/// request the open player is showing. Opening something while the player is up swaps the
/// stream in place, so there's never a second session holding a provider connection.
@MainActor
final class PlayerSession: ObservableObject {
    static let shared = PlayerSession()

    let engine: AetherEngine?
    let initError: String?
    /// What's playing; a new request (another channel, a reminder's Watch) reloads the player.
    @Published var request: PlaybackRequest?
    /// Set at launch, for channel switching and playback preferences.
    weak var settings: AppSettings?

    private init() {
        do {
            let engine = try AetherEngine()
            // Tellio plays no sound of its own, so the engine releases the audio session when
            // playback stops. The player activates it before each load (no AVPlayerViewController
            // to do it on the native route).
            engine.deactivatesAudioSessionOnStop = true
            // Lock screen and Control Centre: title, play/pause and skip.
            engine.ownsVideoNowPlayingSession = true
            engine.ownsVideoNowPlayingCommands = true
            engine.ownsSoftwareNowPlaying = true
            engine.ownsAudioNowPlaying = true
            self.engine = engine
            self.initError = nil
        } catch {
            self.engine = nil
            self.initError = error.localizedDescription
        }
    }
}

/// Full screen, no status bar, home indicator tucked away while the controls are hidden.
final class PlayerHostingController: UIHostingController<AnyView> {
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
}

/// Picture in picture for whichever route the engine picked: the player layer on the native
/// route, the engine's sample-buffer source on the software route.
@MainActor
final class PictureInPicture: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    @Published private(set) var isPossible = false
    @Published private(set) var isActive = false
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private weak var engine: AetherEngine?
    private var restoring = false
    /// Called when the window is closed (not returned to full screen).
    var onClosed: (() -> Void)?

    func rebuild(for engine: AetherEngine) {
        self.engine = engine
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let new: AVPictureInPictureController?
        if let layer = engine.nativePlayerLayer {
            new = controller?.playerLayer === layer ? controller : AVPictureInPictureController(playerLayer: layer)
        } else {
            new = engine.softwarePiPSource?.makePictureInPictureController()
        }
        guard new !== controller else { return }
        controller = new
        controller?.delegate = self
        // Going to the Home Screen while playing carries on in a small window.
        controller?.canStartPictureInPictureAutomaticallyFromInline = true
        possibleObservation = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] c, _ in
            let possible = c.isPictureInPicturePossible
            DispatchQueue.main.async { self?.isPossible = possible }
        }
        if controller == nil { isPossible = false }
    }

    func toggle() {
        guard let controller else { return }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else {
            controller.startPictureInPicture()
        }
    }

    func tearDown() {
        controller?.stopPictureInPicture()
        possibleObservation = nil
        controller = nil
        isPossible = false
    }

    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ c: AVPictureInPictureController) {
        MainActor.assumeIsolated {
            restoring = false
            isActive = true
            engine?.pictureInPictureActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
        MainActor.assumeIsolated {
            isActive = false
            engine?.pictureInPictureActive = false
            if !restoring { onClosed?() }
            restoring = false
        }
    }

    nonisolated func pictureInPictureController(
        _ c: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completion: @escaping (Bool) -> Void
    ) {
        // The player screen stays up underneath, so going back is just closing the window.
        MainActor.assumeIsolated { restoring = true }
        completion(true)
    }
}

/// The AirPlay button.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .white
        view.activeTintColor = .white
        view.prioritizesVideoDevices = true
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

/// The engine's subtitle cues (text and pictures such as PGS) drawn over the video.
struct SubtitleOverlay: View {
    let cues: [SubtitleCue]
    let time: Double
    var fontSize: CGFloat = 20

    var body: some View {
        let active = cues.filter { $0.startTime <= time && time < $0.endTime }
        let text = active.compactMap(\.text).joined(separator: "\n")

        GeometryReader { geo in
            ZStack {
                ForEach(active) { cue in
                    if case .image(let image) = cue.body {
                        // Position is [0, 1] against the video frame.
                        Image(decorative: image.cgImage, scale: 1)
                            .resizable()
                            .frame(width: image.position.width * geo.size.width,
                                   height: image.position.height * geo.size.height)
                            .position(x: image.position.midX * geo.size.width,
                                      y: image.position.midY * geo.size.height)
                    }
                }
                if !text.isEmpty {
                    VStack {
                        Spacer()
                        Text(text)
                            .font(.system(size: fontSize, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 3)
                            .shadow(color: .black, radius: 1)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 28)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
