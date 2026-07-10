import 'dart:async';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import '../utils/storage_util.dart';
import 'chat_screen.dart';
import 'register_screen.dart';

class WaitingScreen extends StatefulWidget {
  final String serverToken;

  const WaitingScreen({Key? key, required this.serverToken}) : super(key: key);

  @override
  _WaitingScreenState createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> with TickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _particleController;
  late AnimationController _progressController;
  
  bool _isInitialLoading = true;
  bool _isExtendedWait = false;
  
  int _totalMinutes = 30;
  DateTime? _startTime;
  
  String _typedKeys = '';

  @override
  void initState() {
    super.initState();
    
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _progressController = AnimationController(vsync: this, duration: const Duration(minutes: 30));
    
    _initAndCheck();
  }
  
  Future<void> _initAndCheck() async {
    // Check status first to prevent timer flicker
    String status = await ApiService.checkStatus(widget.serverToken);
    if (!mounted) return;
    
    if (status == "granted") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(serverToken: widget.serverToken)),
      );
      return;
    } else if (status == "deleted") {
      await StorageUtil.setServerToken('');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RegisterScreen()),
      );
      return;
    }

    // Still waiting
    await _initTimer();
    
    setState(() {
      _isInitialLoading = false;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkStatus();
      _updateProgress();
    });
  }

  Future<void> _initTimer() async {
    String? startStr = await StorageUtil.getWaitingStart();
    if (startStr == null) {
      _startTime = DateTime.now();
      await StorageUtil.setWaitingStart(_startTime!.toIso8601String());
    } else {
      _startTime = DateTime.tryParse(startStr) ?? DateTime.now();
    }
    _updateProgress();
  }
  
  void _updateProgress() {
    if (_startTime == null) return;
    
    final elapsed = DateTime.now().difference(_startTime!);
    
    if (!_isExtendedWait && elapsed.inMinutes >= 30) {
      setState(() {
        _isExtendedWait = true;
        _totalMinutes = 24 * 60; // 24 hours
        _progressController.duration = Duration(minutes: _totalMinutes);
      });
    }
    
    double startValue = elapsed.inSeconds / (_totalMinutes * 60);
    if (startValue < 0 || startValue > 1) startValue = 0;
    
    _progressController.value = startValue;
    if (!_progressController.isAnimating) {
      _progressController.forward();
    }
  }

  Future<void> _checkStatus() async {
    String status = await ApiService.checkStatus(widget.serverToken);
    if (!mounted) return;
    
    if (status == "granted") {
      _timer?.cancel();
      // Send notification if permitted
      if (html.Notification.permission == 'granted') {
        html.Notification('MilkyCloud Gemini', body: 'Ваш ключ успешно назначен! Вы можете начать чат.');
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(serverToken: widget.serverToken)),
      );
    } else if (status == "deleted") {
      _timer?.cancel();
      await StorageUtil.setServerToken('');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RegisterScreen()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _particleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (_isExtendedWait) {
      String hours = twoDigits(duration.inHours);
      String minutes = twoDigits(duration.inMinutes.remainder(60));
      return "$hours:$minutes";
    }
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _requestNotification() {
    html.Notification.requestPermission().then((permission) {
      if (permission == 'granted') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Уведомления включены! Мы сообщим вам, когда доступ будет открыт.')),
        );
      }
    });
  }
  
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey.keyLabel.toLowerCase();
      if (key.length == 1) {
        _typedKeys += key;
        if (_typedKeys.length > 10) {
          _typedKeys = _typedKeys.substring(_typedKeys.length - 10);
        }
        
        if (_typedKeys.endsWith('demo')) {
          _typedKeys = '';
          _activateDemo();
        } else if (_typedKeys.endsWith('self')) {
          _typedKeys = '';
          _showCustomTokenDialog();
        }
      }
    }
  }
  
  void _activateDemo() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Активация демо режима...')),
    );
    bool success = await ApiService.activateDemo(widget.serverToken);
    if (success) {
      _checkStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка активации демо.')),
      );
    }
  }
  
  void _showCustomTokenDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E20),
        title: const Text('Свой токен', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Введите ваш Gemini API Key',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                bool success = await ApiService.assignCustomToken(widget.serverToken, controller.text.trim());
                if (success) _checkStatus();
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF131314),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6B8AFF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: _handleKeyEvent,
        child: Stack(
          children: [
            // Background particles
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ParticlePainter(animationValue: _particleController.value),
                  );
                },
              ),
            ),
            
            // Main content
            Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E20).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)
                  ],
                ),
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Spinning icon
                    RotationTransition(
                      turns: _particleController,
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF4285F4), Color(0xFF9B72CB), Color(0xFFD96570)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 80),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Ожидание ключа Gemini...',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _isExtendedWait 
                        ? 'В целях безопасности регистрация требует дополнительной проверки. Обычно подтверждение не занимает более суток.'
                        : 'Система скоро назначит вам новый ключ',
                      style: TextStyle(
                        color: _isExtendedWait ? Colors.orangeAccent : Colors.grey, 
                        fontSize: _isExtendedWait ? 14 : 16, 
                        height: 1.5
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    if (_isExtendedWait) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Получить уведомление'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _requestNotification,
                      ),
                      const SizedBox(height: 30),
                    ],
                    
                    // Progress bar
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        double remainingPercent = 1.0 - _progressController.value;
                        Duration remainingTime = Duration(seconds: ((_totalMinutes * 60) * remainingPercent).toInt());
                        
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Осталось', style: TextStyle(color: Colors.grey, fontSize: 14)),
                                Text(
                                  _formatDuration(remainingTime),
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: max(0.01, remainingPercent),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4285F4), Color(0xFF9B72CB), Color(0xFFD96570)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF9B72CB).withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final double animationValue;
  final int particleCount = 50;

  ParticlePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    Random r = Random(42);
    
    for (int i = 0; i < particleCount; i++) {
      double angle = r.nextDouble() * 2 * pi;
      double distance = r.nextDouble() * max(size.width, size.height);
      double speed = 0.2 + r.nextDouble() * 1.5;
      double radius = 1.0 + r.nextDouble() * 3.0;
      
      int colorType = r.nextInt(3);
      Color color;
      if (colorType == 0) color = const Color(0xFF4285F4);
      else if (colorType == 1) color = const Color(0xFF9B72CB);
      else color = const Color(0xFFD96570);
      
      double currentAngle = angle + (animationValue * 2 * pi * speed * (i % 2 == 0 ? 1 : -1));
      
      Offset position = Offset(
        center.dx + cos(currentAngle) * distance,
        center.dy + sin(currentAngle) * distance,
      );
      
      double pulse = sin(animationValue * 2 * pi * speed * 2) * 0.5 + 0.5;
      
      final paint = Paint()
        ..color = color.withOpacity(0.2 + 0.4 * pulse)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        
      canvas.drawCircle(position, radius + (pulse * 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
