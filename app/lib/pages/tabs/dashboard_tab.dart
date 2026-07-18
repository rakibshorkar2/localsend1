import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('ios-delegate-channel');

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Timer? _timer;
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchStats();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final Map<dynamic, dynamic>? data = await _channel.invokeMethod('getSystemStats');
      if (data != null && mounted) {
        setState(() {
          _stats = Map<String, dynamic>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch system stats: $e");
    }
  }

  String _formatBytes(double bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    final cpu = _stats?['cpuUsage'] as double? ?? 0.0;
    
    final ramTotal = _stats?['ramTotal'] as double? ?? 1.0;
    final ramUsed = _stats?['ramUsed'] as double? ?? 0.0;
    final ramRatio = (ramUsed / ramTotal).clamp(0.0, 1.0);

    final storageTotal = (_stats?['storageTotal'] as num?)?.toDouble() ?? 1.0;
    final storageUsed = (_stats?['storageUsed'] as num?)?.toDouble() ?? 0.0;
    final storageRatio = (storageUsed / storageTotal).clamp(0.0, 1.0);

    final gpuName = _stats?['gpuName'] as String? ?? 'Apple GPU';
    final deviceName = _stats?['deviceName'] as String? ?? 'iOS Device';
    final systemVersion = _stats?['systemVersion'] as String? ?? 'iOS';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            _buildGlassCard(
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.developer_board, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deviceName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            systemVersion,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // CPU & RAM Grid
            Row(
              children: [
                Expanded(
                  child: _buildGlassCard(
                    isDark: isDark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        children: [
                          const Text(
                            "CPU",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            width: 100,
                            child: CustomPaint(
                              painter: CircularGaugePainter(
                                value: cpu / 100.0,
                                colors: [Colors.purpleAccent, Colors.deepPurple],
                              ),
                              child: Center(
                                child: Text(
                                  "${cpu.toStringAsFixed(1)}%",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "System Load",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGlassCard(
                    isDark: isDark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        children: [
                          const Text(
                            "RAM",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            width: 100,
                            child: CustomPaint(
                              painter: CircularGaugePainter(
                                value: ramRatio,
                                colors: [Colors.cyanAccent, Colors.blueAccent],
                              ),
                              child: Center(
                                child: Text(
                                  "${(ramRatio * 100).toStringAsFixed(0)}%",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "${_formatBytes(ramUsed)} / ${_formatBytes(ramTotal)}",
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Storage Section
            _buildGlassCard(
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Storage Space",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${(storageRatio * 100).toStringAsFixed(1)}% Used",
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: storageRatio,
                        minHeight: 12,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Used: ${_formatBytes(storageUsed)}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          "Free: ${_formatBytes(storageTotal - storageUsed)}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // GPU & Metal Card
            _buildGlassCard(
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.flash_on, color: Colors.greenAccent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Graphics Engine (GPU)",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            gpuName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Metal API Supported",
                            style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
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

  Widget _buildGlassCard({required Widget child, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CircularGaugePainter extends CustomPainter {
  final double value; // 0.0 to 1.0
  final List<Color> colors;

  CircularGaugePainter({required this.value, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 8;
    const strokeWidth = 8.0;

    // Track path (circle background)
    final trackPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;

    // Value Arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final valuePaint = Paint()
      ..shader = SweepGradient(
        colors: colors,
        stops: const [0.0, 1.0],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * value,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.colors != colors;
  }
}
