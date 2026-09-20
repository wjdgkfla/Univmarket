import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/conversation_sync.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/pill.dart';
import '../widgets/async_action.dart';

class ChatScreen extends StatefulWidget {
  final String id;
  const ChatScreen({super.key, required this.id});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final draftController = TextEditingController();
  ConversationSync? _sync;
  late final Repository _repo;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final repo = _repo = context.read<Repository>();
    unawaited(repo.markConversationRead(widget.id));
    if (repo.isDemo) return;
    _sync = ConversationSync(
      changes: repo.conversationChanges(widget.id),
      load: () => repo.refreshConversation(widget.id),
    )..addListener(_syncChanged);
    unawaited(_sync!.refresh());
  }

  void _syncChanged() {
    if (mounted) setState(() {});
  }

  Widget _retryBanner() => MaterialBanner(
    content: const Text(
      'Chat updates are unavailable. Check your connection and retry.',
    ),
    actions: [
      TextButton(onPressed: () => _sync?.refresh(), child: const Text('Retry')),
    ],
  );

  @override
  void dispose() {
    // Messages that arrived while the chat was open count as read too.
    unawaited(_repo.markConversationRead(widget.id));
    _sync?.removeListener(_syncChanged);
    _sync?.dispose();
    draftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<Repository>();
    final conversation = repo.getConversation(widget.id);
    if (conversation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Conversation'),
          leading: IconButton(
            tooltip: 'Go back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/inbox'),
          ),
        ),
        body: _sync == null
            ? const Center(child: Text('This conversation is unavailable.'))
            : _sync!.failed
            ? _retryBanner()
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final seller = repo.getSeller(conversation.sellerId);
    final listing = repo.getListing(conversation.listingId);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_sync?.failed == true) _retryBanner(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(bottom: BorderSide(color: c.line)),
              ),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Go back',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/inbox'),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Avatar(initials: seller?.initials ?? '?'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seller?.name ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: c.ink,
                          ),
                        ),
                        Text(
                          '${listing?.title ?? ''} · \$${listing?.price ?? 0}',
                          style: TextStyle(fontSize: 11.5, color: c.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                reverse: true,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final m in conversation.messages.reversed) ...[
                    _MessageBubble(
                      message: m,
                      listing: listing,
                      conversationId: conversation.id,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: draftController,
                      style: TextStyle(color: c.ink, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText:
                            'Message ${seller?.name.split(' ').first ?? ''}…',
                        hintStyle: TextStyle(color: c.inkFaint, fontSize: 13.5),
                        filled: true,
                        fillColor: c.surface2,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: c.line, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: c.line, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Send message',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        final draft = draftController.text;
                        final text = draft.trim();
                        if (text.isEmpty || _sending) return;
                        setState(() => _sending = true);
                        try {
                          await context.read<Repository>().sendMessage(
                            conversation.id,
                            text,
                          );
                          if (mounted && draftController.text == draft) {
                            draftController.clear();
                          }
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        } finally {
                          if (mounted) setState(() => _sending = false);
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Listing? listing;
  final String conversationId;
  const _MessageBubble({
    required this.message,
    required this.listing,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = message;

    if (m is SystemMessage) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            m.body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: c.inkFaint),
          ),
        ),
      );
    }

    if (m is OfferMessage) {
      final mine = m.from == MessageFrom.me;
      final tone = switch (m.status) {
        OfferStatus.pending => PillTone.warn,
        OfferStatus.accepted => PillTone.good,
        OfferStatus.declined => PillTone.bad,
      };
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.84,
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.line, width: 1.5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          'CASH OFFER',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: c.inkFaint,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Pill(label: m.status.name, tone: tone),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${m.amount}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      'for ${listing?.title ?? ''}',
                      style: TextStyle(fontSize: 11.5, color: c.inkSoft),
                    ),
                  ],
                ),
              ),
              if (m.status == OfferStatus.pending && !mine)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.line, width: 1.5),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: _OfferActions(
                    conversationId: conversationId,
                    offerId: m.id,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final t = m as TextMessage;
    final mine = t.from == MessageFrom.me;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.78,
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? c.accent : c.surface,
            border: mine ? null : Border.all(color: c.line),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Text(
            t.body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: mine ? Colors.white : c.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Accept/Decline for a received offer. Both disable while a response is in
/// flight so the one-way action can't be submitted twice.
class _OfferActions extends StatefulWidget {
  const _OfferActions({required this.conversationId, required this.offerId});
  final String conversationId, offerId;
  @override
  State<_OfferActions> createState() => _OfferActionsState();
}

class _OfferActionsState extends State<_OfferActions> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = context.read<Repository>();
    await runAction(
      context,
      () => accept
          ? repo.acceptOffer(widget.conversationId, widget.offerId)
          : repo.declineOffer(widget.conversationId, widget.offerId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: _TicketButton(
            label: 'Decline',
            bg: c.surface2,
            fg: c.inkSoft,
            onTap: _busy ? null : () => _respond(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TicketButton(
            label: 'Accept',
            bg: c.good,
            fg: Colors.white,
            onTap: _busy ? null : () => _respond(true),
          ),
        ),
      ],
    );
  }
}

class _TicketButton extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final VoidCallback? onTap;
  const _TicketButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final material = Material(
      color: bg,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
    return Opacity(opacity: onTap == null ? 0.5 : 1, child: material);
  }
}
