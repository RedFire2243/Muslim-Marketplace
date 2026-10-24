import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/connections.dart';
import 'data_providers.dart';
import 'session.dart';

enum PendingStatus { sending, failed, sent }

/// A message typed by the member that may not be persisted yet.
class PendingMessage {
  const PendingMessage({
    required this.clientId,
    required this.body,
    required this.createdAt,
    this.status = PendingStatus.sending,
  });

  final String clientId;
  final String body;
  final DateTime createdAt;
  final PendingStatus status;

  PendingMessage withStatus(PendingStatus s) => PendingMessage(
    clientId: clientId,
    body: body,
    createdAt: createdAt,
    status: s,
  );
}

/// Per-conversation outbox giving each sent message a visible sending,
/// failed or sent state, with idempotent retry (same client id).
class OutboxController extends Notifier<List<PendingMessage>> {
  OutboxController(this.conversationId);
  final String conversationId;
  static const _uuid = Uuid();

  @override
  List<PendingMessage> build() {
    ref.watch(currentUserIdProvider);
    return const [];
  }

  Future<void> send(String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    final pending = PendingMessage(
      clientId: _uuid.v4(),
      body: text.length > Message.maxLength
          ? text.substring(0, Message.maxLength)
          : text,
      createdAt: ref.read(clockProvider)().toUtc(),
    );
    state = [...state, pending];
    await _deliver(pending);
  }

  Future<void> retry(String clientId) async {
    final p = state.where((m) => m.clientId == clientId).firstOrNull;
    if (p == null || p.status != PendingStatus.failed) return;
    _set(clientId, PendingStatus.sending);
    await _deliver(p);
  }

  void discard(String clientId) =>
      state = state.where((m) => m.clientId != clientId).toList();

  /// Drops entries the server has confirmed.
  void prune(Set<String> persistedClientIds) {
    final next = state
        .where((m) => !persistedClientIds.contains(m.clientId))
        .toList();
    if (next.length != state.length) state = next;
  }

  Future<void> _deliver(PendingMessage p) async {
    final backend = ref.read(backendProvider);
    if (backend == null) return;
    try {
      await backend.connections.sendMessage(
        conversationId,
        p.body,
        clientId: p.clientId,
      );
      if (ref.mounted) _set(p.clientId, PendingStatus.sent);
    } catch (_) {
      if (ref.mounted) _set(p.clientId, PendingStatus.failed);
    }
  }

  void _set(String clientId, PendingStatus status) {
    state = [
      for (final m in state) m.clientId == clientId ? m.withStatus(status) : m,
    ];
  }
}

final outboxProvider =
    NotifierProvider.family<OutboxController, List<PendingMessage>, String>(
      OutboxController.new,
    );
