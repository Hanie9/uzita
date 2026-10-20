import 'dart:async';
import 'dart:html' as html;

void Function() bindKeyboardDismiss(void Function() onDismiss) {
  final html.VisualViewport? viewport = html.window.visualViewport;
  if (viewport == null) return () {};

  num lastHeight = viewport.height ?? 0;
  final StreamSubscription<html.Event> subscription = viewport.onResize.listen(
    (_) {
      final num height = viewport.height ?? 0;
      final num inner = html.window.innerHeight ?? height;
      if (height > lastHeight + 40 && height > inner * 0.75) {
        onDismiss();
      }
      lastHeight = height;
    },
  );
  return subscription.cancel;
}
