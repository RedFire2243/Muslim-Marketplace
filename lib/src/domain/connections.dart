import 'json.dart';
import 'taxonomy.dart';

/// A request from one member to another, usually about a listing.
///
/// Accepting a request opens a private conversation. It does not mean a job
/// was offered or accepted.
class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.senderId,
    required this.recipientId,
    this.listingId,
    this.listingTitle,
    required this.message,
    this.status = RequestStatus.pending,
    required this.createdAt,
    this.respondedAt,
    this.conversationId,
  });

  final String id;
  final String senderId;
  final String recipientId;

  /// Null for a general introduction, or after the listing was deleted.
  final String? listingId;

  /// Title at the time of the request, kept for context.
  final String? listingTitle;
  final String message;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? conversationId;

  bool involves(String userId) => senderId == userId || recipientId == userId;
  String otherParty(String me) => me == senderId ? recipientId : senderId;

  ConnectionRequest copyWith({
    RequestStatus? status,
    DateTime? respondedAt,
    String? conversationId,
  }) => ConnectionRequest(
    id: id,
    senderId: senderId,
    recipientId: recipientId,
    listingId: listingId,
    listingTitle: listingTitle,
    message: message,
    status: status ?? this.status,
    createdAt: createdAt,
    respondedAt: respondedAt ?? this.respondedAt,
    conversationId: conversationId ?? this.conversationId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'senderId': senderId,
    'recipientId': recipientId,
    'listingId': listingId,
    'listingTitle': listingTitle,
    'message': message,
    'status': status.wire,
    'createdAt': writeDate(createdAt),
    'respondedAt': writeDate(respondedAt),
    'conversationId': conversationId,
  };

  factory ConnectionRequest.fromJson(Map<String, Object?> json) =>
      ConnectionRequest(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        recipientId: json['recipientId'] as String,
        listingId: readOptionalString(json['listingId']),
        listingTitle: readOptionalString(json['listingTitle']),
        message: json['message'] as String? ?? '',
        status: RequestStatus.fromWire(json['status'] as String? ?? 'pending'),
        createdAt: readDate(json['createdAt']),
        respondedAt: readOptionalDate(json['respondedAt']),
        conversationId: readOptionalString(json['conversationId']),
      );
}

/// A private conversation between the two people in an accepted request.
class Conversation {
  const Conversation({
    required this.id,
    required this.requestId,
    required this.participantIds,
    this.listingId,
    this.listingTitle,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
  });

  final String id;
  final String requestId;

  /// Exactly two member ids.
  final List<String> participantIds;
  final String? listingId;
  final String? listingTitle;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;

  bool hasParticipant(String userId) => participantIds.contains(userId);

  String otherParticipant(String me) =>
      participantIds.firstWhere((id) => id != me, orElse: () => me);

  DateTime get sortTime => lastMessageAt ?? createdAt;

  Conversation withLastMessage(Message m) => Conversation(
    id: id,
    requestId: requestId,
    participantIds: participantIds,
    listingId: listingId,
    listingTitle: listingTitle,
    createdAt: createdAt,
    lastMessageAt: m.createdAt,
    lastMessagePreview: m.body.length > 120
        ? '${m.body.substring(0, 117)}...'
        : m.body,
    lastMessageSenderId: m.senderId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'requestId': requestId,
    'participantIds': participantIds,
    'listingId': listingId,
    'listingTitle': listingTitle,
    'createdAt': writeDate(createdAt),
    'lastMessageAt': writeDate(lastMessageAt),
    'lastMessagePreview': lastMessagePreview,
    'lastMessageSenderId': lastMessageSenderId,
  };

  factory Conversation.fromJson(Map<String, Object?> json) => Conversation(
    id: json['id'] as String,
    requestId: json['requestId'] as String,
    participantIds: readStrings(json['participantIds']),
    listingId: readOptionalString(json['listingId']),
    listingTitle: readOptionalString(json['listingTitle']),
    createdAt: readDate(json['createdAt']),
    lastMessageAt: readOptionalDate(json['lastMessageAt']),
    lastMessagePreview: readOptionalString(json['lastMessagePreview']),
    lastMessageSenderId: readOptionalString(json['lastMessageSenderId']),
  );
}

/// A persisted text message.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.clientId,
  });

  static const maxLength = 2000;

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  /// Generated by the sending client so a retried send is not duplicated.
  final String clientId;

  Map<String, Object?> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'body': body,
    'createdAt': writeDate(createdAt),
    'clientId': clientId,
  };

  factory Message.fromJson(Map<String, Object?> json) => Message(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    senderId: json['senderId'] as String,
    body: json['body'] as String? ?? '',
    createdAt: readDate(json['createdAt']),
    clientId: json['clientId'] as String? ?? json['id'] as String,
  );
}

/// A listing the member saved for later.
class SavedListing {
  const SavedListing({
    required this.userId,
    required this.listingId,
    required this.savedAt,
  });

  final String userId;
  final String listingId;
  final DateTime savedAt;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'listingId': listingId,
    'savedAt': writeDate(savedAt),
  };

  factory SavedListing.fromJson(Map<String, Object?> json) => SavedListing(
    userId: json['userId'] as String,
    listingId: json['listingId'] as String,
    savedAt: readDate(json['savedAt']),
  );
}
