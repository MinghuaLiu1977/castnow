import SwiftUI
import WebRTC
import MetalKit

extension UIView {
    func pauseMetalViews(_ pause: Bool) {
        if let mtkView = self as? MTKView {
            mtkView.isPaused = pause
        }
        for subview in subviews {
            subview.pauseMetalViews(pause)
        }
    }
}

class VideoViewWrapper: UIView, RTCVideoRenderer {
    private var videoView: RTCMTLVideoView?
    private var currentTrack: RTCVideoTrack?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.cornerRadius = 12
        self.layer.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.layer.cornerRadius = 12
        self.layer.masksToBounds = true
    }
    
    // Thread-safe state for the renderer to avoid Main Thread Checker exceptions
    private let stateLock = NSLock()
    private var _isReadyToRender: Bool = false
    var isReadyToRender: Bool {
        get {
            stateLock.lock()
            let value = _isReadyToRender
            stateLock.unlock()
            return value
        }
        set {
            stateLock.lock()
            _isReadyToRender = newValue
            stateLock.unlock()
        }
    }
    
    // CRITICAL: Prevent SwiftUI from expanding the view to the video's native pixel resolution.
    // Without this, a 4K video causes SwiftUI to create a 3840x2160 view, which MTKView then 
    // multiplies by the screen scale (e.g. 3x or 4x), resulting in a 15K texture allocation crash!
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let safeWidth = max(16.0, bounds.width)
        let safeHeight = max(16.0, bounds.height)
        let safeFrame = CGRect(x: bounds.origin.x, y: bounds.origin.y, width: safeWidth, height: safeHeight)
        
        print("📺 [VideoStreamView] layoutSubviews: View bounds: \(bounds.width) x \(bounds.height) -> safeFrame: \(safeFrame.width) x \(safeFrame.height)")
        
        let isValidBounds = (bounds.width >= 1 && bounds.height >= 1)
        self.isReadyToRender = (self.window != nil && isValidBounds)
        
        if isValidBounds {
            if videoView == nil {
                let view = RTCMTLVideoView(frame: safeFrame)
                view.videoContentMode = .scaleAspectFit
                addSubview(view)
                self.videoView = view
                
                let active = (self.window != nil && currentTrack != nil)
                view.isEnabled = active
                view.pauseMetalViews(!active)
            } else {
                videoView?.isHidden = false
                videoView?.frame = safeFrame
                videoView?.videoContentMode = .scaleAspectFit
                let active = (self.window != nil && currentTrack != nil)
                videoView?.pauseMetalViews(!active)
            }
        } else {
            videoView?.isHidden = true
            videoView?.frame = safeFrame
            videoView?.pauseMetalViews(true) // Aggressively pause when invalid bounds
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        self.isReadyToRender = (self.window != nil && bounds.width >= 1 && bounds.height >= 1)
        let active = (self.window != nil && currentTrack != nil)
        videoView?.isEnabled = active
        videoView?.pauseMetalViews(!active)
    }
    
    func setTrack(_ track: RTCVideoTrack?) {
        if currentTrack == track { return }
        if let current = currentTrack {
            current.remove(self) // Remove self (proxy)
        }
        currentTrack = track
        if let newTrack = track {
            newTrack.add(self) // Add self (proxy)
            let active = (self.window != nil)
            videoView?.isEnabled = active
            videoView?.pauseMetalViews(!active)
        } else {
            // Immediately destroy the view and pause all metal render loops
            videoView?.isEnabled = false
            videoView?.pauseMetalViews(true)
            videoView?.removeFromSuperview()
            videoView = nil
        }
    }
    
    // MARK: - RTCVideoRenderer Proxy
    
    func setSize(_ size: CGSize) {
        print("📐 [VideoStreamView] setSize called with WebRTC video dimensions: \(size.width) x \(size.height)")
        
        // CRITICAL FIX FOR 15K CRASH: 
        // WebRTC's RTCMTLVideoView internally multiplies the size passed here by `UIScreen.main.scale` (e.g. 3x on iPhone Pro).
        // If the web sends a 5K video (5120x2880), RTCMTLVideoView computes drawableSize = 5120 * 3 = 15360!
        // This exceeds Metal's 8192 limit and crashes instantly.
        // The fix is to pass the size in UI Points (divided by scale) instead of raw pixels, so WebRTC's multiplication
        // perfectly restores it back to the true pixel size (or at least keeps it under 8192).
        let scale = UIScreen.main.scale
        let widthInPoints = size.width / scale
        let heightInPoints = size.height / scale
        
        let safeSize = CGSize(width: max(16.0, widthInPoints), height: max(16.0, heightInPoints))
        videoView?.setSize(safeSize)
    }
    
    func renderFrame(_ frame: RTCVideoFrame?) {
        // Use thread-safe flag instead of reading `self.window` or `self.bounds` on WebRTC's background thread
        guard isReadyToRender else { return }
        
        guard let validFrame = frame, validFrame.width >= 16, validFrame.height >= 16 else {
            return
        }
        
        // CRITICAL: Retina Mac screens (e.g. 5K display) can capture frames up to 15360x8640.
        // MTLSimDevice max texture size is 8192. We must drop frames that are too large to prevent SIGABRT.
        if validFrame.width > 8192 || validFrame.height > 8192 {
            // We skip rendering these oversized frames. The web sender should cap resolution.
            print("🚨 [VideoStreamView] WARNING: DROPPED DANGEROUS VIDEO FRAME: \(validFrame.width) x \(validFrame.height)")
            return
        }
        
        videoView?.renderFrame(validFrame)
    }
}

/// UIViewRepresentable wrapper around WebRTC's video view.
struct VideoStreamView: UIViewRepresentable {
    let track: RTCVideoTrack?

    func makeUIView(context: Context) -> VideoViewWrapper {
        return VideoViewWrapper()
    }

    func updateUIView(_ uiView: VideoViewWrapper, context: Context) {
        uiView.setTrack(track)
    }
    
    static func dismantleUIView(_ uiView: VideoViewWrapper, coordinator: ()) {
        // Clean up the track to prevent the orphaned view from receiving frames
        uiView.setTrack(nil)
    }
}