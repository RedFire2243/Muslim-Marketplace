import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/account_gateway.dart';
import 'data/key_value_store.dart';
import 'data/supabase/supabase_gateway.dart';
import 'state/session.dart';

/// Builds the root widget. Demo mode always works; connected mode is added
/// only when backend configuration is present and initializes cleanly.
Future<Widget> bootstrap({
  AppConfig? config,
  KeyValueStore? store,
  Duration? demoLatency,
  DateTime Function()? clock,
  List<Override> overrides = const [],
  Key? key,
}) async {
  final cfg = config ?? AppConfig.fromEnvironment();
  final kv =
      store ?? SharedPreferencesStore(await SharedPreferences.getInstance());

  AccountGateway? gateway;
  if (cfg.hasBackend) {
    try {
      gateway = await SupabaseAccountGateway.initialize(cfg);
    } catch (e) {
      // A bad configuration must not block the demo.
      debugPrint('Connected mode unavailable: $e');
    }
  }

  return ProviderScope(
    key: key,
    retry: (_, _) => null,
    overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      appConfigProvider.overrideWithValue(cfg),
      accountGatewayProvider.overrideWithValue(gateway),
      if (demoLatency != null)
        demoLatencyProvider.overrideWithValue(demoLatency),
      if (clock != null) clockProvider.overrideWithValue(clock),
      ...overrides,
    ],
    child: const MarketplaceApp(),
  );
}
