import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../game/stack_game.dart';
import '../settings/settings.dart';
import 'feedback.dart';
import 'hud.dart';
import 'overlays.dart';
import 'settings_sheet.dart';

/// Hosts the Flame game and layers the Flutter HUD + cards on top. A single
/// top-level tap handler feeds drops to the game; the cards handle their own
/// taps. When Balance Mode is on, starting a run detours through the
/// calibration card (which is also where the motion permission is requested —
/// only when the feature is actually used).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.settings});

  final Settings settings;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final StackGame game = StackGame();
  late final HapticsController _haptics =
      HapticsController(game: game, settings: widget.settings);

  bool _calibrating = false; // calibration card is showing
  bool _calibrationBusy = false; // sampling in progress
  String? _tiltError;

  void _onStartPressed() {
    if (widget.settings.balanceMode) {
      setState(() {
        _calibrating = true;
        _calibrationBusy = false;
        _tiltError = null;
      });
    } else {
      game.detachTilt();
      game.startRun();
    }
  }

  Future<void> _onCalibrateTap() async {
    if (_calibrationBusy) return;
    setState(() => _calibrationBusy = true);
    final ok = await game.prepareBalanceMode();
    if (!mounted) return;
    setState(() => _calibrationBusy = false);
    if (ok) {
      setState(() => _calibrating = false);
      game.startRun(balanceMode: true);
    } else {
      setState(() => _tiltError =
          'Tilt is unavailable or motion access was denied.\n'
          'You can play classic, or check device settings.');
    }
  }

  void _onPlayClassic() {
    setState(() => _calibrating = false);
    game.detachTilt();
    game.startRun();
  }

  @override
  void dispose() {
    _haptics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10141C),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => game.onDropTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(game: game),
            Hud(game: game),
            if (_calibrating)
              CalibrationCard(
                busy: _calibrationBusy,
                error: _tiltError,
                onCalibrate: _onCalibrateTap,
                onPlayClassic: _onPlayClassic,
              )
            else
              GameOverlays(game: game, onStart: _onStartPressed),
            // Settings gear, only on the menu-ish phases.
            ValueListenableBuilder<GamePhase>(
              valueListenable: game.phase,
              builder: (context, phase, _) {
                final show = (phase == GamePhase.ready ||
                        phase == GamePhase.gameOver) &&
                    !_calibrating;
                if (!show) return const SizedBox.shrink();
                return SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      padding: const EdgeInsets.all(16),
                      iconSize: 28,
                      color: Colors.white70,
                      icon: const Icon(Icons.settings),
                      onPressed: () =>
                          SettingsSheet.show(context, widget.settings),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
