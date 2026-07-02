import '../core/input/input_event.dart';
import '../core/input/input_source.dart';

/// Turns screen taps into [DropEvent]s. The presentation layer calls [tap] on a
/// pointer-down; the game loop drains the queued events each tick. The core has
/// no idea taps are the source — the same [DropEvent]s could come from a script.
class TapInputSource implements InputSource {
  final List<InputEvent> _queue = [];

  /// Record a drop request (call from the widget's tap handler).
  void tap() => _queue.add(const DropEvent());

  @override
  List<InputEvent> drain() {
    if (_queue.isEmpty) return const <InputEvent>[];
    final out = List<InputEvent>.of(_queue);
    _queue.clear();
    return out;
  }
}
