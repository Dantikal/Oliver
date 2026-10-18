class Comment {
  const Comment({
    required this.id,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.text,
    this.parentCommentId,
    this.likesCount = 0,
    this.isLiked = false,
    required this.createdAt,
    this.replies = const [],
  });

  final String id;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String text;
  final String? parentCommentId;
  final int likesCount;
  final bool isLiked;
  final DateTime createdAt;
  final List<Comment> replies;

  int get totalReplies =>
      replies.fold(replies.length, (s, r) => s + r.totalReplies);

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'].toString(),
        userId: j['userId'].toString(),
        fullName: (j['fullName'] ?? '') as String,
        avatarUrl: j['avatarUrl'] as String?,
        text: (j['text'] ?? '') as String,
        parentCommentId: j['parentCommentId']?.toString(),
        likesCount: (j['likesCount'] ?? 0) as int,
        isLiked: (j['isLiked'] ?? false) as bool,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        replies: ((j['replies'] ?? const []) as List)
            .map((e) => Comment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Comment copyWith({int? likesCount, bool? isLiked, List<Comment>? replies}) =>
      Comment(
        id: id,
        userId: userId,
        fullName: fullName,
        avatarUrl: avatarUrl,
        text: text,
        parentCommentId: parentCommentId,
        likesCount: likesCount ?? this.likesCount,
        isLiked: isLiked ?? this.isLiked,
        createdAt: createdAt,
        replies: replies ?? this.replies,
      );

  /// Рекурсивно применяет [f] к комментарию с [targetId] в дереве.
  Comment mapTree(String targetId, Comment Function(Comment) f) {
    if (id == targetId) return f(this);
    return copyWith(
        replies: replies.map((r) => r.mapTree(targetId, f)).toList());
  }

  Comment? removeFromTree(String targetId) {
    if (id == targetId) return null;
    return copyWith(
      replies: replies
          .map((r) => r.removeFromTree(targetId))
          .whereType<Comment>()
          .toList(),
    );
  }
}
