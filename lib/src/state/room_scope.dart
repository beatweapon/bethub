import 'package:flutter/widgets.dart';

import 'room_state.dart';

class RoomScope extends InheritedNotifier<RoomState> {
  const RoomScope({super.key, required RoomState state, required super.child})
    : super(notifier: state);

  static RoomState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RoomScope>();
    assert(scope != null, 'RoomScope is not found in the widget tree.');
    return scope!.notifier!;
  }
}
