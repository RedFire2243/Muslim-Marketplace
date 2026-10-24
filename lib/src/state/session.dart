import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/account_gateway.dart';
import '../data/demo/demo_backend.dart';
import '../data/key_value_store.dart';
import '../data/repositories.dart';

/// Overridden at startup with device storage.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('keyValueStoreProvider must be overridden'),
);

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

/// Real-account gateway; null when no backend is configured.
final accountGatewayProvider = Provider<AccountGateway?>((ref) => null);

/// Clock used by ranking and the demo backend.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Simulated demo latency, so loading and sending states are visible.
final demoLatencyProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 120),
);

/// The single local demo backend for this app run.
final demoBackendProvider = FutureProvider<DemoBackend>((ref) async {
  final backend = await DemoBackend.open(
    ref.watch(keyValueStoreProvider),
    clock: ref.watch(clockProvider),
    latency: ref.watch(demoLatencyProvider),
  );
  ref.onDispose(backend.dispose);
  return backend;
});

/// A signed-in member and the backend serving them.
class AppSession {
  const AppSession(this.backend, this.userId);
  final MarketplaceBackend backend;
  final String userId;

  AppMode get mode => backend.mode;
  bool get isDemo => mode == AppMode.demo;
}

class SessionController extends AsyncNotifier<AppSession?> {
  static const modeKey = 'mm.session.mode';

  KeyValueStore get _store => ref.read(keyValueStoreProvider);

  @override
  Future<AppSession?> build() async {
    final mode = _store.getString(modeKey);
    if (mode == AppMode.demo.name) {
      final demo = await ref.read(demoBackendProvider.future);
      final id = demo.activeUserId;
      if (id != null && (await demo.members()).any((p) => p.id == id)) {
        return AppSession(demo, id);
      }
    } else if (mode == AppMode.connected.name) {
      final gateway = ref.read(accountGatewayProvider);
      if (gateway != null) {
        try {
          final backend = await gateway.restore();
          if (backend != null) {
            return AppSession(backend, backend.currentUserId);
          }
        } catch (_) {
          // Fall through to the welcome screen.
        }
      }
    }
    return null;
  }

  /// Enters the demo as a new member (onboarding) or as a sample member.
  Future<void> startDemo({String? asMemberId}) async {
    final demo = await ref.read(demoBackendProvider.future);
    if (asMemberId != null) {
      await demo.switchTo(asMemberId);
    } else {
      await demo.createMember();
    }
    await _store.setString(modeKey, AppMode.demo.name);
    state = AsyncData(AppSession(demo, demo.currentUserId));
  }

  /// Demo only: act as a different fictional member.
  Future<void> switchDemoMember(String memberId) async {
    final current = state.value;
    final controls = current?.backend.demo;
    if (current == null || controls == null) {
      throw StateError('Member switching is only available in the demo.');
    }
    await controls.switchTo(memberId);
    state = AsyncData(AppSession(current.backend, memberId));
  }

  /// Demo only: restores the sample data and returns to the welcome screen.
  Future<void> resetDemo() async {
    final current = state.value;
    final demo = await ref.read(demoBackendProvider.future);
    if (current != null && current.backend.demo == null) {
      throw StateError('Reset is only available in the demo.');
    }
    await demo.reset();
    await _store.remove(modeKey);
    state = const AsyncData(null);
  }

  Future<void> leaveDemo() async {
    final demo = await ref.read(demoBackendProvider.future);
    await demo.signOut();
    await _store.remove(modeKey);
    state = const AsyncData(null);
  }

  Future<void> signIn(String email, String password) async {
    final gateway = _requireGateway();
    final backend = await gateway.signIn(
      email: email.trim(),
      password: password,
    );
    await _store.setString(modeKey, AppMode.connected.name);
    state = AsyncData(AppSession(backend, backend.currentUserId));
  }

  /// Returns a [ConfirmationRequired] when the email must be confirmed first.
  Future<SignUpResult> signUp(
    String name,
    String email,
    String password,
  ) async {
    final gateway = _requireGateway();
    final result = await gateway.signUp(
      displayName: name.trim(),
      email: email.trim(),
      password: password,
    );
    if (result is SignedUp) {
      await _store.setString(modeKey, AppMode.connected.name);
      state = AsyncData(
        AppSession(result.backend, result.backend.currentUserId),
      );
    }
    return result;
  }

  Future<void> signOut() async {
    final current = state.value;
    if (current == null) return;
    if (current.isDemo) return leaveDemo();
    await _requireGateway().signOut();
    await current.backend.dispose();
    await _store.remove(modeKey);
    state = const AsyncData(null);
  }

  AccountGateway _requireGateway() {
    final g = ref.read(accountGatewayProvider);
    if (g == null) {
      throw StateError('Accounts are not configured in this build.');
    }
    return g;
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, AppSession?>(
  SessionController.new,
);
