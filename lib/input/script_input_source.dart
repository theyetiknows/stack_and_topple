import '../core/input/input_event.dart';
import '../core/input/input_source.dart';

/// A deterministic input source for tests, replays, and automated feel-tuning.
///
/// Because it implements the same [InputSource] port as taps and tilt, a script
/// drives the identical code path a real player does — which is what makes the
/// core reproducibly testable.
class ScriptInputSource implements InputSource {
  ScriptInputSource([List<InputEvent>? initial])
      : _queue = [...?initial];

  final List<InputEvent> _queue;

  void add(InputEvent event) => _queue.add(event);
  void drop() => _queue.add(const DropEvent());

  @override
  List<InputEvent> drain() {
    if (_queue.isEmpty) return const <InputEvent>[];
    final out = List<InputEvent>.of(_queue);
    _queue.clear();
    return out;
  }
}
