import Foundation
import WebRTC
import AVFoundation
import UIKit

/// Reads video frames from the BroadcastExtension over the App Group unix socket
/// and pushes them into an RTCVideoSource.
///
/// Protocol (matches BroadcastExtension/SampleHandler.swift):
///   HTTP/1.1 200 OK\r\n
///   Buffer-Width: <w>\r\nBuffer-Height: <h>\r\nBuffer-Orientation: <o>\r\n
///   Content-Length: <len>\r\n\r\n
///   <JPEG bytes>
final class SocketVideoCapturer: NSObject {
    private var capturer: RTCVideoCapturer!
    private var socket: SocketClient?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let source: RTCVideoSource

    /// Called on the main thread with a preview image for each captured frame (throttled).
    var onPreviewFrame: ((UIImage) -> Void)?
    private var lastPreviewTime: TimeInterval = 0

    init(source: RTCVideoSource) {
        self.source = source
        super.init()
        let cap = RTCVideoCapturer(delegate: source)
        self.capturer = cap
    }

    func start() {
        guard let groupID = Bundle.main.object(forInfoDictionaryKey: "RTCAppGroupIdentifier") as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            print("⚠️ [Capturer] App Group container missing")
            return
        }
        let sockPath = container.appendingPathComponent("rtc_SSFD").path
        let client = SocketClient(path: sockPath)
        client.onFrame = { [weak self] jpegData, width, height, orientation in
            self?.pushFrame(jpegData, width: width, height: height)
        }
        self.socket = client
        // Retry connecting while host app starts the server.
        var connected = false
        for _ in 0..<20 {
            if client.connect() { connected = true; break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        print(connected ? "✅ [Capturer] Socket connected" : "❌ [Capturer] Socket connect failed")
    }

    func stop() {
        socket?.close()
        socket = nil
        capturer = nil
    }

    private func pushFrame(_ jpeg: Data, width: Int, height: Int) {
        guard let image = UIImage(data: jpeg) else { return }

        // Emit throttled preview on main thread.
        let now = Date().timeIntervalSince1970
        if now - lastPreviewTime > 0.066 {
            lastPreviewTime = now
            let preview = image
            DispatchQueue.main.async { [weak self] in
                self?.onPreviewFrame?(preview)
            }
        }

        guard let cgImage = image.cgImage else { return }
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferCGImageCompatibilityKey: true,
                             kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
                            &pb)
        guard let pixelBuffer = pb else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            return
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let videoFrame = RTCVideoFrame(buffer: RTCCVPixelBuffer(pixelBuffer: pixelBuffer),
                                       rotation: ._0,
                                       timeStampNs: Int64(Date().timeIntervalSince1970 * 1_000_000_000))
        source.capturer(capturer, didCapture: videoFrame)
    }
}

/// Minimal UNIX domain socket client that reads `rtc_SSFD` framing.
final class SocketClient {
    var onFrame: ((Data, Int, Int, Int) -> Void)?
    private let path: String
    private var fd: Int32 = -1
    private var buffer = Data()
    private var thread: Thread?

    init(path: String) {
        self.path = path
    }

    func connect() -> Bool {
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        let pathPtr = path.withCString { UnsafePointer($0) }
        withUnsafeMutablePointer(to: &addr.sun_path) { sunPathPtr in
            let raw = UnsafeMutableRawPointer(sunPathPtr)
            raw.copyMemory(from: pathPtr, byteCount: min(bytes.count, 104))
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, addrLen)
            }
        }
        guard result == 0 else {
            Darwin.close(sock)
            return false
        }
        fd = sock
        var one = 1
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int>.size))
        thread = Thread { [weak self] in
            self?.readLoop()
        }
        thread?.start()
        return true
    }

    func close() {
        if fd >= 0 { Darwin.close(fd); fd = -1 }
        thread?.cancel()
        thread = nil
    }

    private func readLoop() {
        var chunk = [UInt8](repeating: 0, count: 8192)
        while !Thread.current.isCancelled && fd >= 0 {
            let n = read(fd, &chunk, chunk.count)
            if n > 0 {
                buffer.append(contentsOf: chunk[0..<n])
                parseBuffer()
            } else if n < 0 && errno == EAGAIN {
                Thread.sleep(forTimeInterval: 0.01)
            } else {
                break
            }
        }
    }

    private func parseBuffer() {
        while true {
            guard let range = buffer.range(of: Data("\r\n\r\n".utf8)) else { return }
            let headerData = buffer[..<range.lowerBound]
            guard let header = String(data: headerData, encoding: .utf8) else {
                buffer.removeSubrange(..<range.upperBound)
                continue
            }
            var length = 0, width = 0, height = 0, orientation = 0
            for line in header.split(separator: "\r\n") {
                if line.hasPrefix("Content-Length:") {
                    length = Int(line.dropFirst("Content-Length:".count).trimmingCharacters(in: .whitespaces)) ?? 0
                } else if line.hasPrefix("Buffer-Width:") {
                    width = Int(line.dropFirst("Buffer-Width:".count).trimmingCharacters(in: .whitespaces)) ?? 0
                } else if line.hasPrefix("Buffer-Height:") {
                    height = Int(line.dropFirst("Buffer-Height:".count).trimmingCharacters(in: .whitespaces)) ?? 0
                } else if line.hasPrefix("Buffer-Orientation:") {
                    orientation = Int(line.dropFirst("Buffer-Orientation:".count).trimmingCharacters(in: .whitespaces)) ?? 0
                }
            }
            let bodyStart = range.upperBound
            guard buffer.count - bodyStart >= length else { return }
            let body = buffer[bodyStart..<(bodyStart + length)]
            onFrame?(Data(body), width, height, orientation)
            buffer.removeSubrange(..<(bodyStart + length))
        }
    }
}