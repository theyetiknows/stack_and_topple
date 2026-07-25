import 'package:flutter/material.dart';

import '../settings/settings.dart';

/// Bottom sheet with the option toggles. Balance Mode's subtitle states the
/// calibration promise so players know an odd holding pose is fine.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.settings});

  final Settings settings;

  static Future<void> show(BuildContext context, Settings settings) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161B26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SettingsSheet(settings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'SETTINGS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                    color: Colors.white70,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Balance Mode'),
                subtitle: const Text(
                  'Hard mode: tilt your phone to keep the tower steady. '
                  'Calibrates to however you hold it.',
                ),
                value: settings.balanceMode,
                onChanged: (v) => settings.balanceMode = v,
              ),
              SwitchListTile(
                title: const Text('Loose Stack'),
                subtitle: Text(
                  settings.balanceMode
                      ? 'Expert: placed blocks slide when you tilt. Blocks '
                          'that slide off cost points — the run ends only if '
                          'the whole tower goes.'
                      : 'Requires Balance Mode.',
                ),
                value: settings.looseStack && settings.balanceMode,
                onChanged: settings.balanceMode
                    ? (v) => settings.looseStack = v
                    : null,
              ),
              SwitchListTile(
                title: const Text('Haptics'),
                subtitle:
                    const Text('Vibration feedback on drops and topples.'),
                value: settings.haptics,
                onChanged: (v) => settings.haptics = v,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
