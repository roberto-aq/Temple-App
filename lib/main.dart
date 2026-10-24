import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.navBackground,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final problem = SupabaseConfig.problem;
  if (problem != null) {
    runApp(templeMaterialApp(home: _ConfigError(problem)));
    return;
  }
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.key);
  runApp(AuthGate(prefs: await SharedPreferences.getInstance()));
}

/// Se muestra si la app se compiló sin la configuración de Supabase.
class _ConfigError extends StatelessWidget {
  const _ConfigError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FALTA CONFIGURAR SUPABASE', style: AppText.display(32, height: 1)),
              const SizedBox(height: 12),
              SelectableText(message, style: AppText.body(16, color: AppColors.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
