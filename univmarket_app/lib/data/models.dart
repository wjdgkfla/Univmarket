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

  const Listing({
    required this.id,
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

  Conversation copyWith({List<ChatMessage>? messages}) => Conversation(
    id: id,
    sellerId: sellerId,
    listingId: listingId,
    unread: unread,
    messages: messages ?? this.messages,
  );
}
