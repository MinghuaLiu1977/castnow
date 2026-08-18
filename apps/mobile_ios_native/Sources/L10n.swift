import Foundation

/// 集中管理本地化字符串：跟随系统语言自动适配
/// （开发语言为英文 en，zh-Hans 为支持的本地化，其他语言回退英文）
enum L10n {
    private static func tr(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }

    /// 当前生效界面语言是否为中文
    static var isChinese: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true
    }

    // MARK: - 接收端网址（随语言切换：中文 padap.cn / 英文 vercel.app）

    static var webBaseURL: String { tr("web_base_url") }
    static var webFullURL: String { "https://\(webBaseURL)" }

    // MARK: - Common

    static var tagline: String { tr("tagline") }
    static var alertOK: String { tr("alert_ok") }

    // MARK: - Home

    static var homeReceiveOn: String { tr("home_receive_on") }
    static var homeBroadcast: String { tr("home_broadcast") }
    static var homeBroadcastSub: String { tr("home_broadcast_sub") }
    static var homeReceive: String { tr("home_receive") }
    static var homeReceiveSub: String { tr("home_receive_sub") }
    static var homeEngine: String { tr("home_engine") }
    static var homeTerms: String { tr("home_terms") }
    static var homePrivacy: String { tr("home_privacy") }
    static var homeHelp: String { tr("home_help") }

    // MARK: - Source select

    static var sourceTitle: String { tr("source_title") }
    static var sourceDesc: String { tr("source_desc") }
    static var sourceScreen: String { tr("source_screen") }
    static var sourceScreenSub: String { tr("source_screen_sub") }
    static var sourceCamera: String { tr("source_camera") }
    static var sourceCameraSub: String { tr("source_camera_sub") }
    static var sourceMic: String { tr("source_mic") }
    static var sourceMicSub: String { tr("source_mic_sub") }
    static var sourceLaunch: String { tr("source_launch") }
    static var sourceLaunchFailed: String { tr("source_launch_failed") }
    static var permCamera: String { tr("perm_camera") }
    static var permMic: String { tr("perm_mic") }
    static var permJoin: String { tr("perm_join") }
    static var permDeniedFormat: String { tr("perm_denied_format") }

    // MARK: - Receive

    static var receiveTitle: String { tr("receive_title") }
    static var receiveConnect: String { tr("receive_connect") }
    static var receiveConnecting: String { tr("receive_connecting") }
    static var receiveDisconnected: String { tr("receive_disconnected") }

    // MARK: - Broadcast

    static var bcConnecting: String { tr("bc_connecting") }
    static var bcWaitingReceiver: String { tr("bc_waiting_receiver") }
    static var bcInitializing: String { tr("bc_initializing") }
    static var bcBroadcastEnded: String { tr("bc_broadcast_ended") }
    static var bcReceiverConnected: String { tr("bc_receiver_connected") }
    static var bcReceiverLeft: String { tr("bc_receiver_left") }
    static var bcErrorFormat: String { tr("bc_error_format") }
    static var bcRecalling: String { tr("bc_recalling") }
    static var bcConnected: String { tr("bc_connected") }
    static var bcStartingScreen: String { tr("bc_starting_screen") }
    static var bcStartingCamera: String { tr("bc_starting_camera") }
    static var bcSystemDialogTip: String { tr("bc_system_dialog_tip") }
    static var bcPairCodeTitle: String { tr("bc_pair_code_title") }
    static var bcOpenPrefix: String { tr("bc_open_prefix") }
    static var bcOpenSuffix: String { tr("bc_open_suffix") }
    static var bcLabelMic: String { tr("bc_label_mic") }
    static var bcLabelMicMuted: String { tr("bc_label_mic_muted") }
    static var bcLabelSound: String { tr("bc_label_sound") }
    static var bcLabelSoundOff: String { tr("bc_label_sound_off") }
    static var bcFlip: String { tr("bc_flip") }
    static var bcEnd: String { tr("bc_end") }

    // MARK: - PeerJS

    static var signalingTimeout: String { tr("signaling_timeout") }
}
