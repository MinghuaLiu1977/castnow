import AVFoundation
import WebRTC
import UIKit

/// Captures camera frames using WebRTC's native RTCCameraVideoCapturer,
/// which correctly handles rotation, formats, and performance.
final class CameraCapture: NSObject {
    let videoSource: RTCVideoSource
    private let capturer: RTCCameraVideoCapturer
    
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

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Find the front camera
            let devices = RTCCameraVideoCapturer.captureDevices()
            guard let frontCamera = devices.first(where: { $0.position == .front }) ?? devices.first else {
                return
            }
            
            // Find a suitable format (e.g., around 720p)
            let formats = RTCCameraVideoCapturer.supportedFormats(for: frontCamera)
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
            self.capturer.startCapture(with: frontCamera, format: format, fps: maxFps) { [weak self] error in
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