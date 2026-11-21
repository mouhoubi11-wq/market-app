import 'package:supabase_flutter/supabase_flutter.dart';

class Announcement {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final double price;
  final String categoryId;
  final String city;
  final String contactPhone;
  final String type;
  final DateTime createdAt;
  final List<String> photoUrls;

  const Announcement({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.city,
    required this.contactPhone,
    required this.type,
    required this.createdAt,
    this.photoUrls = const [],
  });

  /// Vrai si l'annonce appartient à l'utilisateur connecté (calculé, jamais stocké).
  bool get isMine {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return uid != null && uid == ownerId;
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    if (diff.inDays < 28) return 'il y a ${(diff.inDays / 7).floor()} sem.';
    final d = createdAt;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return 'le $dd/$mm/${d.year}';
  }

  /// Construit une annonce à partir d'une ligne de la table `announcements`.
  factory Announcement.fromRow(Map<String, dynamic> m) => Announcement(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        price: (m['price'] as num).toDouble(),
        categoryId: m['category_id'] as String,
        city: m['city'] as String,
        contactPhone: m['contact_phone'] as String,
        type: m['type'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        photoUrls: ((m['photo_urls'] as List?) ?? const []).cast<String>(),
      );
}
