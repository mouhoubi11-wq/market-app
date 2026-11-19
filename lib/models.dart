import 'dart:convert';

class Announcement {
  final String id;
  final String title;
  final String description;
  final double price;
  final String categoryId;
  final String city;
  final String contactPhone;
  final String type;
  final bool isMine;
  final DateTime createdAt;
  final List<String> photoPaths;

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.city,
    required this.contactPhone,
    required this.type,
    this.isMine = false,
    required this.createdAt,
    this.photoPaths = const [],
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'a l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return 'il y a ${(diff.inDays / 7).floor()} sem.';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'price': price,
        'categoryId': categoryId,
        'city': city,
        'contactPhone': contactPhone,
        'type': type,
        'isMine': isMine,
        'createdAt': createdAt.toIso8601String(),
        'photoPaths': photoPaths,
      };

  factory Announcement.fromMap(Map<String, dynamic> m) => Announcement(
        id: m['id'],
        title: m['title'],
        description: m['description'],
        price: (m['price'] as num).toDouble(),
        categoryId: m['categoryId'],
        city: m['city'],
        contactPhone: m['contactPhone'],
        type: m['type'],
        isMine: m['isMine'] ?? false,
        createdAt: DateTime.parse(m['createdAt']),
        photoPaths: (m['photoPaths'] as List?)?.cast<String>() ?? const [],
      );

  String toJson() => jsonEncode(toMap());
}
