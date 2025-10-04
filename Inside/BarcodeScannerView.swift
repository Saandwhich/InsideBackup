import SwiftUI
import AVFoundation

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
                    DispatchQueue.main.async { self.onProductFetched?(productString) }
                } else {
                    DispatchQueue.main.async { self.onProductFetched?("No product found for barcode \(barcode)") }
                }
            } catch {
                DispatchQueue.main.async { self.onProductFetched?("Error parsing product: \(error.localizedDescription)") }
            }
        }.resume()
    }
}
