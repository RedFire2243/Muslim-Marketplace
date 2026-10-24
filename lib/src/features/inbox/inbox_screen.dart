import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/errors.dart';
import '../../domain/connections.dart';
import '../../domain/taxonomy.dart';
import '../../routing/router.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import 'conversation_screen.dart';

/// Requests and private conversations. On wide screens the selected
/// conversation opens beside the list.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key, this.selectedConversationId});
  final String? selectedConversationId;

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    // Open on requests when something is waiting and no chat is selected.
    if (widget.selectedConversationId == null &&
        ref.read(pendingIncomingCountProvider) > 0) {
      _tabs.index = 1;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = Breakpoints.isExpanded(context);
    final pending = ref.watch(pendingIncomingCountProvider);
    // A different member (demo switching) starts on their own default tab.
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous != next) {
        _tabs.index = ref.read(pendingIncomingCountProvider) > 0 ? 1 : 0;
      }
    });

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            ContentWidth.gutter(context),
            Space.lg,
            ContentWidth.gutter(context),
            Space.xs,
          ),
          child: Semantics(
            header: true,
            child: Text('Inbox', style: t.headlineMedium),
          ),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: false,
          tabs: [
            const Tab(text: 'Messages'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text('Requests', overflow: TextOverflow.ellipsis),
                  ),
                  if (pending > 0) ...[
                    const SizedBox(width: 6),
                    Badge.count(count: pending),
                  ],
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ConversationList(selectedId: widget.selectedConversationId),
              const _RequestList(),
            ],
          ),
        ),
      ],
    );

    if (!wide) return Scaffold(body: list);

    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 380, child: list),
          VerticalDivider(
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: widget.selectedConversationId == null
                ? const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Select a conversation',
                    message:
                        'Conversations open here after a request is accepted.',
                  )
                : ConversationView(
                    key: ValueKey(widget.selectedConversationId),
                    conversationId: widget.selectedConversationId!,
                    embedded: true,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList({this.selectedId});
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final me = ref.watch(currentUserIdProvider);
    final now = ref.watch(clockProvider)();
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    return AsyncView(
      value: conversations,
      onRetry: () => ref.invalidate(conversationsProvider),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No conversations yet',
            message:
                'When someone accepts your request, or you accept theirs, a private conversation starts here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(indent: 72),
          itemBuilder: (context, i) {
            final conv = list[i];
            final otherId = conv.otherParticipant(me ?? '');
            final other = ref.watch(memberProvider(otherId));
            final name = other?.displayName ?? 'Member';
            final preview = conv.lastMessagePreview == null
                ? 'Say hello to start the conversation.'
                : '${conv.lastMessageSenderId == me ? 'You: ' : ''}${conv.lastMessagePreview}';
            return ListTile(
              selected: conv.id == selectedId,
              selectedTileColor: c.primaryContainer.withValues(alpha: 0.4),
              leading: MemberAvatar(name: name, id: otherId),
              title: Row(
                children: [
                  Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                  Text(
                    relativeTime(conv.sortTime, now),
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (conv.listingTitle != null)
                    Text(
                      'Re: ${conv.listingTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelSmall,
                    ),
                  Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
              onTap: () => context.openConversation(conv.id),
            );
          },
        );
      },
    );
  }
}

class _RequestList extends ConsumerStatefulWidget {
  const _RequestList();

  @override
  ConsumerState<_RequestList> createState() => _RequestListState();
}

class _RequestListState extends ConsumerState<_RequestList> {
  bool _incoming = true;

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(requestsProvider);
    final me = ref.watch(currentUserIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Received'),
                icon: Icon(Icons.call_received),
              ),
              ButtonSegment(
                value: false,
                label: Text('Sent'),
                icon: Icon(Icons.call_made),
              ),
            ],
            selected: {_incoming},
            onSelectionChanged: (s) => setState(() => _incoming = s.first),
          ),
        ),
        Expanded(
          child: AsyncView(
            value: requests,
            onRetry: () => ref.invalidate(requestsProvider),
            data: (all) {
              final list =
                  all
                      .where(
                        (r) =>
                            _incoming ? r.recipientId == me : r.senderId == me,
                      )
                      .toList()
                    ..sort((a, b) {
                      // Pending first, newest first.
                      final p = (a.status == RequestStatus.pending ? 0 : 1)
                          .compareTo(b.status == RequestStatus.pending ? 0 : 1);
                      return p != 0 ? p : b.createdAt.compareTo(a.createdAt);
                    });
              if (list.isEmpty) {
                return EmptyState(
                  icon: _incoming
                      ? Icons.move_to_inbox_outlined
                      : Icons.outbox_outlined,
                  title: _incoming
                      ? 'No requests received'
                      : 'No requests sent',
                  message: _incoming
                      ? 'When someone asks to connect about your listings, it shows up here.'
                      : 'Open a listing and tap “Request to connect” to introduce yourself.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  Space.sm,
                  0,
                  Space.sm,
                  Space.xxl,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: RequestTile(request: list[i], incoming: _incoming),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class RequestTile extends ConsumerStatefulWidget {
  const RequestTile({super.key, required this.request, required this.incoming});
  final ConnectionRequest request;
  final bool incoming;

  @override
  ConsumerState<RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<RequestTile> {
  bool _busy = false;

  Future<void> _act(
    Future<ConnectionRequest> Function() action,
    String success, {
    bool openChat = false,
  }) async {
    setState(() => _busy = true);
    try {
      final r = await action();
      if (!mounted) return;
      if (openChat && r.conversationId != null) {
        // The conversation itself confirms the acceptance; a snackbar would
        // cover its message composer.
        ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
        context.openConversation(r.conversationId!);
      } else {
        showMessage(context, success);
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final otherId = r.otherParty(me);
    final other = ref.watch(memberProvider(otherId));
    final name = other?.displayName ?? 'Member';
    final now = ref.watch(clockProvider)();
    final actions = ref.read(actionsProvider);

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: r.status == RequestStatus.pending && widget.incoming
              ? c.primary
              : c.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(name: name, id: otherId, size: 36),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.incoming ? name : 'To $name',
                      style: t.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      relativeTime(r.createdAt, now),
                      style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusBadge.request(r.status),
            ],
          ),
          const SizedBox(height: Space.sm),
          InkWell(
            onTap: r.listingId == null
                ? null
                : () => context.openListing(r.listingId!),
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                r.listingTitle == null
                    ? 'General introduction'
                    : 'About: ${r.listingTitle}',
                style: t.labelMedium?.copyWith(
                  color: r.listingId == null ? c.onSurfaceVariant : c.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.xxs),
          Text(r.message, style: t.bodyMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              if (widget.incoming && r.status == RequestStatus.pending) ...[
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _act(
                          () => actions.respond(r.id, accept: true),
                          'Accepted. You can now message $name.',
                          openChat: true,
                        ),
                  icon: const Icon(Icons.check),
                  label: const Text('Accept'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _act(
                          () => actions.respond(r.id, accept: false),
                          'Request declined',
                        ),
                  child: const Text('Decline'),
                ),
              ],
              if (!widget.incoming && r.status == RequestStatus.pending)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _act(
                          () => actions.withdraw(r.id),
                          'Request withdrawn',
                        ),
                  child: const Text('Withdraw'),
                ),
              if (r.status == RequestStatus.accepted &&
                  r.conversationId != null)
                FilledButton.tonalIcon(
                  onPressed: () => context.openConversation(r.conversationId!),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open conversation'),
                ),
            ],
          ),
          if (widget.incoming && r.status == RequestStatus.pending)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                'Accepting opens a private conversation. It doesn’t commit you to anything else.',
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
