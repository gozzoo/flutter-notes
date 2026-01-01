import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_notes/main.dart';

void main() {
  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    await Hive.openBox('notes');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('App starts and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Flutter notes'), findsOneWidget);
  });
}
