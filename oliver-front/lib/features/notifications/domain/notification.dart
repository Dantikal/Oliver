import '../../../core/pagination/paged.dart';

enum NotificationType { like, comment, message, system }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.text,
    required this.createdAt,
    this.actorName,
    this.actorAvatar,
    this.productId,
    this.productImage,
    this.isRead = false,
  });

  final String id;
  final NotificationType type;
  final String text;
  final DateTime createdAt;
  final String? actorName;
  final String? actorAvatar;
  final String? productId;
  final String? productImage;
  final bool isRead;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'].toString(),
        type: NotificationType.values.firstWhere(
          (t) => t.name.toUpperCase() == '${j['type']}'.toUpperCase(),
          orElse: () => NotificationType.system,
        ),
        text: (j['text'] ?? j['message'] ?? '') as String,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        actorName: j['actorName'] as String?,
        actorAvatar: j['actorAvatarUrl'] as String?,
        productId: j['productId']?.toString(),
        productImage: j['productImageUrl'] as String?,
        isRead: (j['isRead'] ?? j['read'] ?? false) as bool,
      );

  AppNotification markRead() => AppNotification(
        id: id,
        type: type,
        text: text,
        createdAt: createdAt,
        actorName: actorName,
        actorAvatar: actorAvatar,
        productId: productId,
        productImage: productImage,
        isRead: true,
      );
}

class Counters {
  const Counters(
      {this.unreadMessages = 0,
      this.newLikes = 0,
      this.unreadNotifications = 0});
  final int unreadMessages;
  final int newLikes;
  final int unreadNotifications;

  int get chatsBadge => unreadMessages + newLikes;

  factory Counters.fromJson(Map<String, dynamic> j) => Counters(
        unreadMessages: (j['unreadMessages'] ?? 0) as int,
        newLikes: (j['newLikes'] ?? 0) as int,
        unreadNotifications: (j['unreadNotifications'] ?? 0) as int,
      );

  Counters copyWith(
          {int? unreadMessages, int? newLikes, int? unreadNotifications}) =>
      Counters(
        unreadMessages: unreadMessages ?? this.unreadMessages,
        newLikes: newLikes ?? this.newLikes,
        unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      );
}

abstract class NotificationRepository {
  Future<PageResult<AppNotification>> list(int page);
  Future<Counters> counters();
  Future<void> markRead(List<String> ids);
}
