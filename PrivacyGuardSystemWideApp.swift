import SwiftUI
import AVFoundation
import Vision

@main
struct PrivacyGuardSystemWideApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var shieldManager = SystemWideShieldManager()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("PrivacyGuard System-Wide")
                .font(.largeTitle.bold())
            
            Text(shieldManager.isActive ? "🟢 Active — Monitoring" : "🔴 Inactive")
                .font(.title2)
                .foregroundColor(shieldManager.isActive ? .green : .red)
            
            Button(action: {
                if shieldManager.isActive {
                    shieldManager.stop()
                } else {
                    shieldManager.start()
                }
            }) {
                Text(shieldManager.isActive ? "Stop Shield" : "Start Shield")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(shieldManager.isActive ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            
            Text("Real-time face detection using Vision framework")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .onAppear {
            shieldManager.requestCameraPermission()
        }
    }
}

class SystemWideShieldManager: ObservableObject {
    @Published var isActive = false
    private var captureSession: AVCaptureSession?
    private var overlayWindow: UIWindow?
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                print("Camera permission granted")
            } else {
                print("Camera permission denied")
            }
        }
    }
    
    func start() {
        isActive = true
        
        // Setup camera
        setupCamera()
        
        // Create full-screen overlay
        createOverlay()
        
        print("iOS System-Wide Shield started")
    }
    
    func stop() {
        isActive = false
        captureSession?.stopRunning()
        overlayWindow?.isHidden = true
        overlayWindow = nil
        
        print("iOS System-Wide Shield stopped")
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }
        
        session.sessionPreset = .medium
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        session.addOutput(output)
        
        // Vision ML face detection
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        session.startRunning()
    }
    
    private func createOverlay() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow?.windowLevel = .alert + 1
        overlayWindow?.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        overlayWindow?.isHidden = true
        
        // Make it click-through when inactive
        overlayWindow?.isUserInteractionEnabled = false
    }
    
    func activateShield() {
        overlayWindow?.isHidden = false
        print("🛡️ iOS System-wide shield ACTIVATED")
    }
    
    func deactivateShield() {
        overlayWindow?.isHidden = true
        print("✅ iOS System-wide shield DEACTIVATED")
    }
}

extension SystemWideShieldManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let results = request.results as? [VNFaceObservation] {
                if results.count >= 2 {
                    DispatchQueue.main.async {
                        self.activateShield()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.deactivateShield()
                    }
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
}