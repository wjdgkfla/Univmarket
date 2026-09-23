import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/listing_image.dart';
import '../widgets/pill.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/time_ago.dart';

String _lastMessage(Conversation c) {
  if (c.messages.isEmpty) return '';
  final m = c.messages.last;
  return switch (m) {
    TextMessage(:final from, :final body) =>
      from == MessageFrom.me ? 'You: $body' : body,
    SystemMessage(:final body) => body,
    OfferMessage(:final amount) => 'Offer: \$$amount',
  };
}

OfferStatus? _offerStatus(Conversation c) {
  for (final m in c.messages.reversed) {
    if (m is OfferMessage && m.status != OfferStatus.pending) return m.status;
  }
  return null;
}

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  // Ongoing freshness while the app is open (on any tab, not just this one)
  // comes from InboxLiveSync's app-wide realtime subscription. This screen
  // only needs to guarantee one refresh on open and one on resume, the same
  // resume-recovers-a-missed-realtime-event fallback the chat screen uses.
  bool _failed = false;
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    try {
      await context.read<Repository>().refreshInbox();
      if (mounted && _failed) setState(() => _failed = false);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _refreshing = false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (context.read<Repository>().isDemo) return;
    WidgetsBinding.instance.addObserver(this);
    // A repository whose refreshInbox() happens to complete synchronously
    // (no real await before its notifyListeners(), as some test doubles do)
    // would otherwise call notifyListeners() while Flutter is still in the
    // middle of building this very widget. Deferring to a microtask is what
    // the old per-screen ConversationSync used to do for the same reason.
    unawaited(Future.microtask(_refresh));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<Repository>();
    final conversations = repo.listConversations();

    return ScreenScaffold(
      title: 'Inbox',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_failed)
            MaterialBanner(
              content: const Text(
                'Could not refresh messages. Check your connection and retry.',
              ),
              actions: [
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          if (conversations.isEmpty)
            EmptyState(
              icon: CupertinoIcons.chat_bubble_2,
              title: 'No messages yet',
              message:
                  'Message a seller or make an offer, and your conversations will appear here.',
              actionLabel: 'Browse listings',
              onAction: () => context.go('/'),
            ),
          for (var i = 0; i < conversations.length; i++) ...[
            if (i > 0) Divider(indent: gutter + 52 + 12, color: c.line),
            FadeSlideIn(
              key: ValueKey(conversations[i].id),
              index: i,
              child: _ConversationRow(
                conv: conversations[i],
                repo: repo,
                colors: c,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final Conversation conv;
  final Repository repo;
  final AppColors colors;
  const _ConversationRow({
    required this.conv,
    required this.repo,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final seller = repo.getSeller(conv.sellerId);
    final listing = repo.getListing(conv.listingId);
    final status = _offerStatus(conv);
    return InkWell(
      onTap: () => context.push('/chat/${conv.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
        child: Row(
          children: [
            Avatar(initials: seller?.initials ?? '?', size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          seller?.name ?? 'Student',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: conv.unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 15.5,
                            color: c.ink,
                          ),
                        ),
                      ),
                      if (conv.updatedAt != null)
                        Text(
                          timeAgo(conv.updatedAt!),
                          style: TextStyle(fontSize: 12.5, color: c.inkSoft),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _lastMessage(conv),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: conv.unread ? c.ink : c.inkSoft,
                      fontWeight: conv.unread
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 6),
                    switch (status) {
                      OfferStatus.accepted => const Pill(
                        label: 'Reserved',
                        tone: PillTone.good,
                      ),
                      OfferStatus.expired => const Pill(
                        label: 'Expired',
                        tone: PillTone.neutral,
                      ),
                      _ => const Pill(label: 'Declined', tone: PillTone.bad),
                    },
                  ],
                ],
              ),
            ),
            if (conv.unread) ...[
              const SizedBox(width: 8),
              Semantics(
                label: 'Unread',
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: c.bad,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
            if (listing != null) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 48,
                child: ListingImage(
                  listing: listing,
                  radius: 6,
                  showStatus: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
