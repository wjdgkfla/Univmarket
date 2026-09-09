import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'repository.dart';

/// Local sandbox only. This adapter never authenticates or contacts Supabase.
class DemoRepository extends Repository {
  DemoRepository._(this._prefs) : super.offline();
  final SharedPreferences _prefs;
  static const _key = 'univmarket.demo.v1';
  static const schools = {
    'gmu': 'George Mason University',
    'vt': 'Virginia Tech',
    'umd': 'University of Maryland',
  };
  String _school = 'gmu';
  List<Listing> _items = [];
  Set<String> _saved = {};
  List<Conversation> _threads = [];
  int _sequence = 0;
  late String _committedSnapshot;
  int _writeEpoch = 0;
  Future<void> _writes = Future.value();
  @override
  bool get isDemo => true;
  @override
  String get universityId => _school;
  @override
  Map<String, String> get universities => schools;
  @override
  List<String> get pickupZones => const [
    'Student center',
    'Main library',
    'Residence hall lobby',
  ];
  @override
  Profile get me => Profile(
    id: 'demo-me',
    name: 'Your demo profile',
    initials: 'YOU',
    school: schools[_school]!,
    rating: 0,
    dealsDone: 0,
    meetupsKeptPct: 0,
    avgReplyTime: '—',
  );
  @override
  Set<String> get favorites => Set.unmodifiable(_saved);
  @override
  List<Listing> listListings() =>
      List.unmodifiable(_items.where((l) => l.universityId == _school));
  @override
  Listing? getListing(String id) {
    for (final item in listListings()) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Profile? getSeller(String id) => id == me.id
      ? me
      : Profile(
          id: id,
          name: id.endsWith('alex') ? 'Alex Morgan' : 'Sam Rivera',
          initials: id.endsWith('alex') ? 'AM' : 'SR',
          school: schools[_school]!,
          rating: 0,
          dealsDone: 0,
          meetupsKeptPct: 0,
          avgReplyTime: 'Demo seller',
        );
  @override
  List<Conversation> listConversations() =>
      List.unmodifiable(_threads.where((t) => getListing(t.listingId) != null));
  @override
  Conversation? getConversation(String id) {
    for (final t in listConversations()) {
      if (t.id == id) return t;
    }
    return null;
  }

  static Future<DemoRepository> open() async {
    final repo = DemoRepository._(await SharedPreferences.getInstance());
    final saved = repo._prefs.getString(_key);
    if (saved == null) {
      repo._seed();
    } else {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      repo._school = data['school'] as String;
      if (!schools.containsKey(repo._school)) {
        throw const FormatException('Unknown saved university');
      }
      repo._sequence = data['sequence'] as int;
      repo._items = (data['listings'] as List)
          .map((v) => Listing.fromJson(v))
          .toList();
      repo._saved = (data['favorites'] as List).cast<String>().toSet();
      repo._threads = (data['threads'] as List)
          .map((v) => Conversation.fromJson(v))
          .toList();
    }
    repo._committedSnapshot = repo._snapshot();
    repo.ready = true;
    return repo;
  }

  void _seed() {
    const inventory = [
      (
        'Calculus textbook, 9th edition',
        28,
        'Textbooks',
        'book',
        'A clean copy with a few helpful notes. Sample listing.',
        'books.jpg',
      ),
      (
        'Sony wireless headphones',
        85,
        'Electronics',
        'headphones',
        'Comfortable over-ear headphones with case. Sample listing.',
        'headphones.jpg',
      ),
      (
        'Reading chair',
        45,
        'Furniture',
        'chair',
        'A comfortable chair for your study corner. Sample listing.',
        'chair.jpg',
      ),
      (
        'Everyday campus bike',
        120,
        'Bikes',
        'bike',
        'Ready for the ride to class. Sample listing.',
        'bike.jpg',
      ),
      (
        'Adjustable desk lamp',
        18,
        'Dorm',
        'lamp',
        'Warm light for late-night studying. Sample listing.',
        'lamp.jpg',
      ),
      (
        'Canvas everyday backpack',
        24,
        'Bags',
        'bag',
        'Room for a laptop and your books. Sample listing.',
        'bag.jpg',
      ),
    ];
    for (final school in schools.keys) {
      for (var i = 0; i < inventory.length; i++) {
        final (title, price, category, icon, description, photo) = inventory[i];
        _items.add(
          Listing(
            id: '$school-item-$i',
            icon: icon,
            title: title,
            price: price,
            condition: i.isEven ? Condition.good : Condition.likeNew,
            zone: pickupZones[i % pickupZones.length],
            tag: category,
            trades: false,
            description: description,
            sellerId: '$school-alex',
            universityId: school,
            imageSource: 'assets/images/$photo',
          ),
        );
      }
      _threads.add(
        Conversation(
          id: '$school-welcome',
          sellerId: '$school-alex',
          listingId: '$school-item-1',
          unread: true,
          messages: [
            const SystemMessage(
              'demo-note',
              'Demo conversation — no messages are sent to real people.',
            ),
            const TextMessage(
              'hello',
              MessageFrom.them,
              'Try accepting this sample offer to reserve the item.',
            ),
            OfferMessage(
              '$school-sample-offer',
              MessageFrom.them,
              75,
              '$school-item-1',
              OfferStatus.pending,
            ),
          ],
        ),
      );
    }
  }

  String _id(String type) =>
      '$type-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  String _snapshot() => jsonEncode({
    'school': _school,
    'sequence': _sequence,
    'listings': _items.map((l) => l.toJson()).toList(),
    'favorites': _saved.toList(),
    'threads': _threads.map((t) => t.toJson()).toList(),
  });
  void _restore(String snapshot) {
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    _school = data['school'] as String;
    _sequence = data['sequence'] as int;
    _items = (data['listings'] as List)
        .map((v) => Listing.fromJson(v))
        .toList();
    _saved = (data['favorites'] as List).cast<String>().toSet();
    _threads = (data['threads'] as List)
        .map((v) => Conversation.fromJson(v))
        .toList();
  }

  Future<void> _save() {
    final snapshot = _snapshot();
    final epoch = _writeEpoch;
    final operation = _writes.then((_) async {
      if (epoch != _writeEpoch) {
        throw StateError('A previous save failed. Please retry your change.');
      }
      try {
        if (!await _prefs.setString(_key, snapshot)) {
          throw StateError(
            'Could not save changes on this device. Try a smaller photo or free storage.',
          );
        }
        _committedSnapshot = snapshot;
      } catch (_) {
        _writeEpoch++;
        _restore(_committedSnapshot);
        // SharedPreferences updates its memory cache before a write succeeds.
        // Reload it so opening a second repository cannot read the failed value.
        await _prefs.reload();
        notifyListeners();
        rethrow;
      }
      notifyListeners();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<void> selectUniversity(String id) async {
    if (!schools.containsKey(id)) throw ArgumentError('Unknown university');
    _school = id;
    await _save();
  }

  @override
  Future<void> toggleFavorite(String listingId) async {
    if (getListing(listingId) == null) {
      throw StateError('Listing unavailable in this university');
    }
    if (!_saved.remove(listingId)) _saved.add(listingId);
    await _save();
  }

  @override
  Future<String> conversationForListing(String listingId) async {
    final listing = getListing(listingId);
    if (listing == null || listing.sellerId == me.id) {
      throw StateError('Choose another seller’s listing');
    }
    for (final t in listConversations()) {
      if (t.listingId == listingId) return t.id;
    }
    final id = _id('chat');
    _threads.add(
      Conversation(
        id: id,
        sellerId: listing.sellerId,
        listingId: listingId,
        unread: false,
        messages: [
          const SystemMessage(
            'demo',
            'Demo conversation — messages stay on this device.',
          ),
        ],
      ),
    );
    await _save();
    return id;
  }

  void _updateThread(Conversation thread) {
    final i = _threads.indexWhere((t) => t.id == thread.id);
    _threads[i] = thread;
  }

  @override
  Future<void> refreshConversation(String conversationId) async {}
  @override
  Future<void> sendMessage(String conversationId, String body) async {
    final thread = getConversation(conversationId);
    if (thread == null) throw StateError('Conversation unavailable');
    if (body.trim().isEmpty || body.length > 2000) {
      throw ArgumentError('Message must be 1–2000 characters.');
    }
    _updateThread(
      thread.copyWith(
        messages: [
          ...thread.messages,
          TextMessage(_id('message'), MessageFrom.me, body.trim()),
        ],
      ),
    );
    await _save();
  }

  @override
  Future<void> sendOffer(String conversationId, int amount) async {
    final thread = getConversation(conversationId);
    if (thread == null || getListing(thread.listingId)?.status != 'available') {
      throw StateError('This item is no longer available.');
    }
    if (amount <= 0 || amount > 100000) {
      throw ArgumentError('Enter an offer between 1 and 100000.');
    }
    _updateThread(
      thread.copyWith(
        messages: [
          ...thread.messages,
          OfferMessage(
            _id('offer'),
            MessageFrom.me,
            amount,
            thread.listingId,
            OfferStatus.pending,
          ),
        ],
      ),
    );
    await _save();
  }

  @override
  Future<void> acceptOffer(String conversationId, String offerId) =>
      _respond(conversationId, offerId, OfferStatus.accepted);
  @override
  Future<void> declineOffer(String conversationId, String offerId) =>
      _respond(conversationId, offerId, OfferStatus.declined);
  Future<void> _respond(
    String conversationId,
    String offerId,
    OfferStatus status,
  ) async {
    final thread = getConversation(conversationId);
    if (thread == null) throw StateError('Conversation unavailable');
    final offer = thread.messages
        .whereType<OfferMessage>()
        .where((m) => m.id == offerId)
        .firstOrNull;
    if (offer == null ||
        offer.from != MessageFrom.them ||
        offer.status != OfferStatus.pending) {
      throw StateError('Only a pending received offer can be answered.');
    }
    final listing = getListing(thread.listingId);
    if (listing == null || listing.status != 'available') {
      throw StateError('This item is no longer available.');
    }
    _updateThread(
      thread.copyWith(
        messages: [
          for (final m in thread.messages)
            m.id == offer.id ? offer.copyWith(status: status) : m,
          if (status == OfferStatus.accepted)
            const SystemMessage(
              'reserved',
              'Item reserved in this demo. Arrange a pickup in the conversation.',
            ),
        ],
      ),
    );
    if (status == OfferStatus.accepted) {
      _items[_items.indexWhere((l) => l.id == listing.id)] = listing.copyWith(
        status: 'reserved',
      );
      for (var i = 0; i < _threads.length; i++) {
        final t = _threads[i];
        if (t.listingId == listing.id) {
          _threads[i] = t.copyWith(
            messages: [
              for (final m in t.messages)
                if (m is OfferMessage &&
                    m.id != offerId &&
                    m.status == OfferStatus.pending)
                  m.copyWith(status: OfferStatus.declined)
                else
                  m,
            ],
          );
        }
      }
    }
    await _save();
  }

  @override
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
    if (title.trim().length < 3 || title.trim().length > 100) {
      throw ArgumentError('Title must be 3–100 characters.');
    }
    if (price < 0 || price > 100000) {
      throw ArgumentError('Price must be between 0 and 100000.');
    }
    if (description.trim().length < 10 || description.length > 2000) {
      throw ArgumentError('Description must be 10–2000 characters.');
    }
    if (!categories.contains(category) ||
        !pickupZones.contains(pickupZoneName)) {
      throw ArgumentError('Choose a valid category and pickup location.');
    }
    final existing = editingId == null ? null : getListing(editingId);
    if (editingId != null && (existing == null || existing.sellerId != me.id)) {
      throw StateError('You can only edit your own listings.');
    }
    final listing = Listing(
      id: editingId ?? _id('listing'),
      icon: categoryIcons[category]!,
      title: title.trim(),
      price: price,
      condition: condition,
      zone: pickupZoneName,
      tag: category,
      trades: acceptsTrades,
      description: description.trim(),
      sellerId: me.id,
      universityId: _school,
      imageSource: imageSource,
      status: existing?.status ?? 'available',
    );
    if (editingId != null) {
      _items[_items.indexWhere((l) => l.id == editingId)] = listing;
    } else {
      _items.insert(0, listing);
    }
    await _save();
  }

  @override
  Future<void> markSold(String id) async {
    final listing = getListing(id);
    if (listing == null || listing.sellerId != me.id) {
      throw StateError('You can only manage your own listings.');
    }
    _items[_items.indexWhere((l) => l.id == id)] = listing.copyWith(
      status: 'sold',
    );
    await _save();
  }
}
