import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:apps_k24/pages/get_started_screen.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/services/notification_service.dart';
import 'package:apps_k24/widgets/http_debug_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await ApiService.init();
  } catch (e) {
    debugPrint('[Main] ApiService init error: $e');
  }

  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('[Main] NotificationService init error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K-24 Driver App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      builder: (context, child) {
        // On web: wrap inside phone frame simulator
        if (kIsWeb) {
          return _WebPhoneFrame(child: HttpDebugOverlay(child: child!));
        }
        return HttpDebugOverlay(child: child!);
      },
      home: const GetStartedScreen(title: 'Get Started'),
    );
  }
}

/// Phone frame simulator for Flutter Web development.
/// Wraps the app content in a centered 390x844px frame (iPhone 14 size)
/// with a realistic device border so you can see exactly how it looks on mobile.
class _WebPhoneFrame extends StatelessWidget {
  final Widget child;
  const _WebPhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    const double phoneWidth = 390;
    const double phoneHeight = 844;
    const double frameThickness = 14.0;
    const double cornerRadius = 48.0;
    const double notchWidth = 120.0;
    const double notchHeight = 32.0;

    // Total frame height including notch + home bar
    const double totalFrameHeight = phoneHeight + frameThickness * 2 + 20;
    const double totalFrameWidth = phoneWidth + frameThickness * 2;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Scale factor so the frame fits the browser window with padding
          final double availH = constraints.maxHeight - 60; // 60px for label + hint
          final double availW = constraints.maxWidth - 32;
          final double scaleH = availH / totalFrameHeight;
          final double scaleW = availW / totalFrameWidth;
          final double scale = (scaleH < scaleW ? scaleH : scaleW).clamp(0.3, 1.0);

          return Column(
            children: [
              // Label bar at top
              Container(
                height: 36,
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_android, color: Colors.white54, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'K-24 Driver App  —  Dev Preview',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Phone frame — scaled to fit
              Expanded(
                child: Center(
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: totalFrameWidth,
                      height: totalFrameHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(cornerRadius + frameThickness),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF3A3A4A), Color(0xFF1C1C28)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 60,
                              spreadRadius: 8,
                              offset: const Offset(0, 20),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.05),
                              blurRadius: 1,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(frameThickness),
                          child: Column(
                            children: [
                              // Dynamic Island / Notch
                              SizedBox(
                                height: notchHeight,
                                child: Center(
                                  child: Container(
                                    width: notchWidth,
                                    height: notchHeight - 6,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A0A0A),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF1A1A1A),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF252525),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // App content
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(cornerRadius - frameThickness),
                                  child: SizedBox(
                                    width: phoneWidth,
                                    child: child,
                                  ),
                                ),
                              ),

                              // Home indicator bar
                              SizedBox(
                                height: 28,
                                child: Center(
                                  child: Container(
                                    width: 120,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom hint
              Container(
                height: 24,
                alignment: Alignment.center,
                child: Text(
                  'r = Hot Reload 🔥   |   R = Hot Restart   |   q = Quit',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
