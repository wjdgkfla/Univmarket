import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/conversation_sync.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/pill.dart';
import '../widgets/screen_scaffold.dart';

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
  ConversationSync? _sync;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final repo = context.read<Repository>();
    if (repo.isDemo) return;
    _sync = ConversationSync(changes: [], load: repo.refreshInbox)
      ..addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    unawaited(_sync!.refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_sync!.refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      unawaited(_sync!.refresh());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _sync?.removeListener(_changed);
    _sync?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<Repository>();
    final conversations = repo.listConversations();

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_sync?.failed == true)
            MaterialBanner(
              content: const Text(
                'Could not refresh messages. Check your connection and retry.',
              ),
              actions: [
                TextButton(
                  onPressed: () => _sync?.refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              'Inbox',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ),
          if (conversations.isEmpty)
            EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No messages yet',
              message:
                  'Message a seller or make an offer, and your conversations will appear here.',
              actionLabel: 'Browse listings',
              onAction: () => context.go('/'),
            ),
          for (final conv in conversations)
            _ConversationRow(conv: conv, repo: repo, colors: c),
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
    final status = _offerStatus(conv);
    return InkWell(
      onTap: () => context.push('/chat/${conv.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Avatar(initials: seller?.initials ?? '?'),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seller?.name ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _lastMessage(conv),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.inkSoft),
                  ),
                ],
              ),
            ),
            if (conv.unread)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
              )
            else if (status == OfferStatus.accepted)
              const Pill(label: 'Reserved', tone: PillTone.good)
            else if (status == OfferStatus.declined)
              const Pill(label: 'Declined', tone: PillTone.bad),
          ],
        ),
      ),
    );
  }
}
