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

  static String get paywallTitle => _isZh ? '升级到专业版' : 'Upgrade to Pro';
  static String get paywallUnlimitedTime => _isZh ? '无限时长' : 'Unlimited Time';
  static String get paywallRtmp => _isZh ? 'RTMP 推流' : 'RTMP Streaming';
  static String get paywallAllDevices => _isZh ? '全设备支持' : 'All Devices';
  static String get paywallRestore => _isZh ? '恢复购买' : 'Restore Purchase';
}
