import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_shell.dart';
import 'state/account.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// MaterialApp con el tema y el idioma de Temple.
MaterialApp templeMaterialApp({required Widget home}) => MaterialApp(
      title: 'Temple',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );

/// La app con una cuenta abierta (o sin cuenta, en los tests).
class TempleApp extends StatefulWidget {
  const TempleApp({super.key, required this.state, this.account});

  final AppState state;
  final Account? account;

  @override
  State<TempleApp> createState() => _TempleAppState();
}

class _TempleAppState extends State<TempleApp> {
  final _shell = ShellController();

  @override
  void dispose() {
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget app = AppScope(
      state: widget.state,
      child: ShellScope(controller: _shell, child: templeMaterialApp(home: const HomeShell())),
    );
    final account = widget.account;
    if (account != null) app = AccountScope(account: account, child: app);
    return app;
  }
}
