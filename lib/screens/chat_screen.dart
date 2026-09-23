import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/conversation_sync.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/listing_image.dart';
import '../widgets/pill.dart';
import '../widgets/safety_menu.dart';
import '../widgets/async_action.dart';

class ChatScreen extends StatefulWidget {
  final String id;
  const ChatScreen({super.key, required this.id});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final draftController = TextEditingController();
  ConversationSync? _sync;
  late final Repository _repo;
  bool _sending = false;
  bool _loaded = false;
  final _shown = <String>{};
  bool _primed = false;

  Future<void> _send() async {
    final draft = draftController.text;
    final text = draft.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.sendMessage(widget.id, text);
      if (mounted && draftController.text == draft) draftController.clear();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final repo = _repo = context.read<Repository>();
    unawaited(repo.markConversationRead(widget.id));
    if (repo.isDemo) return;
    WidgetsBinding.instance.addObserver(this);
    _sync = ConversationSync(
      changes: repo.conversationChanges(widget.id),
      load: () async {
        await repo.refreshConversation(widget.id);
        if (mounted) setState(() => _loaded = true);
      },
    )..addListener(_syncChanged);
    unawaited(_sync!.refresh());
  }

  void _syncChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Realtime may have disconnected while the phone was locked.
      unawaited(_sync?.refresh());
    }
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
    WidgetsBinding.instance.removeObserver(this);
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
            icon: const Icon(CupertinoIcons.chevron_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/inbox'),
          ),
        ),
        body: _sync?.failed == true
            ? _retryBanner()
            : _sync == null || _loaded
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('This conversation is unavailable.'),
                    TextButton(
                      onPressed: () => context.go('/inbox'),
                      child: const Text('Back to inbox'),
                    ),
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final seller = repo.getSeller(conversation.sellerId);
    final listing = repo.getListing(conversation.listingId);
    // The history on first open is at rest; later messages slide in.
    if (!_primed) {
      _primed = true;
      _shown.addAll(conversation.messages.map((m) => m.id));
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_sync?.failed == true) _retryBanner(),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(bottom: BorderSide(color: c.line, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Go back',
                    icon: Icon(CupertinoIcons.chevron_back, color: c.ink),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/inbox'),
                  ),
                  Avatar(initials: seller?.initials ?? '?', size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      seller?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: c.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    icon: Icon(CupertinoIcons.ellipsis, color: c.ink),
                    onPressed: () => showSafetyMenu(
                      context,
                      userId: conversation.sellerId,
                      userName: seller?.name ?? 'this student',
                    ),
                  ),
                ],
              ),
            ),
            if (listing != null)
              InkWell(
                onTap: () => context.push('/listing/${listing.id}'),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(gutter, 10, gutter, 10),
                  decoration: BoxDecoration(
                    color: c.bg,
                    border: Border(
                      bottom: BorderSide(color: c.line, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: ListingImage(
                          listing: listing,
                          radius: 6,
                          showStatus: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (listing.status != 'available') ...[
                                  Pill(
                                    label: listing.status,
                                    tone: listing.status == 'sold'
                                        ? PillTone.neutral
                                        : PillTone.good,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    listing.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: c.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            priceText(context, listing.price, size: 14.5),
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 16,
                        color: c.inkFaint,
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ColoredBox(
                color: c.bg,
                child: ListView(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  children: [
                    for (final m in conversation.messages.reversed) ...[
                      FadeSlideIn(
                        key: ValueKey(m.id),
                        animate: _shown.add(m.id),
                        child: _MessageBubble(
                          message: m,
                          listing: listing,
                          conversationId: conversation.id,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                8,
                8 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.line, width: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: draftController,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: c.ink, fontSize: 16),
                      decoration: InputDecoration(
                        counterText: '',
                        isDense: true,
                        hintText:
                            'Message ${seller?.name.split(' ').first ?? ''}',
                        fillColor: c.surface2,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: c.line),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: 'Send message',
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: _sending ? null : _send,
                      radius: 24,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _sending ? c.surface2 : c.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.arrow_up,
                              size: 18,
                              color: _sending ? c.inkFaint : c.accentInk,
                            ),
                          ),
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
            style: TextStyle(fontSize: 12.5, color: c.inkSoft),
          ),
        ),
      );
    }

    if (m is OfferMessage) {
      final mine = m.from == MessageFrom.me;
      final expired = m.isExpired;
      final tone = expired
          ? PillTone.neutral
          : switch (m.status) {
              OfferStatus.pending => PillTone.warn,
              OfferStatus.accepted => PillTone.good,
              OfferStatus.declined => PillTone.bad,
              OfferStatus.expired => PillTone.neutral,
            };
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.8,
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: mine ? c.accentWash : c.surface2,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(CupertinoIcons.tag, size: 15, color: c.inkSoft),
                          Text(
                            mine ? 'Your cash offer' : 'Cash offer',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.inkSoft,
                            ),
                          ),
                          Pill(
                            label: expired ? 'expired' : m.status.name,
                            tone: tone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      priceText(
                        context,
                        m.amount,
                        size: 26,
                        weight: FontWeight.w800,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'for ${listing?.title ?? ''}',
                        style: TextStyle(fontSize: 13, color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
                if (m.status == OfferStatus.pending && !expired && !mine)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: _OfferActions(
                      conversationId: conversationId,
                      offerId: m.id,
                    ),
                  ),
              ],
            ),
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
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: mine ? c.accent : c.surface2,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 6),
                bottomRight: Radius.circular(mine ? 6 : 18),
              ),
            ),
            child: Text(
              t.body,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: mine ? c.accentInk : c.ink,
              ),
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
            bg: c.surface,
            fg: c.ink,
            onTap: _busy ? null : () => _respond(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TicketButton(
            label: 'Accept',
            bg: c.accent,
            fg: c.accentInk,
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
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
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
