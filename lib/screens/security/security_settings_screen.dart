import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../providers/security_provider.dart';
import 'lock_screen.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final security = context.watch<SecurityProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguridad y Privacidad'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tarjeta de estado de seguridad
          _SecurityStatusCard(security: security),
          const SizedBox(height: 24),

          // Sección: Control de acceso
          Text(
            'Control de acceso',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),

          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // PIN de 4 dígitos
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.pin, color: colorScheme.onPrimaryContainer),
                  ),
                  title: const Text('PIN de 4 dígitos', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    security.isPinSet ? 'PIN activo y configurado' : 'Sin configurar (recomendado)',
                  ),
                  trailing: security.isPinSet
                      ? PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'change') {
                              _changePin(context);
                            } else if (val == 'remove') {
                              _removePin(context);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'change',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text('Cambiar PIN'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Desactivar PIN', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : OutlinedButton(
                          onPressed: () => _createPin(context),
                          child: const Text('Activar'),
                        ),
                  onTap: () {
                    if (!security.isPinSet) {
                      _createPin(context);
                    }
                  },
                ),
                const Divider(height: 1),

                // Autenticación Biométrica
                SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Icon(
                      security.availableBiometrics.contains(BiometricType.face)
                          ? Icons.face_rounded
                          : Icons.fingerprint_rounded,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(security.biometricsLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    !security.canCheckBiometrics
                        ? 'No disponible en este dispositivo'
                        : (!security.isPinSet
                            ? 'Requiere configurar un PIN primero'
                            : (security.isBiometricsEnabled ? 'Activado' : 'Desactivado')),
                  ),
                  value: security.isBiometricsEnabled,
                  onChanged: (security.isPinSet && security.canCheckBiometrics)
                      ? (val) async {
                          if (val) {
                            final messenger = ScaffoldMessenger.of(context);
                            // Probar biometría antes de habilitarla
                            final ok = await security.authenticateWithBiometrics();
                            if (ok) {
                              await security.toggleBiometrics(true);
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Autenticación biométrica activada con éxito.')),
                              );
                            }
                          } else {
                            await security.toggleBiometrics(false);
                          }
                        }
                      : null,
                ),
                const Divider(height: 1),

                // Bloqueo al salir a segundo plano
                SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.screen_lock_portrait_outlined, color: colorScheme.onSurfaceVariant),
                  ),
                  title: const Text('Bloqueo automático', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Bloquear la app al salir a segundo plano'),
                  value: security.isAutoLockEnabled,
                  onChanged: security.isSecurityConfigured
                      ? (val) => security.toggleAutoLock(val)
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Sección: Privacidad visual
          Text(
            'Privacidad visual',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),

          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: CircleAvatar(
                backgroundColor: colorScheme.tertiaryContainer,
                child: Icon(
                  security.isPrivacyModeEnabled ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
              title: const Text('Modo Privacidad', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Ocultar montos y balances por defecto en la pantalla principal'),
              value: security.isPrivacyModeEnabled,
              onChanged: (_) => security.togglePrivacyMode(),
            ),
          ),

          const SizedBox(height: 24),

          // Nota de seguridad y privacidad local
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Privacidad de Grado Financiero',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tu PIN está protegido mediante hashing SHA-256 criptográfico local. Todos tus registros financieros se mantienen 100% en tu dispositivo y nunca son transferidos a servidores externos.',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _createPin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LockScreen(
          mode: LockScreenMode.create,
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN configurado correctamente.')),
            );
          },
        ),
      ),
    );
  }

  void _changePin(BuildContext context) {
    // Primero verificar el PIN actual
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LockScreen(
          mode: LockScreenMode.verify,
          title: 'Verifica tu PIN actual',
          onSuccess: () {
            // Una vez verificado, abrir pantalla para crear el nuevo PIN
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LockScreen(
                  mode: LockScreenMode.create,
                  title: 'Nuevo PIN de seguridad',
                  onSuccess: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN actualizado con éxito.')),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _removePin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LockScreen(
          mode: LockScreenMode.verify,
          title: 'Verifica tu PIN para desactivarlo',
          onSuccess: () async {
            final security = context.read<SecurityProvider>();
            await security.removePin();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN de seguridad desactivado.')),
              );
            }
          },
        ),
      ),
    );
  }
}

class _SecurityStatusCard extends StatelessWidget {
  final SecurityProvider security;

  const _SecurityStatusCard({required this.security});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSecure = security.isSecurityConfigured;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSecure
              ? [const Color(0xFF1E88E5), const Color(0xFF1565C0)]
              : [colorScheme.surfaceContainerHigh, colorScheme.surfaceContainerHighest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSecure
                  ? Colors.white.withValues(alpha: 0.2)
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSecure ? Icons.verified_user_rounded : Icons.lock_open_rounded,
              color: isSecure ? Colors.white : colorScheme.onSurfaceVariant,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSecure ? 'Aplicación protegida' : 'Sin protección activa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSecure ? Colors.white : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSecure
                      ? 'Tus finanzas requieren PIN o biometría para abrirse.'
                      : 'Cualquiera con acceso a tu teléfono puede ver tus saldos.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSecure ? Colors.white.withValues(alpha: 0.85) : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
