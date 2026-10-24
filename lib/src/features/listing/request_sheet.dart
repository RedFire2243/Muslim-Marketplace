import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/errors.dart';
import '../../domain/listing.dart';
import '../../domain/profile.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';

/// Composes a connection request. Returns true when one was sent.
Future<bool?> showRequestSheet(
  BuildContext context, {
  required String recipientId,
  required String recipientName,
  Listing? listing,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _RequestSheet(
    recipientId: recipientId,
    recipientName: recipientName,
    listing: listing,
  ),
);

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({
    required this.recipientId,
    required this.recipientName,
    this.listing,
  });
  final String recipientId;
  final String recipientName;
  final Listing? listing;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  late final TextEditingController _message;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final first = widget.recipientName.split(' ').first;
    final title = widget.listing?.title;
    _message = TextEditingController(
      text: title == null
          ? 'Salaam $first, I found you in the member directory and would like to connect.'
          : 'Salaam $first, I’m interested in “$title”.',
    );
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Add a short message.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(actionsProvider)
          .sendRequest(
            recipientId: widget.recipientId,
            listing: widget.listing,
            message: text,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is ValidationException
            ? e.fieldErrors.values.first
            : friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final Profile? me = ref.watch(myProfileProvider).value;
    final listed = me?.directoryVisible ?? false;
    return Padding(
      padding: EdgeInsets.only(
        left: Space.md,
        right: Space.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Space.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request to connect', style: t.titleLarge),
            const SizedBox(height: Space.xxs),
            Text(
              widget.listing == null
                  ? 'To ${widget.recipientName}'
                  : 'To ${widget.recipientName} about “${widget.listing!.title}”',
              style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _message,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Message',
                errorText: _error,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: c.onSurfaceVariant),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    '${widget.recipientName.split(' ').first} will see your name and this message${listed ? ', plus your directory profile' : ''}. If they accept, you can message each other privately. This isn’t an application or a commitment.',
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const ButtonSpinner()
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? 'Sending…' : 'Send request'),
            ),
            const SizedBox(height: Space.xs),
            TextButton(
              onPressed: _sending ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a confirmation after [showRequestSheet] succeeds.
void confirmRequestSent(BuildContext context, bool? sent) {
  if (sent == true) {
    showMessage(context, 'Request sent. We’ll show it in your inbox.');
  }
}
