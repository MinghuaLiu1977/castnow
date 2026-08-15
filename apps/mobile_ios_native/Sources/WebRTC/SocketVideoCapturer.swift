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
    private var socket: SocketServer?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let source: RTCVideoSource

    /// Called on the main thread with a preview image for each captured frame (throttled).
    var onPreviewFrame: ((UIImage) -> Void)?
    private var lastPreviewTime: TimeInterval = 0
    private var lastResLogTime: TimeInterval = 0

    /// 像素缓冲池：复用 IOSurface，避免每帧 6.8MB 分配导致 IOSurface creation failed
    private var pixelPool: CVPixelBufferPool?
    private var poolLock = NSLock()

    /// Called when the BroadcastExtension disconnects (broadcast finished by
    /// system — lock screen, control-center stop, or extension crash).
    var onBroadcastEnded: (() -> Void)?

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
        let server = SocketServer(path: sockPath)
        server.onFrame = { [weak self] jpegData, width, height, orientation in
            self?.pushFrame(jpegData, width: width, height: height)
        }
        server.onClientDisconnected = { [weak self] in
            print("🛑 [Capturer] Extension socket closed → broadcast ended")
            self?.onBroadcastEnded?()
        }
        self.socket = server
        // Non-blocking: server listens on a background thread; extension connects in.
        server.start()
        print("✅ [Capturer] Socket server listening")
    }

    func stop() {
        socket?.close()
        socket = nil
        capturer = nil
        poolLock.lock()
        pixelPool = nil
        poolLock.unlock()
    }

    /// 获取/重建与目标尺寸匹配的缓冲池（尺寸变化时重建一次）
    private func pooledBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        poolLock.lock()
        defer { poolLock.unlock() }
        if let pool = pixelPool,
           let attrs = CVPixelBufferPoolGetPixelBufferAttributes(pool) as? [String: Any],
           let w = attrs[kCVPixelBufferWidthKey as String] as? Int,
           let h = attrs[kCVPixelBufferHeightKey as String] as? Int,
           w == width, h == height {
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb)
            return pb
        }
        let poolAttrs: [String: Any] = [kCVPixelBufferPoolMinimumBufferCountKey as String: 3]
        let bufAttrs: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var newPool: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttrs as CFDictionary,
                                      bufAttrs as CFDictionary, &newPool) == kCVReturnSuccess,
              let pool = newPool else { return nil }
        pixelPool = pool
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb)
        return pb
    }

    private func pushFrame(_ jpeg: Data, width: Int, height: Int) {
        // autoreleasepool：每帧 JPEG 解码产生大量临时对象，及时释放降低 jetsam 风险
        autoreleasepool {
        guard let image = UIImage(data: jpeg) else { return }

        // 分辨率日志：每 3 秒打印一次采集输入与送编码前的目标尺寸
        let now = Date().timeIntervalSince1970
        if now - lastResLogTime > 3.0 {
            lastResLogTime = now
            let imgW = image.cgImage?.width ?? -1
            let imgH = image.cgImage?.height ?? -1
            print("📐 [Capturer] socket frame \(width)x\(height), decoded \(imgW)x\(imgH), jpeg \(jpeg.count) bytes")
        }

        // 预览瘦身：5fps + 缩到 320px 宽，避免主线程持有/解码全尺寸帧（内存+CPU）
        if now - lastPreviewTime > 0.2 {
            lastPreviewTime = now
            let maxSide: CGFloat = 320
            let scale = min(1, maxSide / max(image.size.width, image.size.height))
            if scale < 1, let cg = image.cgImage {
                let newSize = CGSize(width: floor(image.size.width * scale),
                                     height: floor(image.size.height * scale))
                let thumbCtx = CGContext(data: nil, width: Int(newSize.width), height: Int(newSize.height),
                                         bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
                thumbCtx?.interpolationQuality = .medium
                thumbCtx?.draw(cg, in: CGRect(origin: .zero, size: newSize))
                if let thumbCg = thumbCtx?.makeImage() {
                    let preview = UIImage(cgImage: thumbCg)
                    DispatchQueue.main.async { [weak self] in
                        self?.onPreviewFrame?(preview)
                    }
                }
            } else {
                let preview = image
                DispatchQueue.main.async { [weak self] in
                    self?.onPreviewFrame?(preview)
                }
            }
        }

        guard let cgImage = image.cgImage else { return }

        // 宽高上限 2560：iPhone 16 竖屏约 1206x2622，仅超高维度等比缩到 2560
        var targetWidth = width
        var targetHeight = height
        let maxWidth = 2560
        let maxHeight = 2560
        if targetWidth > maxWidth {
            let ratio = CGFloat(maxWidth) / CGFloat(targetWidth)
            targetWidth = maxWidth
            targetHeight = Int(CGFloat(targetHeight) * ratio)
        }
        if targetHeight > maxHeight {
            let ratio = CGFloat(maxHeight) / CGFloat(targetHeight)
            targetHeight = maxHeight
            targetWidth = Int(CGFloat(targetWidth) * ratio)
        }

        guard let pixelBuffer = pooledBuffer(width: targetWidth, height: targetHeight) else {
            print("⚠️ [Capturer] pixel pool exhausted, drop frame")
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: targetWidth, height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            return
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let videoFrame = RTCVideoFrame(buffer: RTCCVPixelBuffer(pixelBuffer: pixelBuffer),
                                       rotation: ._0,
                                       timeStampNs: Int64(Date().timeIntervalSince1970 * 1_000_000_000))
        source.capturer(capturer, didCapture: videoFrame)
        }
    }
}

/// Minimal UNIX domain socket client that reads `rtc_SSFD` framing.
/// UNIX domain socket **server**. The BroadcastExtension (SampleHandler) connects
/// as a client and streams JPEG frames; we accept and read them on a background thread.
final class SocketServer {
    var onFrame: ((Data, Int, Int, Int) -> Void)?
    /// Fires when a connected extension client goes away (broadcast finished).
    var onClientDisconnected: (() -> Void)?
    private let path: String
    private var serverFd: Int32 = -1
    private var clientFd: Int32 = -1
    private var buffer = Data()
    private var thread: Thread?
    private var deliberateClose = false

    init(path: String) {
        self.path = path
    }

    /// Non-blocking: binds + listens, then accepts/reads on a background thread.
    func start() {
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        withUnsafeMutablePointer(to: &addr.sun_path) { sunPathPtr in
            let raw = UnsafeMutableRawPointer(sunPathPtr)
            bytes.withUnsafeBufferPointer { buf in
                raw.copyMemory(from: buf.baseAddress!, byteCount: min(bytes.count, 104))
            }
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, addrLen)
            }
        }
        guard bindResult == 0, listen(fd, 1) == 0 else {
            Darwin.close(fd)
            return
        }
        serverFd = fd
        thread = Thread { [weak self] in
            self?.acceptLoop()
        }
        thread?.start()
    }

    private func acceptLoop() {
        while !Thread.current.isCancelled && serverFd >= 0 {
            let client = accept(serverFd, nil, nil)
            guard client >= 0 else { break }
            clientFd = client
            var one = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int>.size))
            readLoop(client)
            // 只在仍持有所有权时关闭，避免与 close() 双重 close 误伤其他线程新分配的 fd
            if clientFd == client {
                Darwin.close(client)
                clientFd = -1
            }
            buffer.removeAll()
            // Extension disconnected: broadcast ended (lock screen / system stop).
            // Only meaningful while the server is still meant to be alive.
            if serverFd >= 0 && !deliberateClose && !Thread.current.isCancelled {
                onClientDisconnected?()
            }
        }
    }

    func close() {
        deliberateClose = true
        if clientFd >= 0 { Darwin.close(clientFd); clientFd = -1 }
        if serverFd >= 0 { Darwin.close(serverFd); serverFd = -1 }
        thread?.cancel()
        thread = nil
        unlink(path)
    }

    private func readLoop(_ fd: Int32) {
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
            // 从头找 HTTP 状态行；若开头就是垃圾（半包/错位），丢弃到下一个头部的候选点
            guard buffer.first == UInt8(ascii: "H") else {
                // 找不到 "HTTP/1.1 200 OK" 开头就丢 1 字节继续（避免错位解析越界崩溃）
                if let r = buffer.range(of: Data("HTTP/1.1".utf8)) {
                    buffer.removeSubrange(..<r.lowerBound)
                } else {
                    // 只保留可能的头部前缀，防 362KB JPEG 全扫描
                    buffer.removeAll(keepingCapacity: true)
                }
                continue
            }
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
            // 校验：合法帧长度 1KB~8MB；长度不足继续等数据
            guard length > 1_000, length < 8_000_000, width > 0, height > 0 else {
                buffer.removeSubrange(..<range.upperBound)
                continue
            }
            let bodyStart = range.upperBound
            guard buffer.count - bodyStart >= length else { return }
            let body = buffer.subdata(in: bodyStart..<(bodyStart + length))
            onFrame?(body, width, height, orientation)
            buffer.removeSubrange(..<(bodyStart + length))
        }
    }
}