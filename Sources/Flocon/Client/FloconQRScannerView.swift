#if os(iOS)
import AVFoundation
import SwiftUI

/// A camera view that scans the QR code shown by Flocon Desktop and connects the app to it.
///
/// When a code is read, ``Flocon/connect(address:)`` is called and its result is given to `onResult`.
/// The scan resumes after a failure so the user can try again, and stops once connected.
///
/// The app must declare `NSCameraUsageDescription` in its `Info.plist`. The view asks for the permission
/// the first time it is shown, and shows a message instead of the camera if it is denied or if the device
/// has no camera, such as the simulator.
///
/// ```swift
/// .sheet(isPresented: $isScanning) {
///     FloconQRScannerView { result in
///         if result == .connected { isScanning = false }
///     }
/// }
/// ```
public struct FloconQRScannerView: View {
    private enum Access {
        case checking, ready, denied, unavailable
    }

    private let onResult: @MainActor (FloconConnectResult) -> Void
    @State private var access = Access.checking

    /// - Parameter onResult: Called on the main actor with the result of each connection attempt.
    public init(onResult: @escaping @MainActor (FloconConnectResult) -> Void) {
        self.onResult = onResult
    }

    public var body: some View {
        Group {
            switch access {
            case .checking:
                Color.black
            case .ready:
                FloconQRScannerRepresentable(onResult: onResult)
            case .denied:
                message("Camera access is denied. Allow it in the Settings to scan the QR code.")
            case .unavailable:
                message("No camera is available on this device.")
            }
        }
        .task { access = await Self.requestAccess() }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static func requestAccess() async -> Access {
        guard AVCaptureDevice.default(for: .video) != nil else { return .unavailable }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .ready
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video) ? .ready : .denied
        default: return .denied
        }
    }
}

private struct FloconQRScannerRepresentable: UIViewControllerRepresentable {
    let onResult: @MainActor (FloconConnectResult) -> Void

    func makeUIViewController(context: Context) -> FloconQRScannerController {
        let controller = FloconQRScannerController()
        controller.onCode = { [weak controller, onResult] code in
            Task { @MainActor in
                let result = await Flocon.connect(address: code)
                onResult(result)
                if result != .connected {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    controller?.resume()
                }
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: FloconQRScannerController, context: Context) {}
}

/// Holds the capture session, which is started and stopped off the main thread.
private final class FloconCaptureSession: @unchecked Sendable {
    let session = AVCaptureSession()
}

private final class FloconQRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: (@MainActor (String) -> Void)?

    private let capture = FloconCaptureSession()
    private let queue = DispatchQueue(label: "io.github.openflocon.flocon.qr-scanner")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isPaused = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let session = capture.session
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let capture = capture
        queue.async { capture.session.startRunning() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let capture = capture
        queue.async { capture.session.stopRunning() }
    }

    /// Listens to the camera again after a code that could not be used.
    func resume() {
        isPaused = false
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // The delegate queue is the main queue.
        MainActor.assumeIsolated {
            guard !isPaused,
                  let code = metadataObjects.lazy.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first
            else { return }
            isPaused = true
            onCode?(code)
        }
    }
}
#endif
