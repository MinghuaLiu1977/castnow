import '../core/flavor_config.dart';

class AppStrings {
  const AppStrings._();

  static bool get _isZh => FlavorConfig.isStandard;

  static String get appTitle => _isZh ? 'CastNow - 屏幕投屏' : 'CastNow - Screen Cast';
  static String get close => _isZh ? '关闭' : 'CLOSE';
  static String get open => _isZh ? '打开' : 'OPEN';

  static String get p2pSecure => _isZh ? 'P2P 加密传输' : 'P2P SECURE';
  static String get receiveOn => _isZh ? '接收端访问: ' : 'Receive on: ';
  static String get broadcast => _isZh ? '开始投屏' : 'Broadcast';
  static String get broadcastSubtitle => _isZh ? '共享摄像头或屏幕' : 'Share camera or screen';
  static String get receive => _isZh ? '接收投屏' : 'Receive';
  static String get receiveSubtitle => _isZh ? '观看投屏内容' : 'Watch a stream';
  static String get getPro => _isZh ? '升级专业版' : 'GET PRO';
  static String get pro => _isZh ? '专业版' : 'PRO';
  static String get footerEngine => _isZh ? 'CastNow P2P 引擎 v3.1.5' : 'CastNow P2P Engine v3.1.5';
  static String get footerManage => _isZh ? '管理订阅' : 'MANAGE';
  static String get footerTerms => _isZh ? '条款' : 'TERMS';
  static String get footerPrivacy => _isZh ? '隐私' : 'PRIVACY';
  static String get footerHelp => _isZh ? '帮助' : 'HELP';

  static String get broadcastSelectSource =>
      _isZh ? '请至少选择一个视频源（屏幕或摄像头）' : 'Please select at least one video (Screen or Camera).';
  static String get freeVersionLimit =>
      _isZh ? '免费版：投屏时长限制为 2 分钟' : 'Free Version: Streaming is limited to 2 minutes.';
  static String get rtmpUrlRequired => _isZh ? '请输入 RTMP 地址' : 'Please enter RTMP URL.';
  static String criticalError(String error) => _isZh ? '严重错误: $error' : 'Critical Error: $error';
  static String get signalServerUnavailable =>
      _isZh ? '信令服务器不可用，请检查网络连接' : 'Signal Server Unavailable. Please check your internet connection.';
  static String get broadcastScreenStr => _isZh ? '屏幕' : 'Screen';
  static String get broadcastCameraStr => _isZh ? '摄像头' : 'Camera';
  static String get broadcastMicStr => _isZh ? '麦克风' : 'Mic';
  static String get broadcastStart => _isZh ? '开始投屏' : 'START BROADCAST';
  static String get broadcastStopLabel => _isZh ? '停止投屏' : 'Stop Broadcast';
  static String get broadcastConnecting => _isZh ? '连接中...' : 'Connecting...';
  static String get broadcastConnected => _isZh ? '已连接' : 'CONNECTED';
  static String get broadcastSharing => _isZh ? '投屏中' : 'SHARING';
  static String get broadcastOnAir => _isZh ? '直播中' : 'ON AIR';
  static String get broadcastSelectSources => _isZh ? '选择来源' : 'SELECT SOURCES';
  static String get broadcastSelectDesc =>
      _isZh ? '选择要投屏的内容' : 'Select what to broadcast to the receiver';
  static String get broadcastProEdition => _isZh ? '专业版' : 'PRO EDITION';
  static String get broadcastTerminate => _isZh ? '结束投屏' : 'Terminate Stream';
  static String get broadcastStop => _isZh ? '停止' : 'STOP';
  static String get broadcastUpgrade => _isZh ? '升级到专业版' : 'UPGRADE TO PRO';
  static String broadcastTimeLimit(String limit) =>
      _isZh ? '免费版投屏时长限制 $limit' : 'Free streaming is limited to $limit.';
  static String get broadcastTimeLimitUpgrade =>
      _isZh ? '升级到专业版后可继续投屏' : 'Upgrade to PRO to continue this broadcast.';
  static String get pairCode => _isZh ? '配对码' : 'Pair Code';

  static String get receiveEnterCode => _isZh ? '输入 6 位配对码' : 'Enter 6-digit code';
  static String get receiveJoin => _isZh ? '加入投屏' : 'Join Stream';
  static String get receiveLeave => _isZh ? '退出' : 'Leave';

  static String get timeLimitReached => _isZh ? '投屏时长已达上限' : 'Time Limit Reached';
  static String get screenMirroringActive => _isZh ? '屏幕镜像运行中' : 'Screen Mirroring Active';
  static String get sharingEntireScreen => _isZh ? '正在共享屏幕...' : 'Sharing entire screen...';
  static String openToReceiveTip(String url) =>
      _isZh ? '打开 $url 开始接收' : 'Open $url to receive';
  static String get accessCode => _isZh ? '配对码' : 'ACCESS CODE';
  static String get connect => _isZh ? '连接' : 'CONNECT';
  static String get askBroadcasterForKey => _isZh ? '询问主播获取配对码' : 'Ask broadcaster for key';
  static String get flip => _isZh ? '翻转摄像头' : 'Flip';
  static String get unmute => _isZh ? '取消静音' : 'Unmute';
  static String get muteMic => _isZh ? '静音' : 'Mute';
  static String get talk => _isZh ? '对讲' : 'Talk';
  static String get sharingAccessKey => _isZh ? '投屏配对码' : 'SHARING ACCESS KEY';
  static String receiverPrefix(String info) => _isZh ? '接收方: $info' : 'Receiver: $info';
  static String get screenMirror => _isZh ? '屏幕镜像' : 'Screen Mirror';
  static String get screenMirrorDesc => _isZh ? '共享整个 iOS 屏幕' : 'Broadcast your entire iOS screen';
  static String get cameraView => _isZh ? '摄像头画面' : 'Camera View';
  static String get cameraViewDesc => _isZh ? '共享高清摄像头画面' : 'Share high-quality camera stream';
  static String get hdMicrophone => _isZh ? '高清麦克风' : 'HD Microphone';
  static String get hdMicrophoneDesc =>
      _isZh ? '采集高清音频（默认静音）' : 'Capture crystal clear audio (Muted by default)';
  static String get rtmpMode => _isZh ? 'RTMP 模式' : 'RTMP Mode';
  static String get rtmpModeDesc =>
      _isZh ? '推流至 RTMP 服务器（YouTube、Twitch 等）' : 'Broadcast to RTMP server (YouTube, Twitch, etc.)';
  static String get rtmpUrlLabel => _isZh ? 'RTMP 地址' : 'RTMP URL';
  static String get streamKeyLabel => _isZh ? '推流密钥' : 'Stream Key';
  static String get enterStreamKey => _isZh ? '输入推流密钥' : 'Enter stream key';
  static String get unlockUnlimitedCasting => _isZh ? '解锁无限 P2P 投屏' : 'Unlock unlimited P2P casting';
  static String get hdVideoQuality => _isZh ? '高清画质' : 'HD Video Quality';
  static String get crystalClearAudio => _isZh ? '高保真音频' : 'Crystal Clear Audio';
  static String get subscribeNow => _isZh ? '立即订阅' : 'Subscribe Now';
  static String get maybeLater => _isZh ? '稍后再说' : 'Maybe Later';
  static String get premiumPlanDesc =>
      _isZh ? '年度订阅（自动续费）\n按年计费，随时取消' : '1 Year (Auto-Renewable)\nBilled yearly, cancel anytime';
  static String get termsOfUse => _isZh ? '使用条款 (EULA)' : 'Terms of Use (EULA)';
  static String get andConnector => _isZh ? ' 和 ' : ' and ';
  static String get privacyPolicy => _isZh ? '隐私政策' : 'Privacy Policy';

  static String get paywallTitle => _isZh ? '升级到专业版' : 'Upgrade to Pro';
  static String get paywallUnlimitedTime => _isZh ? '无限时长' : 'Unlimited Time';
  static String get paywallRtmp => _isZh ? 'RTMP 推流' : 'RTMP Streaming';
  static String get paywallAllDevices => _isZh ? '全设备支持' : 'All Devices';
  static String get paywallRestore => _isZh ? '恢复购买' : 'Restore Purchase';
}
