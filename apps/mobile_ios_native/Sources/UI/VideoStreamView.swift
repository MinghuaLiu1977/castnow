import SwiftUI
import WebRTC

/// UIViewRepresentable wrapper around WebRTC's Metal video view.
struct VideoStreamView: UIViewRepresentable {
    let track: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = .scaleAspectFit
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        if let track = track {
            track.add(uiView)
        }
    }
}