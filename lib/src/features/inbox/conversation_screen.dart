import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/errors.dart';
import '../../domain/connections.dart';
import '../../routing/router.dart';
import '../../state/data_providers.dart';
import '../../state/outbox.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context) =>
      ConversationView(conversationId: conversationId);
}

/// A private conversation. Only its two participants can load it; anyone
/// else gets an explanation instead of messages.
class ConversationView extends ConsumerStatefulWidget {
  const ConversationView({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });
  final String conversationId;
  final bool embedded;

  @override
  ConsumerState<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends ConsumerState<ConversationView> {
  final _composer = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _composer.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    ref.read(outboxProvider(widget.conversationId).notifier).send(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final conv = ref.watch(conversationProvider(widget.conversationId));
    return conv.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => _frame(
        context,
        null,
        const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _frame(
        context,
        null,
        e is NotAllowedException || e is NotFoundException
            ? EmptyState(
                icon: Icons.lock_outline,
                title: 'This conversation is private',
                message: e is NotFoundException
                    ? 'We couldn’t find this conversation.'
                    : 'Only the two members in a conversation can read it.',
                actions: [
                  FilledButton(
                    onPressed: () => context.go('/inbox'),
                    child: const Text('Back to inbox'),
                  ),
                ],
              )
            : ErrorState(
                error: e,
                onRetry: () =>
                    ref.invalidate(conversationProvider(widget.conversationId)),
              ),
      ),
      data: (c) => _frame(context, c, _body(context, c)),
    );
  }

  Widget _frame(BuildContext context, Conversation? conv, Widget body) {
    final me = ref.watch(currentUserIdProvider) ?? '';
    final otherId = conv?.otherParticipant(me);
    final other = otherId == null ? null : ref.watch(memberProvider(otherId));
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final title = Row(
      children: [
        if (otherId != null) ...[
          MemberAvatar(
            name: other?.displayName ?? 'Member',
            id: otherId,
            size: 34,
          ),
          const SizedBox(width: Space.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                other?.displayName ?? 'Conversation',
                style: t.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              if (conv?.listingTitle != null)
                Text(
                  'Re: ${conv!.listingTitle}',
                  style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
    final actions = [
      if (conv?.listingId != null)
        IconButton(
          tooltip: 'View listing',
          onPressed: () => context.openListing(conv!.listingId!),
          icon: const Icon(Icons.article_outlined),
        ),
    ];
    if (widget.embedded) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              Space.md,
              Space.sm,
              Space.sm,
              Space.sm,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(child: title),
                ...actions,
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inbox'),
        ),
        titleSpacing: 0,
        title: title,
        actions: actions,
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _body(BuildContext context, Conversation conv) {
    final messages = ref.watch(messagesProvider(conv.id));
    final outbox = ref.watch(outboxProvider(conv.id));
    final me = ref.watch(currentUserIdProvider) ?? '';
    final now = ref.watch(clockProvider)();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // Drop outbox entries once the server has them.
    ref.listen(messagesProvider(conv.id), (_, next) {
      final ids = {for (final m in next.value ?? const <Message>[]) m.clientId};
      ref.read(outboxProvider(conv.id).notifier).prune(ids);
    });

    final list = messages.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(messagesProvider(conv.id)),
      ),
      data: (persisted) {
        final persistedIds = {for (final m in persisted) m.clientId};
        final pending = outbox
            .where((p) => !persistedIds.contains(p.clientId))
            .toList();
        final items = <_Item>[
          for (final m in persisted) _Item.persisted(m),
          for (final p in pending) _Item.pending(p, me, conv.id),
        ];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.waving_hand_outlined,
            title: 'You’re connected',
            message:
                'Say salaam and share what you’d like to talk about. Messages are private to the two of you.',
          );
        }
        // Newest at the bottom; the list is reversed so it opens there.
        final reversed = items.reversed.toList();
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.md,
          ),
          itemCount: reversed.length,
          itemBuilder: (context, i) {
            final item = reversed[i];
            final older = i + 1 < reversed.length ? reversed[i + 1] : null;
            final showDay =
                older == null ||
                dayLabel(older.createdAt, now) != dayLabel(item.createdAt, now);
            return Column(
              children: [
                if (showDay)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    child: Text(
                      dayLabel(item.createdAt, now),
                      style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ),
                _Bubble(
                  item: item,
                  mine: item.senderId == me,
                  onRetry: item.pending?.status == PendingStatus.failed
                      ? () => ref
                            .read(outboxProvider(conv.id).notifier)
                            .retry(item.pending!.clientId)
                      : null,
                  onDiscard: item.pending?.status == PendingStatus.failed
                      ? () => ref
                            .read(outboxProvider(conv.id).notifier)
                            .discard(item.pending!.clientId)
                      : null,
                ),
              ],
            );
          },
        );
      },
    );

    return Column(
      children: [
        Expanded(child: list),
        _Composer(controller: _composer, focusNode: _focus, onSend: _send),
      ],
    );
  }
}

class _Item {
  _Item.persisted(Message m)
    : body = m.body,
      createdAt = m.createdAt,
      senderId = m.senderId,
      pending = null;
  _Item.pending(PendingMessage p, String me, String conversationId)
    : body = p.body,
      createdAt = p.createdAt,
      senderId = me,
      pending = p;

  final String body;
  final DateTime createdAt;
  final String senderId;
  final PendingMessage? pending;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.item,
    required this.mine,
    this.onRetry,
    this.onDiscard,
  });
  final _Item item;
  final bool mine;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final failed = item.pending?.status == PendingStatus.failed;
    final sending = item.pending?.status == PendingStatus.sending;
    final bg = failed
        ? c.errorContainer
        : mine
        ? c.primary
        : c.surfaceContainerLowest;
    final fg = failed
        ? c.onErrorContainer
        : mine
        ? c.onPrimary
        : c.onSurface;
    final status = failed
        ? 'Not sent'
        : sending
        ? 'Sending…'
        : clockTime(item.createdAt);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width * 0.78).clamp(220, 560),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Semantics(
                label: '${mine ? 'You' : 'They'} said: ${item.body}. $status',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    border: mine ? null : Border.all(color: c.outlineVariant),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(Radii.lg),
                      topRight: const Radius.circular(Radii.lg),
                      bottomLeft: Radius.circular(mine ? Radii.lg : 4),
                      bottomRight: Radius.circular(mine ? 4 : Radii.lg),
                    ),
                  ),
                  child: Opacity(
                    opacity: sending ? 0.75 : 1,
                    child: SelectableText(
                      item.body,
                      style: t.bodyMedium?.copyWith(color: fg),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                alignment: mine ? WrapAlignment.end : WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (sending) ...[
                    Icon(Icons.schedule, size: 12, color: c.onSurfaceVariant),
                    const SizedBox(width: 4),
                  ],
                  if (failed) ...[
                    Icon(Icons.error_outline, size: 14, color: c.error),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    status,
                    style: t.labelSmall?.copyWith(
                      color: failed ? c.error : c.onSurfaceVariant,
                    ),
                  ),
                  if (failed) ...[
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                    TextButton(
                      onPressed: onDiscard,
                      child: const Text('Delete'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.xs,
        Space.xs,
        Space.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                // Enter sends on hardware keyboards; Shift+Enter adds a line.
                const SingleActivator(LogicalKeyboardKey.enter): onSend,
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                maxLength: Message.maxLength,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => IconButton.filled(
              tooltip: 'Send message',
              onPressed: controller.text.trim().isEmpty ? null : onSend,
              icon: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}
