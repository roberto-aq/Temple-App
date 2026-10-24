import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import 'library_screen.dart';
import 'progress_screen.dart';
import 'routines_screen.dart';
import 'today_screen.dart';

enum AppTab {
  hoy('Hoy', AppIcons.calendar),
  rutinas('Rutinas', AppIcons.list),
  progreso('Progreso', AppIcons.chart),
  ejercicios('Ejercicios', AppIcons.dumbbell);

  const AppTab(this.label, this.icon);
  final String label;
  final AppIcons icon;
}

/// Pestaña activa. Vive por encima del [Navigator] para que las pantallas apiladas puedan cambiarla.
class ShellController extends ValueNotifier<AppTab> {
  ShellController() : super(AppTab.hoy);
}

class ShellScope extends InheritedNotifier<ShellController> {
  const ShellScope({super.key, required ShellController controller, required super.child}) : super(notifier: controller);

  static ShellController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>()!.notifier!;
  static ShellController read(BuildContext context) => context.getInheritedWidgetOfExactType<ShellScope>()!.notifier!;
}

/// Cierra las pantallas apiladas y muestra la pestaña indicada.
void goToTab(BuildContext context, AppTab tab) {
  final shell = ShellScope.read(context);
  Navigator.of(context).popUntil((r) => r.isFirst);
  shell.value = tab;
}

Future<T?> pushScreen<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

Future<T?> replaceScreen<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).pushReplacement<T, void>(MaterialPageRoute(builder: (_) => screen));

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = ShellScope.of(context).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tab.index,
          children: const [TodayScreen(), RoutinesScreen(), ProgressScreen(), LibraryScreen()],
        ),
      ),
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final shell = ShellScope.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 76 + bottomInset,
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.navBackground,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Semantics(
        label: 'Navegación principal',
        container: true,
        child: Row(
          children: [
            for (final t in AppTab.values)
              Expanded(child: _NavItem(tab: t, active: shell.value == t, onTap: () => shell.value = t)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active, required this.onTap});

  final AppTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(
          children: [
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: active ? AppColors.accent : Colors.transparent,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
            ),
            const SizedBox(height: 11),
            AppIcon(tab.icon, size: 24, color: color, strokeWidth: 2.1),
            const SizedBox(height: 5),
            Text(tab.label, style: AppText.body(12, weight: FontWeight.w700, color: color, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
