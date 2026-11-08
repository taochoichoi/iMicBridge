import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import Combine

@MainActor
final class AudioBridgeModel: ObservableObject {
    @Published private(set) var injectionAvailable = false
    @Published private(set) var permissionText = "Chưa kiểm tra quyền"
    @Published var injectionEnabled = false
    @Published private(set) var selectedFileName: String?
    @Published private(set) var isPlaying = false
    @Published var volume: Double = 1.0

    private var player: AVAudioPlayer?

    func refreshStatus() {
        injectionAvailable = AVAudioSession.sharedInstance().isMicrophoneInjectionAvailable
        switch AVAudioApplication.shared.microphoneInjectionPermission {
        case .granted:
            permissionText = "Đã cấp quyền thêm âm thanh vào cuộc gọi"
        case .denied:
            permissionText = "Quyền đã bị từ chối. Có thể đổi trong Cài đặt iOS."
        case .undetermined:
            permissionText = "Chưa yêu cầu quyền"
        case .serviceDisabled:
            permissionText = "Dịch vụ đang tắt. Bật ‘Thêm âm thanh vào cuộc gọi’ trong Trợ năng."
        @unknown default:
            permissionText = "Trạng thái quyền không xác định"
        }
    }

    func requestPermission() async {
        let result = await AVAudioApplication.requestMicrophoneInjectionPermission()
        switch result {
        case .granted:
            permissionText = "Đã cấp quyền thêm âm thanh vào cuộc gọi"
        case .denied:
            permissionText = "Quyền đã bị từ chối. Có thể đổi trong Cài đặt iOS."
        case .undetermined:
            permissionText = "Chưa có kết quả cấp quyền"
        case .serviceDisabled:
            permissionText = "Hãy bật ‘Thêm âm thanh vào cuộc gọi’ trong Trợ năng."
        @unknown default:
            permissionText = "Trạng thái quyền không xác định"
        }
        refreshStatus()
    }

    func setInjectionEnabled(_ enabled: Bool) {
        guard enabled else {
            do {
                try AVAudioSession.sharedInstance().setPreferredMicrophoneInjectionMode(.none)
                injectionEnabled = false
            } catch {
                permissionText = "Không thể tắt injection: \(error.localizedDescription)"
            }
            return
        }

        guard AVAudioApplication.shared.microphoneInjectionPermission == .granted else {
            permissionText = "Cần cấp quyền Microphone Injection trước."
            injectionEnabled = false
            return
        }
        guard AVAudioSession.sharedInstance().isMicrophoneInjectionAvailable else {
            permissionText = "Chưa có cuộc gọi/ứng dụng tương thích đang hoạt động."
            injectionEnabled = false
            refreshStatus()
            return
        }

        do {
            try AVAudioSession.sharedInstance().setPreferredMicrophoneInjectionMode(.spokenAudio)
            injectionEnabled = true
        } catch {
            permissionText = "Không bật được injection: \(error.localizedDescription)"
            injectionEnabled = false
        }
    }

    func importAudio(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(url.pathExtension)
            try FileManager.default.copyItem(at: url, to: destination)
            player = try AVAudioPlayer(contentsOf: destination)
            player?.prepareToPlay()
            player?.volume = Float(volume)
            selectedFileName = url.lastPathComponent
            isPlaying = false
        } catch {
            permissionText = "Không mở được tệp âm thanh: \(error.localizedDescription)"
        }
    }

    func play() {
        guard let player else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            player.volume = Float(volume)
            isPlaying = player.play()
            if !isPlaying {
                permissionText = "Không phát được tệp âm thanh này."
            }
        } catch {
            permissionText = "Lỗi phát âm thanh: \(error.localizedDescription)"
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
    }

    func updateVolume(_ value: Double) {
        volume = value
        player?.volume = Float(value)
    }
}

struct ContentView: View {
    @StateObject private var model = AudioBridgeModel()
    @State private var showingImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Microphone Injection") {
                    HStack {
                        Text("Khả dụng trong cuộc gọi")
                        Spacer()
                        Text(model.injectionAvailable ? "Có" : "Chưa")
                            .foregroundStyle(model.injectionAvailable ? .green : .secondary)
                    }
                    Text(model.permissionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Yêu cầu quyền") {
                        Task { await model.requestPermission() }
                    }
                    Toggle("Thêm âm thanh vào cuộc gọi", isOn: Binding(
                        get: { model.injectionEnabled },
                        set: { model.setInjectionEnabled($0) }
                    ))
                }

                Section("Phát tệp âm thanh") {
                    Button("Chọn tệp trong Files…") {
                        showingImporter = true
                    }
                    if let name = model.selectedFileName {
                        Text(name).font(.footnote).lineLimit(2)
                        VStack(alignment: .leading) {
                            Text("Âm lượng: \(Int(model.volume * 100))%")
                                .font(.caption)
                            Slider(value: Binding(
                                get: { model.volume },
                                set: { model.updateVolume($0) }
                            ), in: 0...1)
                        }
                        HStack {
                            Button("Phát", systemImage: "play.fill") { model.play() }
                                .disabled(model.isPlaying)
                            Button("Tạm dừng", systemImage: "pause.fill") { model.pause() }
                            Button("Dừng", systemImage: "stop.fill") { model.stop() }
                        }
                    } else {
                        Text("Chưa chọn tệp âm thanh")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Giới hạn của iOS") {
                    Text("Ứng dụng phát các tệp âm thanh mà bạn tự chọn. iOS không cho ứng dụng thông thường thu trực tiếp âm thanh đang phát từ YouTube, TikTok, Spotify hay mọi ứng dụng khác.")
                    Text("Microphone Injection chỉ dùng được khi iOS phát hiện phiên gọi tương thích và người dùng đã bật dịch vụ trong Cài đặt > Trợ năng > Âm thanh & Hình ảnh > Thêm âm thanh vào cuộc gọi. Không đảm bảo tương thích với mọi ứng dụng chat hoặc LiveContainer.")
                }
                .font(.footnote)
            }
            .navigationTitle("iMic Bridge")
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { model.importAudio(from: url) }
                case .failure(let error):
                    // Keep the app open and show the import error in the status area.
                    print("File import failed: \(error.localizedDescription)")
                }
            }
            .onAppear { model.refreshStatus() }
        }
    }
}
