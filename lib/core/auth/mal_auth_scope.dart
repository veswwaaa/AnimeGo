import 'package:flutter/widgets.dart';

import 'mal_auth_provider.dart';

/// Menyediakan [MalAuthProvider] ke subtree widget tanpa dependency tambahan.
class MalAuthScope extends InheritedNotifier<MalAuthProvider> {
  const MalAuthScope({
    super.key,
    required MalAuthProvider provider,
    required super.child,
  }) : super(notifier: provider);

  static MalAuthProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MalAuthScope>();
    assert(scope != null, 'MalAuthScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }
}
