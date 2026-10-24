import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../state/account.dart';
import '../sync/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';

Future<void> showAccountSheet(BuildContext context, Account account) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (_) => _AccountSheet(account: account),
  );
}

/// Ícono, color, título y detalle del estado de sincronización.
(AppIcons, Color, String, String) syncSummary(SyncService s, DateTime now) {
  final n = s.pending;
  final waiting = '$n ${plural(n, 'cambio guardado', 'cambios guardados')} en el teléfono';
  return switch (s.status) {
    SyncStatus.syncing => (AppIcons.repeat, AppColors.accent, 'Sincronizando…', n > 0 ? 'Subiendo $n ${plural(n, 'cambio', 'cambios')}' : 'Trayendo tus datos'),
    SyncStatus.offline => (
        AppIcons.cloudOff,
        AppColors.alert,
        'Sin conexión',
        n > 0
            ? '$waiting. ${plural(n, 'Se sube solo', 'Se suben solos')} cuando vuelva la conexión.'
            : 'Puedes seguir registrando: todo se guarda en el teléfono.',
      ),
    SyncStatus.error => (
        AppIcons.cloudOff,
        AppColors.alert,
        'No se pudo sincronizar',
        '${s.lastError ?? 'Error del servidor'}. ${n > 0 ? '$waiting; ' : ''}se reintentará sola.',
      ),
    SyncStatus.synced when n > 0 => (AppIcons.cloud, AppColors.textSecondary, 'Cambios por subir', waiting),
    SyncStatus.synced => (
        AppIcons.check,
        AppColors.accent,
        'Todo guardado en la nube',
        s.lastSynced == null ? 'Aún no se ha sincronizado.' : 'Última sincronización: ${_ago(s.lastSynced!, now)}.',
      ),
  };
}

String _ago(DateTime t, DateTime now) {
  final m = now.difference(t).inMinutes;
  if (m < 1) return 'hace un momento';
  if (m < 60) return 'hace $m min';
  final hh = t.hour.toString().padLeft(2, '0'), mm = t.minute.toString().padLeft(2, '0');
  return daysBetween(t, now) == 0 ? 'hoy a las $hh:$mm' : '${shortDate(t)}, $hh:$mm';
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({required this.account});
  final Account account;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  bool _confirmSignOut = false;
  bool _signingOut = false;

  Future<void> _requestSignOut() async {
    final sync = widget.account.sync;
    if (sync.pending > 0) {
      setState(() => _signingOut = true);
      await sync.flush();
      if (!mounted) return;
      setState(() => _signingOut = false);
      // Si no se pudo subir todo, se avisa antes de borrar la copia local.
      if (sync.pending > 0) return setState(() => _confirmSignOut = true);
    }
    _signOut();
  }

  void _signOut() {
    Navigator.pop(context);
    widget.account.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final sync = widget.account.sync;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final (icon, color, title, detail) = syncSummary(sync, DateTime.now());
        final n = sync.pending;
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.sheet,
            border: Border(top: BorderSide(color: AppColors.borderStrong)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.handle, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Semantics(header: true, child: Text('TU CUENTA', style: AppText.display(32, height: 1)))),
                  CircleIconButton(icon: AppIcons.close, semanticLabel: 'Cerrar', onTap: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 4),
              Text(widget.account.email, style: AppText.body(16, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: SurfaceCard(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(icon, size: 22, color: color, strokeWidth: 2.4),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: AppText.body(16, weight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(detail, style: AppText.body(13, color: AppColors.textSecondary, height: 1.35)),
                            if (sync.discarded > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'El servidor rechazó ${sync.discarded} ${plural(sync.discarded, 'cambio', 'cambios')} por datos inválidos.',
                                style: AppText.body(13, color: AppColors.alert, height: 1.35),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Sincronizar ahora',
                icon: AppIcons.repeat,
                onTap: sync.status == SyncStatus.syncing ? null : sync.refresh,
              ),
              const SizedBox(height: 10),
              if (!_confirmSignOut)
                SecondaryButton(
                  label: _signingOut ? 'Subiendo cambios…' : 'Cerrar sesión',
                  icon: AppIcons.logOut,
                  iconColor: AppColors.alert,
                  onTap: _signingOut ? null : _requestSignOut,
                )
              else
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.alertSoft(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF5A3A32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¿Cerrar sesión sin subir $n ${plural(n, 'cambio', 'cambios')}?',
                            style: AppText.body(15, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(plural(n, 'Aún no llega a la nube. Si cierras sesión ahora, se pierde.', 'Aún no llegan a la nube. Si cierras sesión ahora, se pierden.'),
                            style: AppText.body(13, color: AppColors.textSecondary)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                label: 'Cancelar',
                                height: 44,
                                fontSize: 15,
                                radius: 12,
                                onTap: () => setState(() => _confirmSignOut = false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Pressable(
                                onTap: _signOut,
                                color: AppColors.alert,
                                radius: 12,
                                height: 44,
                                child: Center(
                                  child: Text('Cerrar sesión',
                                      style: AppText.body(15, weight: FontWeight.w700, color: AppColors.background)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Botón de cuenta en la cabecera de Hoy. El punto avisa si hay cambios sin subir.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final sync = account.sync;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final problem = sync.status == SyncStatus.offline || sync.status == SyncStatus.error;
        final dot = problem ? AppColors.alert : (sync.pending > 0 ? AppColors.textSecondary : null);
        final (_, _, title, _) = syncSummary(sync, DateTime.now());
        return Stack(
          clipBehavior: Clip.none,
          children: [
            CircleIconButton(
              icon: AppIcons.user,
              size: 40,
              iconSize: 20,
              semanticLabel: 'Tu cuenta. $title',
              onTap: () => showAccountSheet(context, account),
            ),
            if (dot != null)
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
