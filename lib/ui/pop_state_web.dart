import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

StreamSubscription<void> bindPopState(void Function() onBack) {
  // Create a controller for the Dart side
  final controller = StreamController<void>();

  // Create a JS interop callback
  final jsListener = ((web.PopStateEvent _) {
    controller.add(null);
  }).toJS;

  // Add JS event listener
  web.window.addEventListener('popstate', jsListener);

  // Subscribe Dart side
  final sub = controller.stream.listen((_) => onBack());

  // Ensure we clean up both Dart and JS listeners
  return _PopStateSubscription(sub, controller, jsListener);
}

class _PopStateSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _sub;
  final StreamController<T> _controller;
  final JSFunction _jsListener;

  _PopStateSubscription(this._sub, this._controller, this._jsListener);

  @override
  Future<void> cancel() async {
    web.window.removeEventListener('popstate', _jsListener);
    await _sub.cancel();
    await _controller.close();
  }

  // Forward other methods
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
