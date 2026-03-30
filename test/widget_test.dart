import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apporbit/main.dart'; // Make sure this path matches your actual main file

void main() {
  testWidgets('AppOrbit launches without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // We removed the default counter, so let's just make sure the core app wrapper loads!
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}