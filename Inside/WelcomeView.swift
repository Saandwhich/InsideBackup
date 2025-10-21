import SwiftUI
import AVKit

struct WelcomeView: View {
    var onStart: () -> Void

    // tweak this if you want the video slightly larger/smaller
    private var videoHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        // Use ~42% of screen height, clamped so it looks good on small and large phones
        return min(max(screenHeight * 0.65, 280), 520)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top title section
                VStack(spacing: 8) {
                    Text("Inside")
                        .font(.system(size: 40, weight: .bold))
                        .tracking(-0.8)
                        .foregroundColor(Color("PrimaryGreen"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .top)

                // Flexible space to help center the video on taller screens
                Spacer(minLength: 12)

                // Centered video with dynamic height
                LoopingVideoView(videoName: "Demo", videoType: "mp4")
                    .frame(height: videoHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // Flexible space below video
                Spacer(minLength: 12)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Text("Know Whats Inside Your Food")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-0.8)
                    .foregroundColor(Color("PrimaryGreen"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)

                Button(action: { onStart() }) {
                    Text("Get Started")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                        .tracking(-0.36)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 16)
                        .background(Color("PrimaryGreen"))
                        .cornerRadius(28)
                }
                .padding(.top, 4)
                .padding(.horizontal, 24)

                HStack(spacing: 4) {
                    Link(destination: URL(string: "https://insideapp.framer.ai/privacy-policy")!) {
                        Text("Privacy Policy")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(-0.24)
                            .foregroundColor(Color("PrimaryGreen"))
                    }
                    Text("and")
                        .font(.system(size: 16))
                        .tracking(-0.24)
                        .foregroundColor(.gray)
                    Link(destination: URL(string: "https://insideapp.framer.ai/terms-of-use-and-disclaimer")!) {
                        Text("Terms of Use")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(-0.24)
                            .foregroundColor(Color("PrimaryGreen"))
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground).opacity(0.95))
        }
    }
}


// MARK: - Looping Video UIViewRepresentable + UIView implementation

struct LoopingVideoView: UIViewRepresentable {
    let videoName: String
    let videoType: String

    func makeUIView(context: Context) -> UIView {
        return LoopingPlayerUIView(videoName: videoName, videoType: videoType)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // nothing to update for now
    }
}

final class LoopingPlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    init(videoName: String, videoType: String) {
        super.init(frame: .zero)
        backgroundColor = .clear
        setupPlayer(videoName: videoName, videoType: videoType)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setupPlayer(videoName: String, videoType: String) {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoType) else {
            print("⚠️ LoopingPlayerUIView: video not found: \(videoName).\(videoType)")
            return
        }

        // Use AVQueuePlayer + AVPlayerLooper for smooth looping
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        self.queuePlayer = queue
        self.playerLooper = AVPlayerLooper(player: queue, templateItem: item)

        let layer = AVPlayerLayer(player: queue)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        self.playerLayer = layer

        queue.isMuted = true
        queue.play()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // make the player layer exactly match this view's bounds
        playerLayer?.frame = bounds
    }

    deinit {
        queuePlayer?.pause()
        playerLooper = nil
        queuePlayer = nil
    }
}
