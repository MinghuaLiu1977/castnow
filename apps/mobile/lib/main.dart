import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerdart/peerdart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- Constants & Theme ---
const Color kBackgroundColor = Color(0xFF020617);
const Color kSurfaceColor = Color(0xFF0F172A);
const Color kPrimaryColor = Color(0xFFF59E0B);
const Color kTextPrimary = Color(0xFFF8FAFC);
const Color kTextSecondary = Color(0xFF94A3B8);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CastNowApp());
}

class CastNowApp extends StatelessWidget {
  const CastNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'CastNow Native',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBackgroundColor,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryColor,
          surface: kSurfaceColor,
        ),
        fontFamily: 'Roboto', 
      ),
      home: const HomeScreen(),
    );
  }
}

// --- Home Screen ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPro = false;
  String? _licenseKey;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _loadProStatus();
  }

  Future<void> _loadProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPro = prefs.getBool('is_pro') ?? false;
      _licenseKey = prefs.getString('license_key');
    });
  }

  Future<void> _saveProStatus(bool status, String? key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro', status);
    if (key != null) await prefs.setString('license_key', key);
    setState(() {
      _isPro = status;
      _licenseKey = key;
    });
  }

  Future<void> _verifyLicense(String key) async {
    if (key.isEmpty) return;
    setState(() => _isVerifying = true);
    
    try {
      final response = await http.post(
        Uri.parse('https://castnow.vercel.app/api/verify-pass'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'licenseKey': key}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          await _saveProStatus(true, key);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Activation Successful! Enjoy CastNow Pro."), backgroundColor: Colors.green),
            );
            Navigator.pop(context); // Close dialog
          }
        } else {
          throw Exception(data['message'] ?? 'Invalid license key');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Activation Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _showInfoDialog(BuildContext context, String title, String content, {String? url}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(content, style: const TextStyle(color: kTextSecondary))),
        actions: [
          if (url != null)
            TextButton(
              onPressed: () => _launchURL(url),
              child: const Text("VIEW ON GITHUB", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showProDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kSurfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: EdgeInsets.zero,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.black, size: 48),
                      SizedBox(height: 12),
                      Text("CastNow Pro", style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildProFeature(Icons.timer_off_rounded, "Unlimited Session Time"),
                    const SizedBox(height: 12),
                    _buildProFeature(Icons.event_available_rounded, "7-Day Activation Pass"),
                    const SizedBox(height: 12),
                    _buildProFeature(Icons.speed_rounded, "Priority P2P Tunneling"),
                    const SizedBox(height: 24),

                      if (!_isPro) ...[
                        TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: "Enter Activation Code",
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          style: const TextStyle(color: kPrimaryColor),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : () => _verifyLicense(_controller.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isVerifying 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text("ACTIVATE NOW", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text("OR", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _launchURL("https://minghster.gumroad.com/l/ihhtg"),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kPrimaryColor),
                            foregroundColor: kPrimaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("BUY ON GUMROAD", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (_isPro) ...[
                        const SizedBox(height: 24),
                        const Text("✓ PRO ACTIVATED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: kPrimaryColor, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: kTextPrimary, fontSize: 14))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    Widget brandSection = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // P2P Badge like App.vue
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text("P2P SECURE", style: TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Logo Area
        Container(
          width: isLandscape ? 60 : 80,
          height: isLandscape ? 60 : 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF020617)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(isLandscape ? 18 : 24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                  color: kPrimaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Icon(Icons.bolt_rounded,
              color: kPrimaryColor, size: isLandscape ? 36 : 48),
        ),
        SizedBox(height: isLandscape ? 12 : 24),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            children: [
              TextSpan(text: 'Cast'),
              TextSpan(text: 'Now', style: TextStyle(color: kPrimaryColor)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Native P2P Screen Sharing",
          style: TextStyle(color: kTextSecondary, letterSpacing: 1.2),
        ),
      ],
    );

    Widget actionsSection = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            context,
            title: "Broadcast",
            subtitle: "Share camera or screen",
            icon: Icons.wifi_tethering,
            color: kPrimaryColor,
            textColor: Colors.black,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => BroadcastScreen(isPro: _isPro))),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            context,
            title: "Receive",
            subtitle: "Watch a stream",
            icon: Icons.download_rounded,
            color: kSurfaceColor,
            textColor: kTextPrimary,
            isOutlined: true,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReceiveScreen())),
          ),
        ],
      ),
    );

    Widget footerSection = Padding(
      padding: EdgeInsets.only(top: isLandscape ? 32 : 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFooterLink(context, "SOURCE", "Source Code", "The source code for CastNow is available on GitHub under the MIT license.", url: "https://github.com/MinghuaLiu1977/castnow"),
              if (!isLandscape) const SizedBox(width: 32),
              if (isLandscape) const SizedBox(width: 24),
              _buildFooterLink(context, "PRIVACY", "Privacy Policy", "We value your privacy. CastNow utilizes direct peer-to-peer connections. Your stream data never touches our servers. We do not collect or store any personal information."),
              if (!isLandscape) const SizedBox(width: 32),
              if (isLandscape) const SizedBox(width: 24),
              _buildFooterLink(context, "TERMS", "Terms of Service", "By using CastNow, you agree that you are responsible for the content you share. The service is provided 'as is' without warranties of any kind."),
              if (isLandscape) ...[
                const SizedBox(width: 24),
                const Text(
                  "EASTLAKE STUDIO",
                  style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ],
          ),
          if (!isLandscape) ...[
            const SizedBox(height: 16),
            const Text(
              "MADE BY EASTLAKE STUDIO",
              style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top padding to help centering
                          if (isLandscape) const SizedBox(height: 1),
                          if (!isLandscape) const SizedBox(height: 40),

                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              isLandscape
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(child: brandSection),
                                        const SizedBox(width: 40),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              actionsSection,
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        brandSection,
                                        const SizedBox(height: 60),
                                        actionsSection,
                                      ],
                                    ),
                            ],
                          ),

                          footerSection,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Floating PRO Button
          Positioned(
            top: MediaQuery.of(context).padding.top + (isLandscape ? 12 : 20),
            left: isLandscape ? 32 : 24, // Moved to left
            child: GestureDetector(
              onTap: () => _showProDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 10)],
                ),
                child: Text(_isPro ? "PRO ACTIVE" : "GET PRO", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(BuildContext context, String label, String title, String content, {String? url}) {
    return GestureDetector(
      onTap: () => _showInfoDialog(context, title, content, url: url),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required Color textColor,
      required VoidCallback onTap,
      bool isOutlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: isOutlined ? Border.all(color: Colors.white12) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOutlined ? Colors.white.withOpacity(0.05) : Colors.black12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: textColor, size: 28),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: textColor.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: textColor.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}

// --- Broadcast Screen (Sender) ---
class BroadcastScreen extends StatefulWidget {
  final bool isPro;
  const BroadcastScreen({super.key, this.isPro = false});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  Peer? _peer;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  String? _peerId;
  bool _isScreenSharing = false;
  
  bool _isBroadcasting = false;
  Timer? _sessionTimer;
  int _remainingSeconds = 1800; // 30 minutes
  Timer? _countdownTimer;
  final List<DataConnection> _connections = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initRenderer();
    WakelockPlus.enable();
    
    // Start Countdown for Free Users
    if (!widget.isPro) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _stopBroadcast();
      }
    });
  }

  String _formatDuration(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }


  Future<void> _initRenderer() async {
    await _localRenderer.initialize();
    
    // Listen for native stop signal (from notification)
    const channel = MethodChannel('media_projection');
    channel.setMethodCallHandler((call) async {
      debugPrint("📢 Received MethodChannel call: ${call.method}");
      if (call.method == "onStopPressed") {
        debugPrint("🛑 Native STOP signal received. Navigating back.");
        _stopBroadcast();
      }
    });

    if (mounted) setState(() {});
  }

  bool _isStopping = false;

  void _stopBroadcast() {
    if (!mounted || _isStopping) return;
    _isStopping = true;

    _sessionTimer?.cancel();
    _sessionTimer = null;

    // 1. Close Peer & Connections
    _peer?.dispose();
    _peer = null;

    // 2. Stop Service (Native notification)
    const MethodChannel('media_projection').invokeMethod('stopMediaProjectionService');

    // 3. Cleanup local state
    _localStream?.dispose();
    _localStream = null;
    _localRenderer.srcObject = null;

    if (mounted) {
      if (Navigator.canPop(context)) {
         Navigator.of(context).pop();
      }
      
      // Optional: Reset state if not popped (shouldn't happen if pushed correctly)
      setState(() {
        _isBroadcasting = false;
        _peerId = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _startBroadcast(bool isScreen) async {
    setState(() => _isLoading = true);
    try {
      // 1. Generate 6-digit access key
      final code = (100000 + math.Random().nextInt(900000)).toString();

      // 2. Acquire media stream FIRST
      Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': isScreen
            ? true 
            : {
                'facingMode': 'user',
                'width': 1280,
                'height': 720
              }
      };


      if (isScreen) {
        // 跨平台屏幕共享逻辑
        if (kIsWeb || Platform.isAndroid || Platform.isMacOS || Platform.isWindows) {
          if (Platform.isAndroid) {
            // 1. 检查当前状态
            var status = await Permission.notification.status;
              
            if (status.isDenied) {
              status = await Permission.notification.request();
              // 🛑 CRITICAL FIX: After system permission dialog closes, Activity might be in proper resume cycle.
              // Starting Foreground Service immediately can crash (Background Service Start Restriction).
              // Wait for 1s to ensure App is recognized as "Foreground" and permission is synced.
              if (status.isGranted) {
                  debugPrint("✅ Notification permission granted. Waiting for system sync...");
                  await Future.delayed(const Duration(milliseconds: 500));
              }
            }

            // 🛑 核心拦截点 🛑
            // 如果此时还是没授权（可能是用户拒绝，也可能是 manifest 缓存问题）
            if (!status.isGranted) {
              debugPrint("❌ 致命错误：没有通知权限，前台服务无法启动！");
              
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("权限缺失"),
                    content: const Text("检测到通知权限缺失。\n\nAndroid 系统要求：开启录屏必须先授予通知权限。\n\n请检查：\n1. 是否已卸载重装 App？\n2. 请去设置中手动开启权限。"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          openAppSettings(); // 引导去设置
                        },
                        child: const Text("去设置"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("取消"),
                      ),
                    ],
                  ),
                );
              }
            // ⛔️ 绝对不能继续，否则必崩 ⛔️
            setState(() => _isLoading = false);
            return;
    
           
            }
          }
          const channel = MethodChannel('media_projection');

          // 1. Start Media Projection Service
          // The native code will handle the Android 14 bridge/polling automatically.
          debugPrint("🚀 Starting media projection service...");
          await channel.invokeMethod('startMediaProjectionService', {
            'type': 'mediaProjection',
            'code': code,
          });

          //await Future.delayed(const Duration(milliseconds: 1500));

          
          // 2. Request Screen Capture (Plugin's native prompt)
          debugPrint("📸 Requesting screen capture permission...");
          _localStream = await navigator.mediaDevices.getDisplayMedia({
            'audio': false
          });
          debugPrint("✅ Screen capture stream acquired successfully.");

          // 3. Listen for "Stop" from System UI
          // When user clicks "Stop sharing" in notification panel, this fires.
          var videoTrack = _localStream!.getVideoTracks()[0];
          videoTrack.onEnded = () {
             debugPrint("📷 MEDIA TRACK ENDED: System 'Stop' button clicked.");
             _stopBroadcast();
          };
          
          videoTrack.onMute = () {
             debugPrint("🔇 MEDIA TRACK MUTED: Stream paused or stopped sending frames.");
             // Optional: If muted for extensive time, could treat as stop.
          };

          // 4. Listen for track removal (common in some implementations)
          _localStream!.onRemoveTrack = (track) {
             debugPrint("👋 TRACK REMOVED from stream. Triggering termination.");
             _stopBroadcast();
          };

          // --- Session Lifecycle: Detect system stop ---
          for (var track in _localStream!.getTracks()) {
            track.onEnded = () {
              debugPrint("🎥 [${track.kind}] system signal: track.onEnded triggered.");
              _stopBroadcast();
            };
          }
      } else if (Platform.isIOS) {
          // System-wide sharing requires a Broadcast Extension (not yet implemented)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("iOS Screen sharing requires Broadcast Extension."),
            backgroundColor: Colors.red,
          ));
          setState(() => _isLoading = false);
          return;
        }
      } else {
        // Camera source
        if (!kIsWeb) {
          await Permission.camera.request();
          await Permission.microphone.request();
        }
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      }

      _localRenderer.srcObject = _localStream;
      _isScreenSharing = isScreen;

      // 3. Initialize Peer AFTER stream is acquired
      final peer = Peer(id: code, options: PeerOptions(debug: LogLevel.All));
      _peer = peer;

      // 3. Setup signaling
      peer.on("open").listen((id) {
        if (!mounted) return;
        setState(() {
          _peerId = id;

          _isLoading = false;
          
          // Start Session Limit Timer for Free Users
          if (!widget.isPro) {
            _sessionTimer = Timer(const Duration(minutes: 30), () {
              if (mounted && _isBroadcasting) {
                _stopBroadcast();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Free session limited to 30 minutes. Please reconnect or upgrade to Pro."),
                    duration: Duration(seconds: 5),
                  )
                );
              }
            });
          }
        });
      });


      _peer!.on("connection").listen((conn) {
        _connections.add(conn);
        _isBroadcasting = true;
        // Auto-minimize app after receiver connects (Android Screen Share only)
        if (_isScreenSharing && !kIsWeb && Platform.isAndroid) {
          const _channel = MethodChannel('media_projection');
          _channel.invokeMethod('minimizeApp');
        }

        // Active call to receiver
        if (_localStream != null) {
          _peer!.call(conn.peer, _localStream!);
        }
      });

      setState(() {});

    } catch (e) {
      debugPrint("Error starting broadcast: $e");
      
      // Attempt to clean up native service if it was started
      try {
        const channel = MethodChannel('media_projection');
        await channel.invokeMethod('stopMediaProjectionService');
      } catch (_) {}

      if (mounted) {
        // Reset state so we stay on the selection screen
        setState(() {
          _isLoading = false;
          _peerId = null;
          _peer = null;
        });

        // Only show error if it's not a user cancellation
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('cancel') && 
            !errorStr.contains('denied') && 
            !errorStr.contains('user_rejected') && 
            !errorStr.contains('give permission')) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        } else {
          debugPrint("User cancelled or denied permission. Returning to selection.");
        }

      }
    }
  }

  void _switchCamera() async {
    if (_localStream != null && !_isScreenSharing) {
       final videoTrack = _localStream!.getVideoTracks().first;
       await Helper.switchCamera(videoTrack);
    }
  }


  @override
  void dispose() {
    debugPrint("🧹 Disposing BroadcastScreenState");
    _countdownTimer?.cancel();
    _sessionTimer?.cancel();
    _stopBroadcast();
    WakelockPlus.disable();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (_peerId == null && !_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Choose Source"), 
          centerTitle: true, 
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _remainingSeconds < 300 ? Colors.red.withOpacity(0.1) : Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _remainingSeconds < 300 ? Colors.redAccent.withOpacity(0.5) : Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, color: _remainingSeconds < 300 ? Colors.redAccent : Colors.red.withOpacity(0.5), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        widget.isPro 
                          ? "UNLIMITED SESSION" 
                          : (_remainingSeconds < 300 ? "ENDING IN ${_formatDuration(_remainingSeconds)}" : "FREE SESSION: 30M LIMIT"),
                        style: TextStyle(
                          color: _remainingSeconds < 300 ? Colors.redAccent : Colors.red.withOpacity(0.7), 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                isLandscape 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: _buildSourceBtn(Icons.phone_android, "Screen Share", () => _startBroadcast(true), isLandscape)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildSourceBtn(Icons.camera_alt, "Camera", () => _startBroadcast(false), isLandscape)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         _buildSourceBtn(Icons.phone_android, "Screen Share", () => _startBroadcast(true), isLandscape),
                         const SizedBox(height: 20),
                         _buildSourceBtn(Icons.camera_alt, "Camera", () => _startBroadcast(false), isLandscape),
                      ],
                    ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          Icon(Icons.circle, color: _isScreenSharing ? Colors.blue : Colors.red, size: 12),
                          const SizedBox(width: 8),
                          Text(_isScreenSharing ? "SHARING SCREEN" : "ON AIR", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context), 
                        icon: const Icon(Icons.close, color: Colors.white)
                      )
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Constrained Video Preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isLandscape ? 400 : double.infinity,
                      maxHeight: isLandscape ? 200 : 300,
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _localStream != null 
                          ? RTCVideoView(_localRenderer, mirror: !_isScreenSharing, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover) 
                          : Container(),
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Code Display
                if (_peerId != null)
                  Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kSurfaceColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("SHARING ACCESS KEY", style: TextStyle(color: kTextSecondary, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _peerId!.split('').map((char) => Container(
                            width: 36, height: 48,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kPrimaryColor.withOpacity(0.5))
                            ),
                            child: Text(char, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                          )).toList(),
                        ),
                        const SizedBox(height: 20),
                        if (!_isScreenSharing)
                          TextButton.icon(
                            onPressed: _switchCamera,
                            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                            label: const Text("Switch Camera", style: TextStyle(color: Colors.white)),
                          ),
                        if (!widget.isPro && _remainingSeconds < 300) ...[
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "SESSION ENDS IN: ${_formatDuration(_remainingSeconds)}",
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _stopBroadcast,
                            icon: const Icon(Icons.stop_circle_rounded, color: Colors.white),
                            label: const Text("TERMINATE STREAM", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.2),
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.redAccent.withOpacity(0.3))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (_isLoading)
              Container(color: Colors.black87, child: const Center(child: CircularProgressIndicator(color: kPrimaryColor))),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBtn(IconData icon, String label, VoidCallback onTap, bool isLandscape) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: isLandscape ? null : 280,
        constraints: const BoxConstraints(maxWidth: 320),
        padding: EdgeInsets.all(isLandscape ? 32 : 40),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isLandscape ? 48 : 56, color: kPrimaryColor),
            const SizedBox(height: 16),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
          ],
        ),
      ),
    );
  }
}

// --- Receive Screen (Viewer) ---
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final TextEditingController _codeController = TextEditingController();
  Peer? _peer;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isConnecting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _peer?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // Receiver also requires ICE configuration for successful P2P traversal
  Map<String, dynamic> _getIceServerConfig() {
     return {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun.cloudflare.com:3478'},
        {'urls': 'stun:stun.miwifi.com:3478'},
        {'urls': 'stun:stun.cdn.aliyun.com:3478'},
      ]
    };
  }

  void _joinStream() {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() => _isConnecting = true);
    
    final peer = Peer(
      options: PeerOptions(
        debug: LogLevel.All,
        config: _getIceServerConfig()
      )
    );
    _peer = peer;

    peer.on("open").listen((id) {
      final conn = peer.connect(code);
      
      conn.on("open").listen((_) {
        debugPrint("Connected to broadcaster signaling");
      });

      conn.on("close").listen((_) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Broadcast ended")));
           Navigator.pop(context);
         }
      });
    });

    peer.on("call").listen((mediaConnection) {
      debugPrint("Received call from ${mediaConnection.peer}");
      
      // --- WebRTC Debug Logs ---
      mediaConnection.peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint("🔥 [手机端 ICE 状态]: ${state.toString()}");
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          debugPrint("❌ 警告：打洞失败，请检查代理设置或 STUN/TURN 服务器");
        }
      };

      mediaConnection.peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        debugPrint("🏠 [手机端候选地址]: ${candidate.candidate}");
      };
      
      // Answer the call (no stream sent back)
      mediaConnection.answer(null);
      mediaConnection.on("stream").listen((stream) {
        debugPrint("Received remote stream: ${stream.id}");
        debugPrint("Video tracks: ${stream.getVideoTracks().length}");
        if (stream.getVideoTracks().isNotEmpty) {
           debugPrint("Video track enabled: ${stream.getVideoTracks().first.enabled}");
        }
        
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isConnected = true;
          _isConnecting = false;
        });
      });

      mediaConnection.on("close").listen((_) {
        debugPrint("Media connection closed");
        setState(() {
          _isConnected = false;
          _remoteRenderer.srcObject = null;
        });
      });

      mediaConnection.on("error").listen((e) {
        debugPrint("Media connection error: $e");
      });
    });

    peer.on("error").listen((err) {
      debugPrint("Peer Error: $err");
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Failed. Check code.")));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            RTCVideoView(
               _remoteRenderer, 
               objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
            ),
            Positioned(
              top: 40, left: 20,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      );
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(title: const Text("Join Stream"), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "FREE SESSION: 30M LIMIT",
                          style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text("ENTER ACCESS KEY", style: TextStyle(color: kTextSecondary, letterSpacing: 3, fontSize: 10, fontWeight: FontWeight.bold)),

                     const SizedBox(height: 24),
                     ConstrainedBox(
                       constraints: const BoxConstraints(maxWidth: 400),
                       child: TextField(
                         controller: _codeController,
                         textAlign: TextAlign.center,
                         keyboardType: TextInputType.number,
                         maxLength: 6,
                         style: TextStyle(
                           fontSize: isLandscape ? 32 : 48, 
                           fontWeight: FontWeight.w900, 
                           color: kPrimaryColor, 
                           letterSpacing: isLandscape ? 4 : 8
                         ),
                         decoration: InputDecoration(
                           counterText: "",
                           filled: true,
                           fillColor: kSurfaceColor,
                           contentPadding: EdgeInsets.symmetric(vertical: isLandscape ? 12 : 24),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                           hintText: "000000",
                           hintStyle: TextStyle(color: kSurfaceColor.withBlue(40)),
                         ),
                       ),
                     ),
                     const SizedBox(height: 40),
                     ConstrainedBox(
                       constraints: const BoxConstraints(maxWidth: 400),
                       child: SizedBox(
                         width: double.infinity,
                         height: 60,
                         child: ElevatedButton(
                           onPressed: _isConnecting ? null : _joinStream,
                           style: ElevatedButton.styleFrom(
                             backgroundColor: kPrimaryColor,
                             foregroundColor: Colors.black,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                           ),
                           child: _isConnecting 
                             ? const CircularProgressIndicator(color: Colors.black)
                             : const Text("CONNECT NOW", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                         ),
                       ),
                     )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
