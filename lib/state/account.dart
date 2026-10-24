import 'package:flutter/widgets.dart';

import '../sync/sync_service.dart';

/// La cuenta con sesión iniciada.
class Account {
  const Account({required this.email, required this.sync, required this.signOut});

  final String email;
  final SyncService sync;

  /// Cierra la sesión y borra la copia local de la cuenta.
  final Future<void> Function() signOut;
}

/// Da acceso a la [Account]. No existe en los tests sin cuenta.
class AccountScope extends InheritedWidget {
  const AccountScope({super.key, required this.account, required super.child});

  final Account account;

  static Account? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AccountScope>()?.account;

  @override
  bool updateShouldNotify(AccountScope oldWidget) => oldWidget.account != account;
}
