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
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      builder: (context, child) => HttpDebugOverlay(child: child!),
      home: const GetStartedScreen(title: 'Get Started'),
    );
  }
}

