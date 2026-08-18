import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'supabase_client.dart';

const _categoryIcon = {
  'Textbooks': 'book',
  'Electronics': 'headphones',
  'Furniture': 'chair',
  'Bikes': 'bike',
  // ponytail: both seeded "Dorm" listings (lamp, whiteboard) share one icon —
  // split by a real subcategory column if that distinction ever matters.
  'Dorm': 'lamp',
  'Apparel': 'shirt',
  'Bags': 'bag',
};
String _iconForCategory(String category) => _categoryIcon[category] ?? 'board';

Condition _conditionFromDb(String v) => switch (v) {
  'like_new' => Condition.likeNew,
  'fair' => Condition.fair,
  _ => Condition.good,
};

String _conditionToDb(Condition c) => switch (c) {
  Condition.likeNew => 'like_new',
  Condition.fair => 'fair',
  Condition.good => 'good',
};

// Dart's OfferStatus only models pending/accepted/declined — withdrawn,
// superseded and expired all read as "no longer live" so they collapse to
// declined for display purposes.
OfferStatus _offerStatusFromDb(String v) => switch (v) {
  'accepted' => OfferStatus.accepted,
  'pending' => OfferStatus.pending,
  _ => OfferStatus.declined,
};

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// Supabase-backed repository. Reads stay synchronous by deliberate design
/// (see the project's CLAUDE.md — wrapping instant reads in FutureBuilder
/// caused a real, debugged bug). Every async fetch populates in-memory
/// fields first, then calls notifyListeners(); nothing fetches inside a
/// getter that a build() method calls directly (getSeller is the one
/// exception, and it only *kicks off* a fetch — it still returns
/// synchronously from cache).
class Repository extends ChangeNotifier {
  Repository() {
    _bootstrap();
  }

  final SupabaseClient _db = supabase;

  /// True once the initial auth + data bootstrap has finished (success or
  /// failure). Screens don't currently gate on this directly — main.dart's
  /// AuthGate shows a loading screen until it flips true.
  bool ready = false;
  String? bootstrapError;

  Profile _me = const Profile(
    id: '',
    name: '',
    initials: '?',
    school: 'Fenwick University',
    rating: 0,
    dealsDone: 0,
    meetupsKeptPct: 100,
    avgReplyTime: '<1h',
  );
  List<Listing> _listings = [];
  final Map<String, Profile> _profiles = {};
  final Set<String> _fetchingProfiles = {};
  List<Conversation> _conversations = [];
  Set<String> _favorites = {};
  Map<String, String> _zoneNames = {}; // pickup_zone_id -> display name
  String? _universityId;
  String? _campusId;

  Profile get me => _me;
  Set<String> get favorites => Set.unmodifiable(_favorites);

  List<Listing> listListings() => List.unmodifiable(_listings);

  Listing? getListing(String id) {
    for (final l in _listings) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Returns the cached profile if we have it; otherwise kicks off a fetch
  /// (fire-and-forget) and returns null for now — the next notifyListeners()
  /// after the fetch resolves will have it cached.
  Profile? getSeller(String id) {
    final cached = _profiles[id];
    if (cached == null && _fetchingProfiles.add(id)) {
      _fetchProfile(id);
    }
    return cached;
  }

  List<Conversation> listConversations() => List.unmodifiable(_conversations);

  Conversation? getConversation(String id) {
    for (final c in _conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    try {
      final auth = _db.auth;
      if (auth.currentSession == null) {
        await auth.signInAnonymously();
      }
      final profileRow =
          await _db.rpc('ensure_profile') as Map<String, dynamic>;
      _me = _profileFromRow(profileRow);
      _profiles[_me.id] = _me;

      final zoneRows = await _db.from('pickup_zones').select('id, name');
      _zoneNames = {
        for (final z in zoneRows) z['id'] as String: z['name'] as String,
      };

      final uniRow = await _db
          .from('universities')
          .select('id')
          .eq('slug', 'fenwick')
          .single();
      _universityId = uniRow['id'] as String;
      final campusRow = await _db
          .from('campuses')
          .select('id')
          .eq('slug', 'main')
          .single();
      _campusId = campusRow['id'] as String;

      await Future.wait([
        _refreshListings(),
        _refreshConversations(),
        _refreshFavorites(),
      ]);
    } catch (e) {
      bootstrapError = e.toString();
      debugPrint('Repository bootstrap failed: $e');
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Profile _profileFromRow(Map<String, dynamic> row) {
    final name = (row['display_name'] as String?) ?? 'Anonymous';
    return Profile(
      id: row['id'] as String,
      name: name,
      initials: _initialsFor(name),
      // Single-university demo — revisit if multi-university ever ships.
      school: 'Fenwick University',
      rating: ((row['reputation_score'] as num?) ?? 5).toDouble(),
      dealsDone: (row['completed_transaction_count'] as int?) ?? 0,
      // Not tracked by the schema yet.
      meetupsKeptPct: 100,
      avgReplyTime: '<1h',
    );
  }

  Future<void> _fetchProfile(String id) async {
    try {
      final row = await _db
          .from('public_profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row != null) {
        _profiles[id] = _profileFromRow(row);
        notifyListeners();
      }
    } finally {
      _fetchingProfiles.remove(id);
    }
  }

  Future<void> _refreshListings() async {
    final rows = await _db
        .from('listings')
        .select()
        .eq('status', 'available')
        .eq('moderation_state', 'visible')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    _listings = [for (final r in rows) _listingFromRow(r)];
  }

  Listing _listingFromRow(Map<String, dynamic> r) => Listing(
    id: r['id'] as String,
    icon: _iconForCategory(r['category'] as String),
    title: r['title'] as String,
    price: (r['price'] as num).round(),
    condition: _conditionFromDb(r['condition'] as String),
    zone: _zoneNames[r['pickup_zone_id']] ?? '',
    tag: r['category'] as String,
    trades: r['accepts_trades'] as bool? ?? false,
    description: (r['description'] as String?) ?? '',
    sellerId: r['seller_id'] as String,
  );

  Future<void> _refreshFavorites() async {
    final rows = await _db
        .from('favorites')
        .select('listing_id')
        .eq('user_id', _me.id);
    _favorites = {for (final r in rows) r['listing_id'] as String};
  }

  Future<void> toggleFavorite(String listingId) async {
    if (_favorites.contains(listingId)) {
      await _db
          .from('favorites')
          .delete()
          .eq('user_id', _me.id)
          .eq('listing_id', listingId);
      _favorites.remove(listingId);
    } else {
      await _db
          .from('favorites')
          .insert({'user_id': _me.id, 'listing_id': listingId});
      _favorites.add(listingId);
    }
    notifyListeners();
  }

  Future<void> _refreshConversations() async {
    final rows = await _db
        .from('conversations')
        .select()
        .or('buyer_id.eq.${_me.id},seller_id.eq.${_me.id}');
    final list = <Conversation>[];
    for (final r in rows) {
      list.add(await _hydrateConversation(r));
    }
    _conversations = list;
  }

  Future<Conversation> _hydrateConversation(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final listingId = row['listing_id'] as String;
    final buyerId = row['buyer_id'] as String;
    final sellerId = row['seller_id'] as String;
    // "sellerId" here means "the other party in the thread" — whichever of
    // buyer/seller isn't me — since I might be either one.
    final otherId = buyerId == _me.id ? sellerId : buyerId;

    final msgRows = await _db
        .from('messages')
        .select()
        .eq('conversation_id', id)
        .order('created_at');

    final offerIds = [
      for (final m in msgRows)
        if (m['offer_id'] != null) m['offer_id'] as String,
    ];
    var offers = <String, Map<String, dynamic>>{};
    if (offerIds.isNotEmpty) {
      final offerRows = await _db.from('offers').select().inFilter(
        'id',
        offerIds,
      );
      offers = {for (final o in offerRows) o['id'] as String: o};
    }

    final messages = [
      for (final m in msgRows) _messageFromRow(m, offers, listingId),
    ];

    final isBuyer = buyerId == _me.id;
    final lastReadAt = isBuyer
        ? row['buyer_last_read_at']
        : row['seller_last_read_at'];
    final unread = lastReadAt == null && msgRows.isNotEmpty;

    return Conversation(
      id: id,
      sellerId: otherId,
      listingId: listingId,
      unread: unread,
      messages: messages,
    );
  }

  ChatMessage _messageFromRow(
    Map<String, dynamic> m,
    Map<String, Map<String, dynamic>> offers,
    String fallbackListingId,
  ) {
    final id = m['id'] as String;
    final type = m['type'] as String;
    final from = m['from_user_id'] == _me.id
        ? MessageFrom.me
        : MessageFrom.them;
    if (type == 'system') return SystemMessage(id, m['body'] as String? ?? '');
    if (type == 'offer') {
      final offerId = m['offer_id'] as String;
      final offer = offers[offerId];
      final amount = ((offer?['cash_amount'] as num?) ?? 0).round();
      final status = _offerStatusFromDb(
        (offer?['status'] as String?) ?? 'pending',
      );
      final listingId = (offer?['listing_id'] as String?) ?? fallbackListingId;
      // Use the offer id (not the message id) so acceptOffer/declineOffer
      // can call respond_to_offer directly with what the UI hands back.
      return OfferMessage(offerId, from, amount, listingId, status);
    }
    return TextMessage(id, from, m['body'] as String? ?? '');
  }

  /// Finds-or-creates the conversation about [listingId] via the
  /// start_conversation RPC and caches it. Unlike the old Demo Mode version
  /// this is necessarily async — starting a conversation is a server call.
  Future<String> conversationForListing(String listingId) async {
    final id =
        await _db.rpc(
              'start_conversation',
              params: {'p_listing_id': listingId},
            )
            as String;
    await refreshConversation(id);
    return id;
  }

  /// Re-fetches one conversation (messages + offers) and updates the cache.
  /// Used after mutations and by the chat screen's realtime subscription.
  Future<void> refreshConversation(String conversationId) async {
    final row = await _db
        .from('conversations')
        .select()
        .eq('id', conversationId)
        .single();
    final conv = await _hydrateConversation(row);
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1) {
      _conversations.add(conv);
    } else {
      _conversations[idx] = conv;
    }
    notifyListeners();
  }

  Future<void> sendMessage(String conversationId, String body) async {
    await _db.rpc(
      'create_message',
      params: {'p_conversation_id': conversationId, 'p_body': body},
    );
    await refreshConversation(conversationId);
  }

  Future<void> acceptOffer(String conversationId, String offerId) =>
      _respondToOffer(conversationId, offerId, 'accept');

  Future<void> declineOffer(String conversationId, String offerId) =>
      _respondToOffer(conversationId, offerId, 'decline');

  Future<void> _respondToOffer(
    String conversationId,
    String offerId,
    String action,
  ) async {
    await _db.rpc(
      'respond_to_offer',
      params: {'p_offer_id': offerId, 'p_action': action},
    );
    await refreshConversation(conversationId);
  }

  /// Sell screen doesn't collect real form input yet (fields are static
  /// display text, a known pre-existing gap) — this posts whatever's
  /// currently shown on screen as the listing.
  Future<void> createListing({
    required String title,
    required int price,
    required Condition condition,
    required String category,
    required String description,
    required bool acceptsTrades,
    required String pickupZoneName,
  }) async {
    final zoneId = _zoneNames.entries
        .firstWhere(
          (e) => e.value == pickupZoneName,
          orElse: () => _zoneNames.entries.first,
        )
        .key;
    await _db.from('listings').insert({
      'seller_id': _me.id,
      'university_id': _universityId,
      'campus_id': _campusId,
      'pickup_zone_id': zoneId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'condition': _conditionToDb(condition),
      'accepts_trades': acceptsTrades,
    });
    await _refreshListings();
    notifyListeners();
  }
}
