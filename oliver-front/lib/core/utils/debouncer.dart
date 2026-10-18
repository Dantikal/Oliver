import 'dart:async';

import 'package:flutter/foundation.dart';

class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _t;

  void call(VoidCallback action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }

  void dispose() => _t?.cancel();
}
