import AVFoundation
import WebRTC
import UIKit

/// Captures camera frames using WebRTC's native RTCCameraVideoCapturer,
/// which correctly handles rotation, formats, and performance.
final class CameraCapture: NSObject {
    let videoSource: RTCVideoSource
    private let capturer: RTCCameraVideoCapturer
    private(set) var position: AVCaptureDevice.Position = .front

    // Expose the internal AVCaptureSession for SwiftUI local preview
    var captureSession: AVCaptureSession {
        return capturer.captureSession
    }

    var onStarted: (() -> Void)?

    init(factory: RTCPeerConnectionFactory) {
        videoSource = factory.videoSource()
        capturer = RTCCameraVideoCapturer(delegate: videoSource)
        super.init()
    }

    func configure() {
        // No manual configuration needed. RTCCameraVideoCapturer handles it.
    }

    /// 前后摄像头切换
    func flip() {
        position = position == .front ? .back : .front
        stop()
        startInternal()
    }

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.startInternal()
                } else {
                    print("Camera access denied")
                }
            }
        } else if status == .authorized {
            startInternal()
        } else {
            print("Camera access not authorized")
        }
    }

    private func startInternal() {
        let target = position
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 按当前朝向选摄像头（默认前置）
            let devices = RTCCameraVideoCapturer.captureDevices()
            guard let camera = devices.first(where: { $0.position == target }) ?? devices.first else {
                return
            }
            
            // Find a suitable format (e.g., around 720p)
            let formats = RTCCameraVideoCapturer.supportedFormats(for: camera)
            let format = formats.sorted {
                let dim1 = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                let dim2 = CMVideoFormatDescriptionGetDimensions($1.formatDescription)
                return (dim1.width * dim1.height) > (dim2.width * dim2.height)
            }.first(where: { 
                let dim = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                return dim.width <= 1280 && dim.height <= 720
            }) ?? formats.first!
            
            // Find max frame rate for the format, cap at 30 fps for WebRTC stability
            var maxFps: Int = 30
            for fpsRange in format.videoSupportedFrameRateRanges {
                maxFps = max(maxFps, Int(fpsRange.maxFrameRate))
            }
            maxFps = min(maxFps, 30)
            
            // RTCCameraVideoCapturer starts asynchronously natively, avoiding main thread blockage
            self.capturer.startCapture(with: camera, format: format, fps: maxFps) { [weak self] error in
                if let error = error {
                    print("Camera capture failed to start: \(error)")
                } else {
                    DispatchQueue.main.async {
                        self?.onStarted?()
                    }
                }
            }
        }
    }

    func stop() {
        capturer.stopCapture()
    }
}