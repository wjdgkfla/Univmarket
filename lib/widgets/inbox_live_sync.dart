import '../data/conversation_sync.dart';
import '../data/repository.dart';
import 'package:flutter/widgets.dart';

/// Keeps the tab-bar's unread dot live app-wide, not just while the Inbox
/// tab is open: a new message anywhere refreshes the inbox in the
/// background, silently. The Inbox screen still does its own refresh on
/// open/resume/pull — this only covers every other tab.
///
/// Gated on having a real backend ([Repository.client] non-null): the demo
/// and every offline test double never reach here, and a live Repository's
/// realtime stream needs an actual server to talk to.
class InboxLiveSync extends StatefulWidget {
  const InboxLiveSync({super.key, required this.repository, required this.child});
  final Repository repository;
  final Widget child;
  @override
  State<InboxLiveSync> createState() => _InboxLiveSyncState();
}

class _InboxLiveSyncState extends State<InboxLiveSync> {
  ConversationSync? _sync;

  @override
  void initState() {
    super.initState();
    if (widget.repository.client == null) return;
    _sync = ConversationSync(
      changes: [widget.repository.incomingMessages()],
      load: widget.repository.refreshInbox,
    );
  }

  @override
  void dispose() {
    _sync?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
