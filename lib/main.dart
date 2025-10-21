import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/models/server_config.dart';
import 'core/services/optimized_storage_service.dart';
import 'core/widgets/error_boundary.dart';
import 'core/providers/app_providers.dart';
import 'core/persistence/hive_bootstrap.dart';
import 'core/persistence/persistence_migrator.dart';
import 'core/persistence/persistence_providers.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/unified_auth_providers.dart';
import 'core/auth/auth_state_manager.dart';
import 'core/utils/debug_logger.dart';
import 'core/utils/system_ui_style.dart';

import 'package:conduit/l10n/app_localizations.dart';
import 'core/services/share_receiver_service.dart';
import 'core/providers/app_startup_providers.dart';

developer.TimelineTask? _startupTimeline;

const ServerConfig _defaultServerConfig = ServerConfig(
  id: 'preconfigured-server',
  name: 'Preconfigured Server',
  url: 'http://220.124.155.35:5173',
  allowSelfSignedCertificates: false,
);

ServerConfig? _normalizeServerConfig(ServerConfig config) {
  final normalizedUrl = _normalizeServerUrl(config.url);
  if (normalizedUrl == null) {
    return null;
  }
  if (normalizedUrl == config.url) {
    return config;
  }
  return config.copyWith(url: normalizedUrl);
}

String? _normalizeServerUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  String normalized = trimmed;
  if (!normalized.startsWith('http://') &&
      !normalized.startsWith('https://')) {
    normalized = 'http://$normalized';
  }

  if (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return null;
  }

  final hasValidScheme = uri.scheme == 'http' || uri.scheme == 'https';
  if (!hasValidScheme || !uri.hasAuthority || uri.host.isEmpty) {
    return null;
  }

  if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
    return null;
  }

  if (_looksLikeIpv4(uri.host) && !_isValidIpv4(uri.host)) {
    return null;
  }

  return normalized;
}

bool _looksLikeIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) {
    return false;
  }
  for (final part in parts) {
    if (part.isEmpty || int.tryParse(part) == null) {
      return false;
    }
  }
  return true;
}

bool _isValidIpv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) {
    return false;
  }

  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) {
      return false;
    }
  }

  return true;
}

Future<void> _ensureDefaultServerConfig(
  OptimizedStorageService storage,
) async {
  final existingConfigs = await storage.getServerConfigs();
  if (existingConfigs.isEmpty) {
    final normalizedConfig = _normalizeServerConfig(_defaultServerConfig);
    if (normalizedConfig == null) {
      DebugLogger.warning(
        'Skipped seeding default server: invalid configuration',
        scope: 'app/startup',
      );
      return;
    }

    await storage.saveServerConfigs([normalizedConfig]);
    await storage.setActiveServerId(normalizedConfig.id);
    DebugLogger.log(
      'Seeded default server configuration',
      scope: 'app/startup',
      data: {'url': normalizedConfig.url},
    );
  }
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Global error handlers
      FlutterError.onError = (FlutterErrorDetails details) {
        DebugLogger.error(
          'flutter-error',
          scope: 'app/framework',
          error: details.exception,
        );
        final stack = details.stack;
        if (stack != null) {
          debugPrintStack(stackTrace: stack);
        }
      };
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        DebugLogger.error(
          'platform-error',
          scope: 'app/platform',
          error: error,
          stackTrace: stack,
        );
        debugPrintStack(stackTrace: stack);
        return true;
      };

      // Start startup timeline instrumentation
      _startupTimeline = developer.TimelineTask();
      _startupTimeline!.start('app_startup');
      _startupTimeline!.instant('bindings_initialized');

      // Edge-to-edge is now handled natively in MainActivity.kt for Android 15+
      // No need for SystemUiMode.edgeToEdge which is deprecated
      _startupTimeline?.instant('edge_to_edge_configured');

      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          sharedPreferencesName: 'conduit_secure_prefs',
          preferencesKeyPrefix: 'conduit_',
          resetOnError: false,
        ),
        iOptions: IOSOptions(
          accountName: 'conduit_secure_storage',
          synchronizable: false,
        ),
      );
      _startupTimeline!.instant('secure_storage_ready');

      // Initialize Hive (now optimized with migration state caching)
      final hiveBoxes = await HiveBootstrap.instance.ensureInitialized();
      _startupTimeline!.instant('hive_ready');

      // Run migration check (now fast-pathed after first run)
      final migrator = PersistenceMigrator(hiveBoxes: hiveBoxes);
      await migrator.migrateIfNeeded();
      _startupTimeline!.instant('migration_complete');

      final storage = OptimizedStorageService(
        secureStorage: secureStorage,
        boxes: hiveBoxes,
      );
      await _ensureDefaultServerConfig(storage);

      // Finish timeline after first frame paints
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startupTimeline?.instant('first_frame_rendered');
        _startupTimeline?.finish();
        _startupTimeline = null;
      });

      runApp(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(secureStorage),
            hiveBoxesProvider.overrideWithValue(hiveBoxes),
            optimizedStorageServiceProvider.overrideWithValue(storage),
          ],
          child: const ConduitApp(),
        ),
      );
      developer.Timeline.instantSync('runApp_called');
    },
    (error, stack) {
      DebugLogger.error(
        'zone-error',
        scope: 'app',
        error: error,
        stackTrace: stack,
      );
      debugPrintStack(stackTrace: stack);
    },
  );
}

class ConduitApp extends ConsumerStatefulWidget {
  const ConduitApp({super.key});

  @override
  ConsumerState<ConduitApp> createState() => _ConduitAppState();
}

class _ConduitAppState extends ConsumerState<ConduitApp> {
  Brightness? _lastAppliedOverlayBrightness;
  @override
  void initState() {
    super.initState();
    // Delay heavy provider initialization until after the first frame so the
    // initial paint stays responsive.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAppState());
  }

  void _initializeAppState() {
    DebugLogger.auth('init', scope: 'app');

    void queueInit(void Function() action, {Duration delay = Duration.zero}) {
      Future<void>.delayed(delay, () {
        if (!mounted) return;
        action();
      });
    }

    queueInit(() => ref.read(authStateManagerProvider));
    queueInit(
      () => ref.read(authApiIntegrationProvider),
      delay: const Duration(milliseconds: 16),
    );
    queueInit(
      () => ref.read(defaultModelAutoSelectionProvider),
      delay: const Duration(milliseconds: 24),
    );
    queueInit(
      () => ref.read(shareReceiverInitializerProvider),
      delay: const Duration(milliseconds: 32),
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appStartupFlowProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider.select((mode) => mode));
    final router = ref.watch(goRouterProvider);
    final locale = ref.watch(appLocaleProvider);
    final lightTheme = ref.watch(appLightThemeProvider);
    final darkTheme = ref.watch(appDarkThemeProvider);

    return ErrorBoundary(
      child: MaterialApp.router(
        routerConfig: router,
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (deviceLocales, supported) {
          if (locale != null) return locale;
          if (deviceLocales == null || deviceLocales.isEmpty) {
            return supported.first;
          }
          for (final device in deviceLocales) {
            for (final loc in supported) {
              if (loc.languageCode == device.languageCode) return loc;
            }
          }
          return supported.first;
        },
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          if (_lastAppliedOverlayBrightness != brightness) {
            _lastAppliedOverlayBrightness = brightness;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              applySystemUiOverlayStyleOnce(brightness: brightness);
            });
          }
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: mediaQuery.textScaler.clamp(
                minScaleFactor: 1.0,
                maxScaleFactor: 3.0,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
