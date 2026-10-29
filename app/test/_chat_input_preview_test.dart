import 'dart:io';

import 'package:app/ai/ai_chat_input.dart';
import 'package:app/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Throwaway visual preview. Run with:
//   fvm flutter test --update-goldens test/_chat_input_preview_test.dart

Future<void> _loadAssetFont(String family, String path) async {
  try {
    final loader = FontLoader(family)..addFont(rootBundle.load(path));
    await loader.load();
  } catch (_) {}
}

Future<void> _loadFileFont(String family, String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  } catch (_) {}
}

void main() {
  testWidgets('preview', (tester) async {
    await _loadAssetFont('Source Sans 3', 'assets/fonts/SourceSans3.ttf');
    await _loadAssetFont('Fraunces', 'assets/fonts/Fraunces.ttf');
    await _loadFileFont(
      'MaterialIcons',
      '/Users/alann/fvm/versions/3.47.5/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );

    final empty = TextEditingController();
    final typed = TextEditingController(text: 'Make the tone warmer and mention my 2010 onset');
    final busy = TextEditingController(text: 'Add that the ringing is constant');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 460,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AiChatInput(controller: empty, maxLength: 500, onSend: (_) {}),
                    const SizedBox(height: 24),
                    AiChatInput(controller: typed, maxLength: 500, onSend: (_) {}),
                    const SizedBox(height: 24),
                    AiChatInput(controller: busy, maxLength: 500, busy: true, onSend: (_) {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField).at(1));
    await tester.pump(const Duration(milliseconds: 250));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('chat_input_preview.png'),
    );

    empty.dispose();
    typed.dispose();
    busy.dispose();
  });
}
