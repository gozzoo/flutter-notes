import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await WindowsSingleInstance.ensureSingleInstance(
    args,
    "flutter_notes",
    onSecondWindow: (args) async {
      // This code runs in the ALREADY OPEN instance
      await windowManager.show();
      await windowManager.focus();
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
    },
  );

  await StorageService.init();
  await windowManager.ensureInitialized();
  await StorageService.restoreWindowBounds();

  runApp(const FlutterNotesApp());
}

class FlutterNotesApp extends StatelessWidget {
  const FlutterNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeScreen(title: 'Flutter notes'),
    );
  }
}
