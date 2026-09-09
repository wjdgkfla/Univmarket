import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../widgets/listing_row.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final mine = repo
        .listListings()
        .where((l) => l.sellerId == repo.me.id)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 36,
            child: Icon(Icons.person_outline, size: 40),
          ),
          const SizedBox(height: 18),
          Text(
            repo.me.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(repo.me.school, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          if (repo.isDemo)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'You are exploring a local demo. Your listings, saved items, and messages stay on this device. University verification and real trading are not enabled.',
                ),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your listings',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/sell'),
                child: const Text('Add new'),
              ),
            ],
          ),
          if (mine.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'Your next listing starts here. Sell something you no longer need.',
              ),
            ),
          for (final l in mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListingRow(listing: l),
            ),
        ],
      ),
    );
  }
}
