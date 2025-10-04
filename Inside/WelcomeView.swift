import SwiftUI
import AVKit

struct WelcomeView: View {
    var onStart: () -> Void

    // tweak this if you want the video slightly larger/smaller
    private let videoHeight: CGFloat = 500

    var body: some View {
        VStack(spacing: 0) {
            
            // Top video — pinned at top, fixed height, won't be overlapped
            LoopingVideoView(videoName: "Demo", videoType: "mp4")
                .frame(height: videoHeight)
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top, 75)

            Spacer() // pushes the content below the video

            // Text block and button — sits at the bottom area
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Know What’s                  Inside Your Food                With Just A Picture")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(Color("PrimaryGreen"))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Inside helps empower people with dietary restrictions, to eat with confidence by using AI to analyze meals for allergens, additives, and dietary preferences.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)

                Button(action: {
                    onStart()
                }) {
                    Text("Get Started")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("PrimaryGreen"))
                        .cornerRadius(28)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 32)
        }
        .edgesIgnoringSafeArea(.top) // video can extend into the top safe area if needed
        .background(Color(.systemBackground)) // ensure the rest of the screen uses the system background
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
