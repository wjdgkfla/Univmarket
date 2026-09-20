import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../data/models.dart';
import '../widgets/async_action.dart';
import '../widgets/listing_image.dart';

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
      try {
        int? amount;
        if (offer) {
          amount = await showDialog<int>(
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
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(listing.tag),
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: ListingImage(
              listing: listing,
              saved: repo.favorites.contains(id),
              onSave: () => runAction(context, () => repo.toggleFavorite(id)),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            listing.price == 0 ? 'Free' : '\$${listing.price}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            listing.title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(listing.condition.label)),
              if (listing.status != 'available')
                Chip(
                  label: Text(
                    '${listing.status[0].toUpperCase()}${listing.status.substring(1)}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            listing.description,
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: Text(listing.zone),
            subtitle: Text(repo.me.school),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(
              listing.isSample
                  ? 'Sample seller'
                  : repo.getSeller(listing.sellerId)?.name ?? 'Seller',
            ),
            subtitle: Text(
              listing.isSample
                  ? 'Preview only · sign-in disabled'
                  : repo.isDemo
                  ? 'Demo profile · identity not verified'
                  : 'Student seller',
            ),
          ),
          if (listing.isSample)
            const Text(
              'This sample is not for sale. Messaging and offers are unavailable.',
            ),
          if (repo.isDemo)
            const Text(
              'Sample marketplace. No real payment or exchange takes place.',
              style: TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 24),
          if (mine) ...[
            FilledButton(
              onPressed: () => context.push('/edit/$id'),
              child: const Text('Edit listing'),
            ),
            OutlinedButton(
              onPressed: listing.status == 'sold'
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Mark as sold?'),
                          content: const Text(
                            'Buyers will no longer see this listing or be able to make offers. This can\'t be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Mark as sold'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await runAction(context, () => repo.markSold(id));
                      }
                    },
              child: const Text('Mark as sold'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: listing.isSample ? null : () => message(),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message seller'),
            ),
            OutlinedButton(
              onPressed: !listing.isSample && listing.status == 'available'
                  ? () => message(offer: true)
                  : null,
              child: const Text('Make offer'),
            ),
          ],
        ],
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Make a cash offer'),
    content: TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Offer in USD',
        prefixText: '\$ ',
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final amount = int.tryParse(controller.text.trim());
          if (amount == null || amount <= 0 || amount > 100000) {
            setState(() => error = 'Enter a whole amount from 1 to 100000.');
            return;
          }
          Navigator.pop(context, amount);
        },
        child: const Text('Send offer'),
      ),
    ],
  );
}
