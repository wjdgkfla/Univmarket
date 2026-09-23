import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'listing_photo.dart';
import 'listing_photo_storage.dart';
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

// Withdrawn and superseded offers read as "no longer live", so they collapse
// to declined for display purposes.
OfferStatus _offerStatusFromDb(String v) => switch (v) {
  'accepted' => OfferStatus.accepted,
  'pending' => OfferStatus.pending,
  'expired' => OfferStatus.expired,
  _ => OfferStatus.declined,
};

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Supabase-backed repository. Reads stay synchronous by deliberate design
/// (see the project's CLAUDE.md — wrapping instant reads in FutureBuilder
/// caused a real, debugged bug). Every async fetch populates in-memory
/// fields first, then calls notifyListeners(); nothing fetches inside a
/// getter that a build() method calls directly (getSeller is the one
/// exception, and it only *kicks off* a fetch — it still returns
/// synchronously from cache).
const categoryIcons = {
  'Textbooks': 'book',
  'Electronics': 'headphones',
  'Furniture': 'chair',
  'Bikes': 'bike',
  'Dorm': 'lamp',
  'Apparel': 'shirt',
  'Bags': 'bag',
};
const categories = [
  'Textbooks',
  'Electronics',
  'Furniture',
  'Bikes',
  'Dorm',
  'Apparel',
  'Bags',
];

/// Report reasons: database key -> label. Keys match the reports table check.
const reportReasons = {
  'prohibited': 'Prohibited or unsafe item',
  'scam': 'Scam or fraud',
  'harassment': 'Harassment or hate',
  'spam': 'Spam or misleading',
  'other': 'Something else',
};

class Repository extends ChangeNotifier {
  Repository.offline() : client = null {
    initialized = Future.value();
  }
  final SupabaseClient? client;
  late final Future<void> initialized;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get isDemo => false;
  String get universityId => _universityId ?? '';

  /// e.g. "GMU" — drives the market name and brand colors.
  String get schoolShortName => _schoolShortName;
  List<String> get pickupZones => _zoneNames.values.toList();
  void _requireConfirmedAccount() {
    final user = _db.auth.currentUser;
    if (!ready ||
        bootstrapError != null ||
        user == null ||
        user.id != _me.id ||
        user.isAnonymous ||
        user.emailConfirmedAt == null) {
      throw StateError('Sign in with your confirmed university account.');
    }
  }

  Future<void> markSold(String id) async {
    _requireConfirmedAccount();
    final listing = getListing(id);
    if (listing == null ||
        listing.sellerId != _me.id ||
        listing.universityId != _universityId ||
        listing.status != 'available') {
      throw StateError('Only your available listings can be marked sold.');
    }
    final row = await _db
        .from('listings')
        .update({'status': 'sold'})
        .eq('id', id)
        .eq('seller_id', _me.id)
        .eq('university_id', _universityId!)
        .eq('status', 'available')
        .isFilter('deleted_at', null)
        .select()
        .single();
    final saved = await _listingFromRow(row);
    final index = _listings.indexWhere((item) => item.id == id);
    if (index >= 0) _listings[index] = saved;
    notifyListeners();
  }

  /// Ends the reservation on your listing: [sold] marks it sold, otherwise
  /// it is relisted as available. The buyer gets a note in the chat.
  Future<void> finishReservation(String listingId, {required bool sold}) async {
    _requireConfirmedAccount();
    final listing = getListing(listingId);
    if (listing == null ||
        listing.sellerId != _me.id ||
        listing.status != 'reserved') {
      throw StateError('Only your reserved listings can be finished.');
    }
    await _db.rpc(
      'finish_reservation',
      params: {
        'p_listing_id': listingId,
        'p_outcome': sold ? 'sold' : 'cancelled',
      },
    );
    // The change has committed; a failed reload must not report failure.
    try {
      await _refreshConversations();
      await _refreshListings();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> sendOffer(String conversationId, int amount) async {
    _requireConfirmedAccount();
    if (amount < 1 || amount > 100000) {
      throw ArgumentError('Enter an offer between 1 and 100000.');
    }
    final thread = getConversation(conversationId);
    final listing = thread == null ? null : getListing(thread.listingId);
    if (thread == null ||
        listing == null ||
        listing.status != 'available' ||
        listing.universityId != _universityId ||
        listing.sellerId == _me.id ||
        thread.sellerId != listing.sellerId) {
      throw StateError('This listing is not available for an offer.');
    }
    final id =
        await _db.rpc(
              'send_offer',
              params: {
                'p_conversation_id': conversationId,
                'p_kind': 'cash',
                'p_cash_amount': amount,
                'p_offered_listing_ids': <String>[],
              },
            )
            as String;
    // A confirmed RPC is a successful send. Do not turn a subsequent read
    // failure into a retry that submits a duplicate offer.
    final current = getConversation(conversationId);
    if (current != null &&
        !current.messages.any((message) => message.id == id)) {
      final index = _conversations.indexWhere(
        (item) => item.id == conversationId,
      );
      _conversations[index] = current.copyWith(
        messages: [
          ...current.messages,
          OfferMessage(
            id,
            MessageFrom.me,
            amount,
            listing.id,
            OfferStatus.pending,
          ),
        ],
      );
      _conversationRevision++;
      notifyListeners();
    }
  }

  Repository({this.client}) {
    initialized = _bootstrap();
  }

  SupabaseClient get _db => client ?? supabase;

  /// True once the initial auth + data bootstrap has finished (success or
  /// failure). Screens don't currently gate on this directly — main.dart's
  /// AuthGate shows a loading screen until it flips true.
  bool ready = false;
  String? bootstrapError;

  Profile _me = const Profile(
    id: '',
    name: '',
    initials: '?',
    school: '',
    rating: 0,
    dealsDone: 0,
    meetupsKeptPct: 100,
    avgReplyTime: '<1h',
  );
  List<Listing> _listings = [];
  final Map<String, Profile> _profiles = {};
  final Set<String> _fetchingProfiles = {};
  List<Conversation> _conversations = [];
  int _conversationRevision = 0;
  Set<String> _favorites = {};
  Map<String, String> _zoneNames = {}; // pickup_zone_id -> display name
  String? _universityId;
  String? _campusId;
  String _schoolName = '';
  String _schoolShortName = '';

  Profile get me => _me;
  Set<String> get favorites => Set.unmodifiable(_favorites);

  /// Students you blocked: their listings and chats are hidden everywhere.
  Set<String> get blocked => Set.unmodifiable(_blocked);
  Set<String> _blocked = {};

  List<Listing> listListings() =>
      List.unmodifiable(_listings.where((l) => !_blocked.contains(l.sellerId)));

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

  List<Conversation> listConversations() => List.unmodifiable(
    _conversations.where((c) => !_blocked.contains(c.sellerId)),
  );

  List<Stream<Object?>> conversationChanges(String id) => [
    _db.from('messages').stream(primaryKey: ['id']).eq('conversation_id', id),
    _db.from('offers').stream(primaryKey: ['id']).eq('conversation_id', id),
  ];

  Conversation? getConversation(String id) {
    for (final c in _conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    try {
      final auth = _db.auth;
      final user = auth.currentUser;
      if (user == null || user.isAnonymous || user.emailConfirmedAt == null) {
        throw StateError('A confirmed email account is required.');
      }
      final profileRow =
          await _db.rpc('ensure_profile') as Map<String, dynamic>;
      _universityId = profileRow['university_id'] as String?;
      _campusId = profileRow['home_campus_id'] as String?;
      if (_universityId == null || _campusId == null) {
        throw StateError(
          'Your university and campus must be assigned before entering the marketplace.',
        );
      }
      final university = await _db
          .from('universities')
          .select('id, name, short_name')
          .eq('id', _universityId!)
          .eq('active', true)
          .single();
      _schoolName = university['name'] as String;
      _schoolShortName = university['short_name'] as String? ?? '';
      // Validate that the profile's campus belongs to its assigned university.
      await _db
          .from('campuses')
          .select('id')
          .eq('id', _campusId!)
          .eq('university_id', _universityId!)
          .eq('active', true)
          .single();
      _me = _profileFromRow(profileRow);
      _isAdmin = profileRow['role'] == 'admin';
      _profiles[_me.id] = _me;
      final zoneRows = await _db
          .from('pickup_zones')
          .select('id, name')
          .eq('campus_id', _campusId!)
          .eq('active', true)
          .order('name');
      _zoneNames = {
        for (final zone in zoneRows)
          zone['id'] as String: zone['name'] as String,
      };
      // Listings go last: the feed also keeps items from these threads and
      // favorites after they stop being available.
      await Future.wait([
        _refreshConversations(),
        _refreshFavorites(),
        _refreshBlocked(),
      ]);
      await _refreshListings();
      if (_isAdmin) {
        // The moderator badge is optional; it must never block sign-in.
        try {
          final count = await _db.rpc('admin_open_report_count') as num;
          _openReportCount = count.toInt();
        } catch (_) {}
      }
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
      school: _schoolName,
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
      // public_profiles hides deleted accounts; their past messages remain.
      _profiles[id] = row != null
          ? _profileFromRow(row)
          : Profile(
              id: id,
              name: 'Deleted student',
              initials: '?',
              school: _schoolName,
              rating: 0,
              dealsDone: 0,
              meetupsKeptPct: 0,
              avgReplyTime: '',
            );
      notifyListeners();
    } catch (_) {
      // Optional profile details must not cause an uncaught async failure.
      // Leave the placeholder visible; a later render can retry the lookup.
    } finally {
      _fetchingProfiles.remove(id);
    }
  }

  Future<void> refreshMarketplace() async {
    if (isDemo) return;
    _requireConfirmedAccount();
    await _refreshListings();
    notifyListeners();
    try {
      await refreshReportCount();
    } catch (_) {}
  }

  Future<void> refreshInbox() async {
    if (isDemo) return;
    _requireConfirmedAccount();
    await _refreshConversations();
    notifyListeners();
  }

  Future<void> _refreshListings() async {
    // A reserved or sold item must stay visible to the buyer chatting about
    // it and to students who saved it.
    final kept = {for (final c in _conversations) c.listingId, ..._favorites};
    final rows = await _db
        .from('listings')
        .select()
        .eq('university_id', _universityId!)
        .or(
          [
            'status.eq.available',
            'seller_id.eq.${_me.id}',
            if (kept.isNotEmpty) 'id.in.(${kept.join(',')})',
          ].join(','),
        )
        .eq('moderation_state', 'visible')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    _listings = await Future.wait([for (final r in rows) _listingFromRow(r)]);
  }

  Future<Listing> _listingFromRow(Map<String, dynamic> r) async {
    var image = r['cover_image_url'] as String?;
    if (image != null && !image.startsWith('https://')) {
      try {
        image = await ListingPhotoStorage(_db).resolve(image);
      } catch (_) {
        // A photo outage must not turn a successful listing write into failure.
        image = null;
      }
    }
    return Listing(
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
      universityId: r['university_id'] as String,
      status: r['status'] as String? ?? 'available',
      imageSource: image,
    );
  }

  Future<void> _refreshFavorites() async {
    final rows = await _db
        .from('favorites')
        .select('listing_id')
        .eq('user_id', _me.id);
    _favorites = {for (final r in rows) r['listing_id'] as String};
  }

  Future<void> _refreshBlocked() async {
    final rows = await _db
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', _me.id);
    _blocked = {for (final r in rows) r['blocked_id'] as String};
  }

  /// Hides [userId]'s listings and chats; the server also stops all
  /// messages and offers between you in both directions.
  Future<void> block(String userId) async {
    if (userId == _me.id || _blocked.contains(userId)) return;
    if (!isDemo) {
      _requireConfirmedAccount();
      await _db.from('blocks').insert({
        'blocker_id': _me.id,
        'blocked_id': userId,
      });
    }
    _blocked.add(userId);
    notifyListeners();
  }

  Future<void> unblock(String userId) async {
    if (!_blocked.contains(userId)) return;
    if (!isDemo) {
      _requireConfirmedAccount();
      await _db
          .from('blocks')
          .delete()
          .eq('blocker_id', _me.id)
          .eq('blocked_id', userId);
    }
    _blocked.remove(userId);
    notifyListeners();
  }

  /// Files a moderation report about [userId], optionally for one of their
  /// listings. [reason] is one of [reportReasons]' keys. Repeats are ignored.
  Future<void> report({
    required String userId,
    String? listingId,
    required String reason,
  }) async {
    if (!reportReasons.containsKey(reason)) {
      throw ArgumentError('Choose a reason for your report.');
    }
    if (isDemo) return;
    _requireConfirmedAccount();
    await _db.rpc(
      'report_user',
      params: {
        'p_reported_user_id': userId,
        'p_listing_id': listingId,
        'p_reason': reason,
      },
    );
  }

  /// Moderators (profiles.role = 'admin', set by the project owner) review
  /// reports at their university. The server re-checks on every call.
  bool get isAdmin => _isAdmin;
  bool _isAdmin = false;

  Future<List<AdminReport>> openReports() async {
    _requireConfirmedAccount();
    final rows = await _db.rpc('admin_open_reports') as List<dynamic>;
    final reports = [
      for (final r in rows) AdminReport.fromJson(r as Map<String, dynamic>),
    ];
    _setOpenReportCount(reports.length);
    return reports;
  }

  /// Open reports awaiting a moderator; 0 for everyone else.
  int get openReportCount => _openReportCount;
  int _openReportCount = 0;

  void _setOpenReportCount(int count) {
    if (count == _openReportCount) return;
    _openReportCount = count;
    notifyListeners();
  }

  /// Polls the moderator badge. A no-op for students and the demo.
  Future<void> refreshReportCount() async {
    if (!_isAdmin || isDemo) return;
    _requireConfirmedAccount();
    final count = await _db.rpc('admin_open_report_count') as num;
    _setOpenReportCount(count.toInt());
  }

  /// [action] is 'dismiss', 'hide_listing' or 'suspend_user'.
  Future<void> resolveReport(String reportId, String action) async {
    _requireConfirmedAccount();
    await _db.rpc(
      'admin_resolve_report',
      params: {'p_report_id': reportId, 'p_action': action},
    );
    // Hidden listings and suspended sellers leave the feed. The action has
    // committed, so failed reloads must not report failure.
    try {
      if (action != 'dismiss') await _refreshListings();
      final count = await _db.rpc('admin_open_report_count') as num;
      _openReportCount = count.toInt();
    } catch (_) {}
    notifyListeners();
  }

  /// Deletes your account on the server (anonymized profile, listings
  /// removed, open deals unwound, sign-in removed), then signs out here.
  Future<void> deleteAccount() async {
    _requireConfirmedAccount();
    await _db.rpc('delete_my_account');
    // The account is gone; clearing the local session cannot fail it.
    try {
      await _db.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  final Set<String> _togglingFavorites = {};

  Future<void> toggleFavorite(String listingId) async {
    // Ignore repeat taps while the first request is in flight.
    if (!_togglingFavorites.add(listingId)) return;
    try {
      await _toggleFavorite(listingId);
    } finally {
      _togglingFavorites.remove(listingId);
    }
  }

  Future<void> _toggleFavorite(String listingId) async {
    if (_favorites.contains(listingId)) {
      await _db
          .from('favorites')
          .delete()
          .eq('user_id', _me.id)
          .eq('listing_id', listingId);
      _favorites.remove(listingId);
    } else {
      await _db.from('favorites').insert({
        'user_id': _me.id,
        'listing_id': listingId,
      });
      _favorites.add(listingId);
    }
    notifyListeners();
  }

  Future<void> _refreshConversations([int attempt = 0]) async {
    final revision = _conversationRevision;
    final rows = await _db
        .from('conversations')
        .select()
        .or('buyer_id.eq.${_me.id},seller_id.eq.${_me.id}');
    final list = <Conversation>[];
    for (final r in rows) {
      list.add(await _hydrateConversation(r));
    }
    // Another refresh or confirmed write won while this snapshot was loading.
    // Preserve the newer cache and fetch again so a realtime event is not lost.
    if (_disposed) return;
    if (revision != _conversationRevision) {
      if (attempt >= 2) {
        throw StateError('Messages changed during refresh. Retry.');
      }
      return _refreshConversations(attempt + 1);
    }
    _conversations = list;
    _conversationRevision++;
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
      final offerRows = await _db
          .from('offers')
          .select()
          .inFilter('id', offerIds);
      offers = {for (final o in offerRows) o['id'] as String: o};
    }

    final messages = [
      for (final m in msgRows) _messageFromRow(m, offers, listingId),
    ];

    final isBuyer = buyerId == _me.id;
    final lastReadAt = DateTime.tryParse(
      (isBuyer ? row['buyer_last_read_at'] : row['seller_last_read_at'])
              as String? ??
          '',
    );
    // Unread = the other party has written since I last opened the thread.
    final unread = msgRows.any(
      (m) =>
          m['from_user_id'] != _me.id &&
          (lastReadAt == null ||
              (DateTime.tryParse(
                    m['created_at'] as String? ?? '',
                  )?.isAfter(lastReadAt) ??
                  false)),
    );

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
      return OfferMessage(
        offerId,
        from,
        amount,
        listingId,
        status,
        expiresAt: DateTime.tryParse(offer?['expires_at'] as String? ?? ''),
      );
    }
    return TextMessage(id, from, m['body'] as String? ?? '');
  }

  /// Finds-or-creates the conversation about [listingId] via the
  /// start_conversation RPC and caches it. Unlike the old Demo Mode version
  /// this is necessarily async — starting a conversation is a server call.
  Future<String> conversationForListing(String listingId) async {
    final id =
        await _db.rpc('start_conversation', params: {'p_listing_id': listingId})
            as String;
    await refreshConversation(id);
    return id;
  }

  /// Clears the unread dot for [conversationId]. Best effort: a failure only
  /// leaves the dot showing, so callers need not surface it.
  Future<void> markConversationRead(String conversationId) async {
    try {
      await _db.rpc(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
      await refreshConversation(conversationId);
    } catch (_) {}
  }

  /// Re-fetches one conversation (messages + offers) and updates the cache.
  /// Used after mutations and by the chat screen's realtime subscription.
  Future<void> refreshConversation(String conversationId) =>
      _refreshConversation(conversationId, 0);

  Future<void> _refreshConversation(String conversationId, int attempt) async {
    final revision = _conversationRevision;
    final row = await _db
        .from('conversations')
        .select()
        .eq('id', conversationId)
        .single();
    final conv = await _hydrateConversation(row);
    if (_disposed) return;
    if (revision != _conversationRevision) {
      if (attempt >= 2) {
        throw StateError('Messages changed during refresh. Retry.');
      }
      return _refreshConversation(conversationId, attempt + 1);
    }
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1) {
      _conversations.add(conv);
    } else {
      _conversations[idx] = conv;
    }
    _conversationRevision++;
    notifyListeners();
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final id =
        await _db.rpc(
              'create_message',
              params: {'p_conversation_id': conversationId, 'p_body': body},
            )
            as String;
    // The RPC has committed. Cache its receipt before attempting another
    // network request, so a read outage cannot invite a duplicate send.
    final current = getConversation(conversationId);
    if (current != null && !current.messages.any((m) => m.id == id)) {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      _conversations[index] = current.copyWith(
        messages: [
          ...current.messages,
          TextMessage(id, MessageFrom.me, body.trim()),
        ],
      );
      _conversationRevision++;
      notifyListeners();
    }
    try {
      await refreshConversation(conversationId);
    } catch (_) {
      // Chat synchronization handles refresh errors and retry independently.
    }
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
    if (action == 'accept') {
      // The listing is now reserved; drop the stale "available" copy. The
      // accept has committed, so a failed reload must not report failure.
      try {
        await _refreshListings();
        notifyListeners();
      } catch (_) {}
    }
  }

  /// Persist editable fields and cache only the row confirmed by the server.
  /// Backend RLS must independently enforce ownership and campus membership.
  Future<void> createListing({
    required String title,
    required int price,
    required Condition condition,
    required String category,
    required String description,
    required bool acceptsTrades,
    required String pickupZoneName,
    String? imageSource,
    String? editingId,
  }) async {
    final user = _db.auth.currentUser;
    if (!ready ||
        bootstrapError != null ||
        user == null ||
        user.id != _me.id ||
        user.isAnonymous ||
        user.emailConfirmedAt == null) {
      throw StateError(
        'Sign in with a confirmed university account before posting.',
      );
    }
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    if (cleanTitle.length < 3 || cleanTitle.length > 100) {
      throw ArgumentError('Use a title between 3 and 100 characters.');
    }
    if (cleanDescription.length < 10 || cleanDescription.length > 2000) {
      throw ArgumentError('Use a description between 10 and 2000 characters.');
    }
    if (price < 0 || price > 100000) {
      throw ArgumentError('Enter a whole-dollar price from 0 to 100000.');
    }
    if (!categories.contains(category)) {
      throw ArgumentError('Choose a valid category.');
    }
    final zones = _zoneNames.entries
        .where((e) => e.value == pickupZoneName)
        .toList();
    if (zones.length != 1) {
      throw ArgumentError(
        'Choose an available pickup location on your campus.',
      );
    }
    final existing = editingId == null ? null : getListing(editingId);
    if (editingId != null &&
        (existing == null ||
            existing.sellerId != _me.id ||
            existing.universityId != _universityId ||
            existing.status != 'available')) {
      throw StateError('Only your available listings can be edited.');
    }
    String? uploadedPath;
    if (imageSource != null && imageSource != existing?.imageSource) {
      final photo = ListingPhoto.fromDataUri(imageSource);
      uploadedPath = await ListingPhotoStorage(
        _db,
      ).upload(universityId: _universityId!, photo: photo);
    }
    final fields = <String, dynamic>{
      'cover_image_url': ?uploadedPath,
      if (uploadedPath != null) 'image_urls': [uploadedPath],
      'pickup_zone_id': zones.single.key,
      'title': cleanTitle,
      'description': cleanDescription,
      'price': price,
      'category': category,
      'condition': _conditionToDb(condition),
      'accepts_trades': acceptsTrades,
    };
    final Map<String, dynamic> row;
    if (editingId == null) {
      row = await _db
          .from('listings')
          .insert({
            ...fields,
            'seller_id': _me.id,
            'university_id': _universityId,
            'campus_id': _campusId,
          })
          .select()
          .single();
    } else {
      row = await _db
          .from('listings')
          .update(fields)
          .eq('id', editingId)
          .eq('seller_id', _me.id)
          .eq('university_id', _universityId!)
          .eq('status', 'available')
          .isFilter('deleted_at', null)
          .select()
          .single();
    }
    final saved = await _listingFromRow(row);
    final index = _listings.indexWhere((listing) => listing.id == saved.id);
    if (index < 0) {
      _listings.insert(0, saved);
    } else {
      _listings[index] = saved;
    }
    notifyListeners();
  }
}
