import SwiftUI
import AVFoundation

/// 遥控拍照（安卓「智玩 → 遥控拍照」）
struct CameraPage: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @StateObject private var cameraManager = CameraManager()
    @State private var showPermissionAlert = false

    var body: some View {
        Group {
            if viewModel.isCameraMode {
                fullScreenCamera
            } else {
                DMapSubPage(title: "遥控拍照") {
                    ScrollView {
                        VStack(spacing: 12) {
                            DMapCard {
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 56))
                                        .foregroundColor(DMapTheme.brandBlue)
                                    Text("遥控拍照")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(DMapTheme.textDark)
                                    Text("按手表任意键 / 晃动手表拍照")
                                        .font(.system(size: 13))
                                        .foregroundColor(DMapTheme.textGray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                            }

                            if !viewModel.bluetoothManager.isConnected {
                                DMapCard {
                                    HStack(spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("请先连接手表")
                                            .font(.system(size: 13))
                                            .foregroundColor(DMapTheme.textGray)
                                        Spacer()
                                    }
                                    .padding(14)
                                }
                            }

                            Button(action: {
                                cameraManager.checkPermission { granted in
                                    if granted {
                                        cameraManager.startSession()
                                        viewModel.enterCameraMode()
                                    } else {
                                        showPermissionAlert = true
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text(viewModel.bluetoothManager.isConnected ? "进入拍照模式" : "请先连接手表")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(viewModel.bluetoothManager.isConnected ? DMapTheme.brandBlue : DMapTheme.tabNormal)
                                .cornerRadius(6)
                            }
                            .padding(.horizontal, 8)
                            .disabled(!viewModel.bluetoothManager.isConnected)

                            Text("照片会自动保存到系统相册。需要相机与相册权限。")
                                .font(.system(size: 11))
                                .foregroundColor(DMapTheme.textGray)
                                .padding(.horizontal, 14)
                        }
                        .padding(.top, 12)
                    }
                }
            }
        }
        .alert("需要相机权限", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在设置中允许 D-MAP 访问相机，以使用遥控拍照功能")
        }
        .onChange(of: viewModel.bluetoothManager.takePhotoTriggered) { triggered in
            if triggered && viewModel.isCameraMode {
                cameraManager.capturePhoto()
            }
        }
    }

    // 全屏取景（安卓拍照页同样为全屏相机）
    private var fullScreenCamera: some View {
        ZStack {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
            if cameraManager.showFlash {
                Color.white.ignoresSafeArea().transition(.opacity)
            }
            VStack {
                HStack {
                    Button(action: {
                        viewModel.exitCameraMode()
                        cameraManager.stopSession()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("遥控拍照")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(16)
                }
                .padding()
                Spacer()
                if cameraManager.lastPhotoTime != nil {
                    Text("照片已拍摄")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.85))
                        .cornerRadius(16)
                }
                HStack(spacing: 40) {
                    Button(action: { cameraManager.switchCamera() }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Button(action: { cameraManager.capturePhoto() }) {
                        ZStack {
                            Circle().stroke(Color.white, lineWidth: 4).frame(width: 70, height: 70)
                            Circle().fill(Color.white).frame(width: 58, height: 58)
                        }
                    }
                    if let lastImage = cameraManager.lastImage {
                        Image(uiImage: lastImage)
                            .resizable().scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 相机管理器
final class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var lastImage: UIImage?
    @Published var showFlash = false
    @Published var lastPhotoTime: Date?

    private var photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back

    override init() { super.init() }

    func checkPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default: completion(false)
        }
    }

    func startSession() {
        guard session.inputs.isEmpty else {
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
            }
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
        }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    func stopSession() {
        if session.isRunning { session.stopRunning() }
    }

    func switchCamera() {
        guard let currentInput = videoDeviceInput else { return }
        position = position == .back ? .front : .back
        session.beginConfiguration()
        session.removeInput(currentInput)
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            return
        }
        if session.canAddInput(input) { session.addInput(input); videoDeviceInput = input }
        else { session.addInput(currentInput) }
        session.commitConfiguration()
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if let previewFormat = settings.availablePreviewPhotoPixelFormatTypes.first {
            settings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewFormat]
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
        withAnimation(.easeInOut(duration: 0.1)) { showFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.2)) { self.showFlash = false }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        DispatchQueue.main.async {
            self.lastImage = image
            self.lastPhotoTime = Date()
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}

// MARK: - 相机预览
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

#Preview {
    CameraPage()
        .environmentObject(DeviceViewModel())
}
