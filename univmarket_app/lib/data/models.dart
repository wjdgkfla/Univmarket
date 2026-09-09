enum Condition { fair, good, likeNew }

extension ConditionLabel on Condition {
  String get label => switch (this) {
    Condition.fair => 'Fair',
    Condition.good => 'Good',
    Condition.likeNew => 'Like New',
  };
}

class Listing {
  final String id;
  final String icon; // key into categoryMesh
  final String title;
  final int price;
  final Condition condition;
  final String zone;
  final String tag;
  final bool trades;
  final String description;
  final String sellerId;

  factory Listing.fromJson(Map<String, dynamic> v) => Listing(
    id: v['id'],
    icon: v['icon'],
    title: v['title'],
    price: v['price'],
    condition: Condition.values.byName(v['condition']),
    zone: v['zone'],
    tag: v['tag'],
    trades: v['trades'],
    description: v['description'],
    sellerId: v['sellerId'],
    universityId: v['universityId'],
    imageSource: v['imageSource'],
    status: v['status'],
  );
  final String universityId;
  final String? imageSource;
  final String status;

  const Listing({
    required this.id,
    this.universityId = '',
    this.imageSource,
    this.status = 'available',
    required this.icon,
    required this.title,
    required this.price,
    required this.condition,
    required this.zone,
    required this.tag,
    required this.trades,
    required this.description,
    required this.sellerId,
  });
}

class Profile {
  final String id;
  final String name;
  final String initials;
  final String school;
  final double rating;
  final int dealsDone;
  final int meetupsKeptPct;
  final String avgReplyTime;

  const Profile({
    required this.id,
    required this.name,
    required this.initials,
    required this.school,
    required this.rating,
    required this.dealsDone,
    required this.meetupsKeptPct,
    required this.avgReplyTime,
  });
}

extension ListingJson on Listing {
  Map<String, dynamic> toJson() => {
    'id': id,
    'icon': icon,
    'title': title,
    'price': price,
    'condition': condition.name,
    'zone': zone,
    'tag': tag,
    'trades': trades,
    'description': description,
    'sellerId': sellerId,
    'universityId': universityId,
    'imageSource': imageSource,
    'status': status,
  };
  Listing copyWith({String? status}) =>
      Listing.fromJson({...toJson(), 'status': status ?? this.status});
}

enum OfferStatus { pending, accepted, declined }

enum MessageFrom { me, them }

sealed class ChatMessage {
  final String id;
  const ChatMessage(this.id);
}

class TextMessage extends ChatMessage {
  final MessageFrom from;
  final String body;
  const TextMessage(super.id, this.from, this.body);
}

class SystemMessage extends ChatMessage {
  final String body;
  const SystemMessage(super.id, this.body);
}

class OfferMessage extends ChatMessage {
  final MessageFrom from;
  final int amount;
  final String listingId;
  final OfferStatus status;
  const OfferMessage(
    super.id,
    this.from,
    this.amount,
    this.listingId,
    this.status,
  );

  OfferMessage copyWith({OfferStatus? status}) =>
      OfferMessage(id, from, amount, listingId, status ?? this.status);
}

class Conversation {
  final String id;
  final String sellerId;
  final String listingId;
  final bool unread;
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    required this.sellerId,
    required this.listingId,
    required this.unread,
    required this.messages,
  });

  factory Conversation.fromJson(Map<String, dynamic> v) => Conversation(
    id: v['id'],
    sellerId: v['sellerId'],
    listingId: v['listingId'],
    unread: v['unread'],
    messages: (v['messages'] as List)
        .map(
          (m) => switch (m['type']) {
            'offer' => OfferMessage(
              m['id'],
              MessageFrom.values.byName(m['from']),
              m['amount'],
              m['listingId'],
              OfferStatus.values.byName(m['status']),
            ),
            'text' => TextMessage(
              m['id'],
              MessageFrom.values.byName(m['from']),
              m['body'],
            ),
            _ => SystemMessage(m['id'], m['body']),
          },
        )
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'sellerId': sellerId,
    'listingId': listingId,
    'unread': unread,
    'messages': messages
        .map(
          (m) => switch (m) {
            OfferMessage() => {
              'type': 'offer',
              'id': m.id,
              'from': m.from.name,
              'amount': m.amount,
              'listingId': m.listingId,
              'status': m.status.name,
            },
            TextMessage() => {
              'type': 'text',
              'id': m.id,
              'from': m.from.name,
              'body': m.body,
            },
            SystemMessage() => {'type': 'system', 'id': m.id, 'body': m.body},
          },
        )
        .toList(),
  };

  Conversation copyWith({List<ChatMessage>? messages}) => Conversation(
    id: id,
    sellerId: sellerId,
    listingId: listingId,
    unread: unread,
    messages: messages ?? this.messages,
  );
}
