class Capsule {
  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime openDate;
  final DateTime createdAt;

  /// Photo kept inside the capsule (guest mode / old capsules).
  final String? imageBase64;

  /// Path of the photo in Supabase Storage (signed-in users).
  final String? mediaPath;

  /// 'image' for now.
  final String? mediaType;

  Capsule({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.openDate,
    required this.createdAt,
    this.imageBase64,
    this.mediaPath,
    this.mediaType,
  });

  bool get isUnlocked => !DateTime.now().isBefore(openDate);

  bool get hasImage => imageBase64 != null || mediaPath != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'category': category,
        'openDate': openDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'imageBase64': imageBase64,
        'mediaPath': mediaPath,
        'mediaType': mediaType,
      };

  factory Capsule.fromJson(Map<String, dynamic> json) {
    return Capsule(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      category: json['category'] as String,
      openDate: DateTime.parse(json['openDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      imageBase64: json['imageBase64'] as String?,
      mediaPath: json['mediaPath'] as String?,
      mediaType: json['mediaType'] as String?,
    );
  }

  /// Row for the Supabase `capsules` table.
  Map<String, dynamic> toRow(String userId) => {
        'id': id,
        'user_id': userId,
        'title': title,
        'message': message,
        'category': category,
        'open_date': openDate.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'image_base64': imageBase64,
        'media_path': mediaPath,
        'media_type': mediaType,
      };

  factory Capsule.fromRow(Map<String, dynamic> row) {
    return Capsule(
      id: row['id'] as String,
      title: row['title'] as String,
      message: row['message'] as String,
      category: row['category'] as String,
      openDate: DateTime.parse(row['open_date'] as String).toLocal(),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      imageBase64: row['image_base64'] as String?,
      mediaPath: row['media_path'] as String?,
      mediaType: row['media_type'] as String?,
    );
  }
}