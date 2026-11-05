import SwiftUI
import Flocon

/// Connects the app to Flocon Desktop at an IP address, with `Flocon.connect(address:)`, and closes it with `Flocon.disconnect()`.
///
/// The default address (`localhost`) keeps being tried, this one is added. Ports are optional: `host`, `host:wsPort` or `host:wsPort:httpPort`; an omitted port is the configured one.
struct ConnectionScreen: View {
    @AppStorage("flocon.sample.address") private var address = ""
    @State private var state = Flocon.connectionState
    @State private var result: FloconConnectResult?
    @State private var isConnecting = false
    @State private var isScanning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    SampleCategoryIcon(systemImage: "wifi", category: .neutral, size: 44)
                    Text("Connect to Flocon Desktop by IP")
                        .font(.subheadline)
                        .foregroundStyle(SampleTheme.inkMuted)
                }

                SampleSection(title: "Status") {
                    HStack(spacing: 12) {
                        Circle().fill(state.sampleColor).frame(width: 10, height: 10)
                        Text(state.sampleLabel)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(SampleTheme.ink)
                        Spacer()
                    }
                    .padding(16)
                }

                SampleSection(title: "Flocon Desktop address") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            TextField("192.168.1.20 or 192.168.1.20:10023:10024", text: $address)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.numbersAndPunctuation)
                                .submitLabel(.go)
                                .onSubmit(connect)
                                .padding(14)
                                .background(SampleTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SampleTheme.line))
                            Button(isConnecting ? "…" : "Connect", action: connect)
                                .buttonStyle(SampleButtonStyle())
                                .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                        }
                        Button("Scan QR code", systemImage: "qrcode.viewfinder") { isScanning = true }
                            .buttonStyle(SampleButtonStyle())
                        Button("Disconnect", action: disconnect)
                            .buttonStyle(SampleButtonStyle())
                            .disabled(isConnecting)
                        if let message = result?.sampleMessage {
                            Text(message.text)
                                .font(.footnote)
                                .foregroundStyle(message.isError ? SampleTheme.error : SampleTheme.success)
                        }
                    }
                    .padding(16)
                }

                SampleInfoCard(
                    text: "The SDK keeps trying its default address (localhost on the simulator) and also connects to this one. "
                        + "Add ports with host:wsPort:httpPort (192.168.1.20:10023:10024), otherwise the configured ports (9023 and 9024 by default) are used. "
                        + "The last address that worked is tried again at the next launch.",
                    tint: SampleTheme.accent
                )
            }
            .padding(20)
        }
        .background(SampleTheme.bg)
        .navigationTitle("Remote connection")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            for await newState in Flocon.connectionStates { state = newState }
        }
        .sheet(isPresented: $isScanning) {
            FloconQRScannerView { scanResult in
                result = scanResult
                if scanResult == .connected { isScanning = false }
            }
        }
    }

    private func disconnect() {
        Task {
            await Flocon.disconnect()
            result = nil
        }
    }

    private func connect() {
        let target = address.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, !isConnecting else { return }
        Task {
            isConnecting = true
            result = await Flocon.connect(address: target)
            isConnecting = false
        }
    }
}

/// The button of the home, next to the title: the dot shows the state of the connection.
struct ConnectionChip: View {
    @State private var state = Flocon.connectionState

    var body: some View {
        NavigationLink(value: SampleConnectionRoute.screen) {
            HStack(spacing: 8) {
                Image(systemName: "wifi").font(.caption.weight(.semibold))
                Text("Connect").font(.caption.weight(.semibold))
                Circle().fill(state.sampleColor).frame(width: 8, height: 8)
            }
            .foregroundStyle(SampleTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(SampleTheme.surfaceHigh, in: Capsule())
            .overlay(Capsule().stroke(SampleTheme.line))
        }
        .buttonStyle(.plain)
        .task {
            for await newState in Flocon.connectionStates { state = newState }
        }
    }
}

/// The destination of ``ConnectionChip``.
enum SampleConnectionRoute: Hashable {
    case screen
}

private extension FloconConnectionState {
    var sampleColor: Color {
        switch self {
        case .connected: SampleTheme.success
        case .connecting: SampleTheme.warning
        case .failed: SampleTheme.error
        case .idle, .buffering: SampleTheme.inkFaint
        }
    }

    var sampleLabel: String {
        switch self {
        case .idle: "Flocon is not started"
        case .buffering: "Not connected, messages are kept"
        case .connecting: "Connecting…"
        case .connected: "Connected to Flocon Desktop"
        case .failed(let reason): "Failed: \(reason)"
        }
    }
}

private extension FloconConnectResult {
    var sampleMessage: (text: String, isError: Bool)? {
        switch self {
        case .connected: ("✓ Connected", false)
        case .notStarted: ("✕ Flocon is not started", true)
        case .invalidAddress(let reason), .failed(let reason): ("✕ \(reason)", true)
        }
    }
}
