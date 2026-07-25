import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing option toggles, persisted across launches.
///
/// All optional features follow the same pattern: gameplay modifiers are
/// OFF-by-default opt-ins, and anything needing OS permissions asks only when
/// the feature is actually engaged (Balance Mode asks on the calibration tap,
/// never at install/launch).
class Settings extends ChangeNotifier {
  Settings._(this._prefs)
      : _balanceMode = _prefs.getBool(_kBalance) ?? false,
        _looseStack = _prefs.getBool(_kLooseStack) ?? false,
        _haptics = _prefs.getBool(_kHaptics) ?? true;

  static const _kBalance = 'balanceMode';
  static const _kLooseStack = 'looseStack';
  static const _kHaptics = 'haptics';

  final SharedPreferences _prefs;

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance());

  /// Hard mode: tilt affects tower stability. OFF by default per the V1 spec.
  bool get balanceMode => _balanceMode;
  bool _balanceMode;
  set balanceMode(bool v) {
    if (v == _balanceMode) return;
    _balanceMode = v;
    _prefs.setBool(_kBalance, v);
    notifyListeners();
  }

  /// Expert layer on top of Balance Mode: placed blocks are no longer welded
  /// to the tower, so tilting shears the stack. OFF by default; inert unless
  /// [balanceMode] is also on (the core enforces this too).
  bool get looseStack => _looseStack;
  bool _looseStack;
  set looseStack(bool v) {
    if (v == _looseStack) return;
    _looseStack = v;
    _prefs.setBool(_kLooseStack, v);
    notifyListeners();
  }

  /// Vibration feedback on drops/perfects/topples. Defaults ON (it is pure
  /// immersion with no privacy surface); no-op on web.
  bool get haptics => _haptics;
  bool _haptics;
  set haptics(bool v) {
    if (v == _haptics) return;
    _haptics = v;
    _prefs.setBool(_kHaptics, v);
    notifyListeners();
  }
}
