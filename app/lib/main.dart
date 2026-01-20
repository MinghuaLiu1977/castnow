
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerdart/peerdart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF020617)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                        color: kPrimaryColor.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: kPrimaryColor, size: 48),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 60),

              _buildActionButton(
                context,
                title: "Broadcast",
                subtitle: "Share camera or screen",
                icon: Icons.wifi_tethering,
                color: kPrimaryColor,
                textColor: Colors.black,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BroadcastScreen())),
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
        ),
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
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  Peer? _peer;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  String? _peerId;
  bool _isScreenSharing = false;
  final List<DataConnection> _connections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initRenderer();
    WakelockPlus.enable();
  }

  Future<void> _initRenderer() async {
    await _localRenderer.initialize();
  }

  // --- 关键修改：提供 robust 的 ICE Servers ---
  Map<String, dynamic> _getIceServerConfig() {
    return {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun.cloudflare.com:3478'},
        {'urls': 'stun:stun.miwifi.com:3478'}, // China Optimized
        {'urls': 'stun:stun.cdn.aliyun.com:3478'}, // China Optimized
      ],
      'sdpSemantics': 'unified-plan'
    };
  }

  Future<void> _startBroadcast(bool isScreen) async {
    setState(() => _isLoading = true);
    try {
      final code = (100000 + Random().nextInt(900000)).toString();

      // 初始化 Peer 时注入 config
      final peer = Peer(
        id: code, 
        options: PeerOptions(
          debug: LogLevel.All,
          config: _getIceServerConfig(), 
        )
      );
      
      _peer = peer;

      _peer!.on("open").listen((id) {
        if (!mounted) return;
        setState(() {
          _peerId = id;
          _isLoading = false;
        });
      });

      _peer!.on("connection").listen((conn) {
        _connections.add(conn);
        if (_localStream != null) {
          _peer!.call(conn.peer, _localStream!);
        }
      });

      // 获取媒体流
      if (isScreen) {
        if (Platform.isAndroid) {
          // Android 原生屏幕共享
          // 注意：必须在 AndroidManifest 中注册 WebrtcMediaProjectionService
          _localStream = await navigator.mediaDevices.getDisplayMedia({
              'video': true, 
              'audio': true
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("iOS Screen sharing requires Broadcast Extension."),
            backgroundColor: Colors.red,
          ));
          setState(() => _isLoading = false);
          return;
        }
      } else {
        // 摄像头
        await Permission.camera.request();
        await Permission.microphone.request();
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'user',
            'width': 1280,
            'height': 720
          }
        });
      }

      _localRenderer.srcObject = _localStream;
      _isScreenSharing = isScreen;
      setState(() {});

    } catch (e) {
      debugPrint("Error starting broadcast: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
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
    _localStream?.dispose();
    _localRenderer.dispose();
    _peer?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_peerId == null && !_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Choose Source"), centerTitle: true, backgroundColor: Colors.transparent),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               _buildSourceBtn(Icons.mobile_screen_share, "Screen Share", () => _startBroadcast(true)),
               const SizedBox(height: 20),
               _buildSourceBtn(Icons.camera_alt, "Camera", () => _startBroadcast(false)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.black,
            child: _localStream != null 
              ? RTCVideoView(_localRenderer, mirror: !_isScreenSharing, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover) 
              : Container(),
          ),
          
          SafeArea(
            child: Column(
              children: [
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
                          )
                        else
                          const Text("You are sharing your screen", style: TextStyle(color: Colors.white54, fontSize: 12))
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (_isLoading)
            Container(color: Colors.black87, child: const Center(child: CircularProgressIndicator(color: kPrimaryColor))),
        ],
      ),
    );
  }

  Widget _buildSourceBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: kPrimaryColor),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold))
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

  // --- 关键修改：Receive 模式也需要 ICE 配置 ---
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
      mediaConnection.answer(null);
      mediaConnection.on("stream").listen((stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isConnected = true;
          _isConnecting = false;
        });
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

    return Scaffold(
      appBar: AppBar(title: const Text("Join Stream"), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const Text("ENTER ACCESS KEY", style: TextStyle(color: kTextSecondary, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
             const SizedBox(height: 24),
             TextField(
               controller: _codeController,
               textAlign: TextAlign.center,
               keyboardType: TextInputType.number,
               maxLength: 6,
               style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 8),
               decoration: InputDecoration(
                 counterText: "",
                 filled: true,
                 fillColor: kSurfaceColor,
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                 hintText: "000000",
                 hintStyle: TextStyle(color: kSurfaceColor.withBlue(40)),
               ),
             ),
             const SizedBox(height: 40),
             SizedBox(
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
             )
          ],
        ),
      ),
    );
  }
}
