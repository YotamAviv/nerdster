import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Attaches a browser popstate listener on web.
StreamSubscription<void> bindPopState(void Function() onBack) {
  final controller = StreamController<void>();

  // Create a JS interop callback
  final jsListener = ((web.PopStateEvent _) {
    controller.add(null);
  }).toJS;

  // Add JS event listener
  web.window.addEventListener('popstate', jsListener);

  // Subscribe Dart side
  final sub = controller.stream.listen((_) => onBack());

  // Wrap so cancel removes listener too
  return _WrappedPopStateSubscription(sub, jsListener);
}

/// Wraps a Dart subscription but cleans up JS listener too.
class _WrappedPopStateSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _sub;
  final JSFunction _jsListener;

  _WrappedPopStateSubscription(this._sub, this._jsListener);

  @override
  Future<void> cancel() async {
    web.window.removeEventListener('popstate', _jsListener);
    await _sub.cancel();
  }

  // Forwarding methods
  @override
  void onData(void Function(T data)? handleData) => _sub.onData(handleData);
  @override
  void onError(Function? handleError) => _sub.onError(handleError);
  @override
  void onDone(void Function()? handleDone) => _sub.onDone(handleDone);
  @override
  void pause([Future<void>? resumeSignal]) => _sub.pause(resumeSignal);
  @override
  void resume() => _sub.resume();
  @override
  bool get isPaused => _sub.isPaused;
  @override
  Future<E> asFuture<E>([E? futureValue]) => _sub.asFuture(futureValue);
}
