import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// 定义 CastNow 的品牌色
const Color kBackgroundColor = Color(0xFF020617); // Slate 950
const Color kPrimaryColor = Color(0xFFF59E0B);    // Amber 500

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CastNowApp());
}

class CastNowApp extends StatelessWidget {
  const CastNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 设置系统状态栏颜色以匹配应用背景
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: kBackgroundColor,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'CastNow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          background: kBackgroundColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: kBackgroundColor,
      ),
      home: const CastNowHome(),
    );
  }
}

class CastNowHome extends StatefulWidget {
  const CastNowHome({super.key});

  @override
  State<CastNowHome> createState() => _CastNowHomeState();
}

class _CastNowHomeState extends State<CastNowHome> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  // 生产环境地址
  final String _targetUrl = 'https://castnow.vercel.app/'; 

  // WebView 配置: 开启 WebRTC 和 媒体播放支持
  final InAppWebViewSettings _settings = InAppWebViewSettings(
    isInspectable: true, // 允许调试
    mediaPlaybackRequiresUserGesture: false, // 允许自动播放
    allowsInlineMediaPlayback: true, // 允许内联播放 (iOS必需)
    iframeAllowFullscreen: true,
    userAgent: "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36 CastNowApp", // 伪装成现代 Chrome 以确保 WebRTC 功能完整开启
    
    // Android 特定配置
    safeBrowsingEnabled: false,
    domStorageEnabled: true,
    databaseEnabled: true,
    allowFileAccessFromFileURLs: true,
    allowUniversalAccessFromFileURLs: true,
  );

  @override
  void initState() {
    super.initState();
    _initNativeFeatures();
  }

  Future<void> _initNativeFeatures() async {
    // 1. 保持屏幕常亮
    await WakelockPlus.enable();

    // 2. 预先请求关键权限 (WebRTC 需要)
    // 注意：getDisplayMedia (录屏) 不需要预先申请 runtime permission，
    // 而是需要 WebView 的 onPermissionRequest 配合 Android System UI。
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_targetUrl)),
              initialSettings: _settings,
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() => _isLoading = true);
              },
              onLoadStop: (controller, url) {
                setState(() => _isLoading = false);
              },
              // 关键：处理 WebRTC 权限请求 (Android)
              // 当网页调用 getDisplayMedia 或 getUserMedia 时触发
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT,
                );
              },
              // 拦截非应用内链接
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url!;
                if (!uri.toString().startsWith('http')) {
                  return NavigationActionPolicy.ALLOW;
                }
                
                // 允许 CastNow 域名和 PeerJS 通信
                if (uri.host.contains('castnow') || 
                    uri.host.contains('vercel') ||
                    uri.host.contains('peerjs')) {
                  return NavigationActionPolicy.ALLOW;
                }
                
                // 其他链接（如支付）可以考虑用外部浏览器打开，这里暂时保持应用内
                return NavigationActionPolicy.ALLOW; 
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint("WEB_LOG: ${consoleMessage.message}");
              },
            ),
            
            // 加载指示器
            if (_isLoading)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: kPrimaryColor),
                    SizedBox(height: 16),
                    Text(
                      "CONNECTING TO NETWORK...",
                      style: TextStyle(
                        color: kPrimaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
