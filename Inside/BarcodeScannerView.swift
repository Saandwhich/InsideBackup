import SwiftUI
import AVFoundation

// NOTE: API Key setup with Secrets.plist
// Create a local Secrets.plist (do not commit) with a Dictionary key "OPENAI_API_KEY" set to your real key.
// Ensure Secrets.plist is added to the app target (Target Membership) so it is bundled.
// Commit a Secrets.sample.plist (same structure, placeholder value) so others can copy it.
// The app will read OPENAI_API_KEY from Secrets.plist; it will fallback to Info.plist only if Secrets.plist is missing.

struct BarcodeScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    var onScanned: (String) -> Void
    
    @StateObject private var scannerDelegate = BarcodeScannerDelegate()
    
    var body: some View {
        ZStack {
            // Fullscreen camera
            CameraPreview(session: scannerDelegate.session)
                .ignoresSafeArea()
            
            // Overlay with centered scanning box
            ScannerOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            
            // Close button
            VStack {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.4)))
                    }
                    .padding(.leading, 20)
                    .padding(.top, 40)
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            scannerDelegate.onProductFetched = { jsonString in
                onScanned(jsonString)
                presentationMode.wrappedValue.dismiss()
            }
            scannerDelegate.startScanning()
        }
        .onDisappear { scannerDelegate.stopScanning() }
        .interactiveDismissDisabled(true) // ensures full-screen on iPad
    }
}

// MARK: Camera Preview
struct CameraPreview: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}

// MARK: Scanner Overlay
struct ScannerOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let boxSize: CGFloat = min(geometry.size.width * 0.7, 300)
            ZStack {
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .frame(width: boxSize, height: boxSize)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .compositingGroup()
                    .ignoresSafeArea()
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: boxSize, height: boxSize)
            }
        }
    }
}

// MARK: Barcode Scanner Delegate
class BarcodeScannerDelegate: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    private struct APIKey {
        static var openAI: String? {
            // Prefer Secrets.plist bundled with the app (not committed to Git). Fallback to Info.plist if needed.
            if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
               let data = try? Data(contentsOf: url),
               let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let key = dict["OPENAI_API_KEY"] as? String, !key.isEmpty {
                return key
            }
            // Fallback: Info.plist (if configured)
            return Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
        }
    }
    
    let session = AVCaptureSession()
    var onProductFetched: ((String) -> Void)?
    
    override init() { super.init(); setupSession() }
    
    private func setupSession() {
        session.beginConfiguration()
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        if session.canAddInput(videoInput) { session.addInput(videoInput) }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .qr, .code128, .upce, .code39, .code93, .pdf417]
        }
        session.commitConfiguration()
    }
    
    func startScanning() { if !session.isRunning { session.startRunning() } }
    func stopScanning() { if session.isRunning { session.stopRunning() } }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        if let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let code = object.stringValue {
            stopScanning()
            fetchProduct(barcode: code)
        }
    }
    
    private func fetchProduct(barcode: String) {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { self.onProductFetched?("Invalid product URL.") }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            guard let data = data, error == nil else {
                DispatchQueue.main.async { self.onProductFetched?("Error fetching product: \(error?.localizedDescription ?? "Unknown error")") }
                return
            }
            
            do {
                let root = try JSONSerialization.jsonObject(with: data, options: [])
                if let rootDict = root as? [String: Any],
                   let productDict = rootDict["product"] as? [String: Any] {
                    let productData = try JSONSerialization.data(withJSONObject: productDict, options: [.prettyPrinted, .sortedKeys])
                    let productString = String(data: productData, encoding: .utf8) ?? "No product data"

                    // If an OpenAI API key is present, attempt to summarize the product; otherwise return raw JSON.
                    if let apiKey = APIKey.openAI, !apiKey.isEmpty {
                        self.summarizeProduct(json: productString, apiKey: apiKey) { summary in
                            DispatchQueue.main.async {
                                self.onProductFetched?(summary ?? productString)
                            }
                        }
                    } else {
                        DispatchQueue.main.async { self.onProductFetched?(productString) }
                    }
                } else {
                    DispatchQueue.main.async { self.onProductFetched?("No product found for barcode \(barcode)") }
                }
            } catch {
                DispatchQueue.main.async { self.onProductFetched?("Error parsing product: \(error.localizedDescription)") }
            }
        }.resume()
    }
    
    // Summarize the Open Food Facts product JSON using OpenAI if an API key is available.
    private func summarizeProduct(json: String, apiKey: String, completion: @escaping (String?) -> Void) {
        // Construct a simple prompt asking for a brief user-friendly summary.
        let prompt = "Summarize this product for a shopper in 3-5 bullet points: \n\n" + json

        // Build a minimal OpenAI chat completions request. Adjust model as needed.
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(nil); return
        }

        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [[
                "role": "user",
                "content": prompt
            ]],
            "temperature": 0.2
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion(nil); return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data = data else {
                completion(nil); return
            }
            // Parse a minimal subset of the OpenAI response
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = jsonObject["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                completion(content)
            } else {
                completion(nil)
            }
        }.resume()
    }
}

