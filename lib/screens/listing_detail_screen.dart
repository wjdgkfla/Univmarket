import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../data/models.dart';
import '../widgets/async_action.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/listing_image.dart';
import '../widgets/pill.dart';
import '../widgets/safety_menu.dart';
import '../widgets/time_ago.dart';

/// Listings with a message/offer action in flight.
final _messaging = <String>{};

class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final listing = repo.getListing(id);
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing unavailable')),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to marketplace'),
          ),
        ),
      );
    }
    final mine = listing.sellerId == repo.me.id;
    Future<void> message({bool offer = false}) async {
      // A second tap while the first is still opening the chat is ignored.
      if (!_messaging.add(id)) return;
      try {
        int? amount;
        if (offer) {
          amount = await showAdaptiveDialog<int>(
            context: context,
            builder: (_) => const OfferDialog(),
          );
          if (amount == null) return;
        }
        if (!context.mounted) return;
        final conversation = await repo.conversationForListing(id);
        if (amount != null) {
          await repo.sendOffer(conversation, amount);
        }
        if (context.mounted) context.push('/chat/$conversation');
      } catch (e) {
        if (context.mounted) showError(context, e);
      } finally {
        _messaging.remove(id);
      }
    }

    final c = context.colors;
    final saved = repo.favorites.contains(id);
    final seller = repo.getSeller(listing.sellerId);
    final size = MediaQuery.of(context).size;
    final photoHeight = size.width < size.height * 0.6
        ? size.width
        : size.height * 0.6;
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 21;

    Widget section(List<Widget> children) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

    /// Asks before an owner action that can't be undone, then runs it.
    Future<void> confirmThen(
      String title,
      String body,
      String confirmLabel,
      Future<void> Function() action,
    ) async {
      final confirmed = await showAdaptiveDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog.adaptive(
          title: Text(title),
          content: Text(body),
          actions: [
            dialogAction(
              dialogContext,
              'Cancel',
              () => Navigator.pop(dialogContext, false),
            ),
            dialogAction(
              dialogContext,
              confirmLabel,
              () => Navigator.pop(dialogContext, true),
              primary: true,
              destructive: true,
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await runAction(context, action);
      }
    }

    final reserved = listing.status == 'reserved';
    final List<Widget> actions = mine
        ? reserved
              // An accepted offer reserved it: finish the sale or relist.
              ? [
                  FilledButton(
                    onPressed: () => confirmThen(
                      'Mark as sold?',
                      'The buyer will be told in your chat. This can\'t be undone.',
                      'Mark as sold',
                      () => repo.finishReservation(id, sold: true),
                    ),
                    child: const Text('Mark as sold'),
                  ),
                  OutlinedButton(
                    onPressed: () => confirmThen(
                      'Cancel reservation?',
                      'The listing goes back on the market and the buyer is told in your chat.',
                      'Cancel reservation',
                      () => repo.finishReservation(id, sold: false),
                    ),
                    child: const Text('Cancel reservation'),
                  ),
                ]
              : [
                  FilledButton(
                    onPressed: listing.status == 'available'
                        ? () => context.push('/edit/$id')
                        : null,
                    child: const Text('Edit listing'),
                  ),
                  OutlinedButton(
                    onPressed: listing.status == 'sold'
                        ? null
                        : () => confirmThen(
                            'Mark as sold?',
                            'Buyers will no longer see this listing or be able to make offers. This can\'t be undone.',
                            'Mark as sold',
                            () => repo.markSold(id),
                          ),
                    child: const Text('Mark as sold'),
                  ),
                ]
        : [
            OutlinedButton(
              onPressed: listing.status == 'available'
                  ? () => message(offer: true)
                  : null,
              child: const Text('Make offer'),
            ),
            FilledButton(
              onPressed: () => message(),
              child: const Text('Message seller'),
            ),
          ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: photoHeight,
            automaticallyImplyLeading: false,
            backgroundColor: c.bg,
            shape: const Border(),
            leading: _PhotoButton(
              tooltip: 'Go back',
              icon: CupertinoIcons.chevron_back,
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
            actions: [
              if (!mine) ...[
                _PhotoButton(
                  tooltip: 'More',
                  icon: CupertinoIcons.ellipsis,
                  onPressed: () => showSafetyMenu(
                    context,
                    userId: listing.sellerId,
                    userName: seller?.name ?? 'this seller',
                    listingId: listing.id,
                  ),
                ),
                const SizedBox(width: 8),
                _PhotoButton(
                  tooltip: saved ? 'Remove from saved' : 'Save listing',
                  icon: saved
                      ? CupertinoIcons.heart_fill
                      : CupertinoIcons.heart,
                  color: saved ? c.accent : null,
                  onPressed: () =>
                      runAction(context, () => repo.toggleFavorite(id)),
                ),
              ] else if (listing.status == 'available')
                _PhotoButton(
                  tooltip: 'More',
                  icon: CupertinoIcons.ellipsis,
                  onPressed: () => _ownerMenu(context, repo, id),
                ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: Hero(
                tag: listingHeroTag(id),
                child: ListingImage(listing: listing, radius: 0),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(gutter, 14, gutter, 14),
                  child: Row(
                    children: [
                      Avatar(initials: seller?.initials ?? '?', size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seller?.name ?? 'Seller',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              repo.isDemo
                                  ? 'Demo profile · identity not verified'
                                  : 'Verified student · ${repo.me.school}',
                              style: TextStyle(fontSize: 13, color: c.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      if (!repo.isDemo)
                        Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          size: 20,
                          color: c.accent,
                          semanticLabel: 'Verified student',
                        ),
                    ],
                  ),
                ),
                const Divider(indent: gutter, endIndent: gutter),
                section([
                  Text(
                    listing.title,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        [
                          listing.tag,
                          listing.condition.label,
                          if (listing.trades) 'Trades ok',
                          if (listing.createdAt != null)
                            'Posted ${timeAgo(listing.createdAt!)}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 13.5, color: c.inkSoft),
                      ),
                      if (listing.status != 'available')
                        Pill(
                          label: listing.status,
                          tone: listing.status == 'sold'
                              ? PillTone.neutral
                              : PillTone.good,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  priceText(
                    context,
                    listing.price,
                    size: 26,
                    weight: FontWeight.w800,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.location_solid,
                        size: 15,
                        color: c.accent,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Pickup at ${listing.zone}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: c.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    listing.description,
                    style: TextStyle(fontSize: 16, height: 1.55, color: c.ink),
                  ),
                ]),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.line, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 10, gutter, 10),
            child: stacked
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      actions[1],
                      const SizedBox(height: 8),
                      actions[0],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: actions[0]),
                      const SizedBox(width: 10),
                      Expanded(child: actions[1]),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Round white button that stays legible over any photo.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Center(
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        elevation: 1,
        shadowColor: const Color(0x33000000),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: Icon(icon, size: 20, color: color ?? const Color(0xFF17191C)),
    ),
  );
}

class OfferDialog extends StatefulWidget {
  const OfferDialog({super.key});
  @override
  State<OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<OfferDialog> {
  final controller = TextEditingController();
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(controller.text.trim());
    if (amount == null || amount <= 0 || amount > 100000) {
      setState(() => error = 'Enter a whole amount from 1 to 100000.');
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    return AlertDialog.adaptive(
      title: const Text('Make a cash offer'),
      content: ios
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoTextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    placeholder: 'Offer in USD',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('\$'),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(fontSize: 13, color: c.bad),
                      ),
                    ),
                ],
              ),
            )
          : TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Offer in USD',
                prefixText: '\$ ',
                errorText: error,
              ),
              onSubmitted: (_) => _submit(),
            ),
      actions: [
        dialogAction(context, 'Cancel', () => Navigator.pop(context)),
        dialogAction(context, 'Send offer', _submit, primary: true),
      ],
    );
  }
}

/// Dialog button in the platform's own style: a Cupertino action on iOS,
/// a Material text or filled button elsewhere.
/// "More" on your own available listing: delete it, after confirming.
Future<void> _ownerMenu(
  BuildContext context,
  Repository repo,
  String id,
) async {
  final choice = await showCupertinoModalPopup<String>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(sheet, 'delete'),
          child: const Text('Delete listing'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheet),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (choice != 'delete' || !context.mounted) return;
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog.adaptive(
      title: const Text('Delete this listing?'),
      content: const Text(
        'It is removed from the market and from students\' saved items. This can\'t be undone.',
      ),
      actions: [
        dialogAction(dialog, 'Cancel', () => Navigator.pop(dialog, false)),
        dialogAction(
          dialog,
          'Delete',
          () => Navigator.pop(dialog, true),
          primary: true,
          destructive: true,
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await repo.deleteListing(id);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    context.canPop() ? context.pop() : context.go('/');
    messenger.showSnackBar(const SnackBar(content: Text('Listing deleted.')));
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Widget dialogAction(
  BuildContext context,
  String label,
  VoidCallback onPressed, {
  bool primary = false,
  bool destructive = false,
}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDefaultAction: primary,
      isDestructiveAction: destructive,
      child: Text(label),
    );
  }
  return primary
      ? FilledButton(onPressed: onPressed, child: Text(label))
      : TextButton(onPressed: onPressed, child: Text(label));
}
