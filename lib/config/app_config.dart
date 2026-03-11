import 'dart:convert';

import 'package:flutter/services.dart';

class AppConfig {
  static int loopCount = 10000;

  static Future<void> load() async {
    try {
      final String response = await rootBundle.loadString('assets/config.json');
      final data = await json.decode(response);

      loopCount = data['loopCount'] ?? 10000;

        print('⚙️ Config loaded: $data');
    } catch (e) {
        print('⚠️ Failed to load config, using defaults: $e');
    }
  }
}
