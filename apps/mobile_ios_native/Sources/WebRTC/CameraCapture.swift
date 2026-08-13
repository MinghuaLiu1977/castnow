import AVFoundation
import WebRTC
import UIKit

/// Captures camera frames via AVCaptureSession, feeds an RTCVideoSource,
/// and exposes a preview layer for SwiftUI.
final class CameraCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    let videoSource: RTCVideoSource
    private let capturer: RTCVideoCapturer
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "castnow.camera.capture")
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    init(factory: RTCPeerConnectionFactory) {
        videoSource = factory.videoSource()
        capturer = RTCVideoCapturer(delegate: videoSource)
        super.init()
    }

    func configure() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        captureSession.commitConfiguration()

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
    }

    func start() {
        captureQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stop() {
        captureQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let frame = RTCVideoFrame(
            buffer: RTCCVPixelBuffer(pixelBuffer: pixelBuffer),
            rotation: ._0,
            timeStampNs: Int64(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds * 1_000_000_000)
        )
        videoSource.capturer(capturer, didCapture: frame)
    }
}