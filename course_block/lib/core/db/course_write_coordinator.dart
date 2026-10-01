import 'dart:async';

/// Serializes course and schedule writes for one persistence instance.
class CourseWriteCoordinator {
  Future<void> _tail = Future<void>.value();
  Object? _activeToken;
  int _pending = 0;
  static final Object _zoneKey = Object();
  static final Object _ownerKey = Object();

  Future<T> run<T>(Future<T> Function() action) {
    if (identical(Zone.current[_ownerKey], this)) {
      // Nested helper calls belong to the same phase; escaped/unawaited calls
      // cannot silently enter a later phase using an obsolete zone token.
      if (!identical(Zone.current[_zoneKey], _activeToken)) {
        throw StateError('A course write escaped its serialized phase');
      }
      return action();
    }

    // Start an idle lane immediately: widget tests (and UI callbacks) can
    // await the first write without needing a separate fake-async pump.
    final operation = _pending++ == 0
        ? _start(action)
        : _tail.then((_) => _start(action));
    // The caller sees its own failure; only the queue tail absorbs it.
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<T> _start<T>(Future<T> Function() action) async {
    final token = Object();
    _activeToken = token;
    try {
      return await runZoned(
        action,
        zoneValues: {_ownerKey: this, _zoneKey: token},
      );
    } finally {
      _activeToken = null;
      _pending--;
    }
  }
}
