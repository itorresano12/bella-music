// lib/providers/kiosk_mode_provider.dart
//
// Counter Kiosk Mode Provider:
// Prevents accidental touch gestures on cash register / hospitality counters.
// Toggles screen touch absorption with a 3-second long-press unlock mechanism.

import 'package:flutter_riverpod/flutter_riverpod.dart';

class KioskModeNotifier extends StateNotifier<bool> {
  KioskModeNotifier() : super(false);

  void toggle() => state = !state;
  void lock() => state = true;
  void unlock() => state = false;
}

final kioskModeProvider = StateNotifierProvider<KioskModeNotifier, bool>((ref) {
  return KioskModeNotifier();
});

