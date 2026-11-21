import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'photo_helper.dart';

enum SortMode { recent, priceAsc, priceDesc }

/// Une page d'annonces + savoir s'il en reste à charger.
class AdPage {
  final List<Announcement> items;
  final bool hasMore;
  const AdPage(this.items, this.hasMore);
}

/// Transforme une erreur technique en message clair pour l'utilisateur.
String friendlyError(Object e) {
  if (e is PostgrestException && e.message.contains('LIMITE:')) {
    return e.message.substring(e.message.indexOf('LIMITE:') + 7).trim();
  }
  final raw = e.toString();
  if (e is SocketException ||
      e is TimeoutException ||
      raw.contains('SocketException') ||
      raw.contains('ClientException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Connection closed') ||
      raw.contains('Connection reset') ||
      raw.contains('Connection refused')) {
    return 'Pas de connexion internet. Vérifiez votre réseau et réessayez.';
  }
  if (e is StorageException) {
    return 'Échec de l\'envoi d\'une photo. Réessayez, ou choisissez des photos moins lourdes.';
  }
  if (e is AuthException) {
    return 'Connexion au serveur impossible. Réessayez dans un instant.';
  }
  if (e is PostgrestException) {
    return 'Erreur du serveur. Réessayez dans un instant.';
  }
  return 'Une erreur est survenue. Réessayez.';
}

class AnnouncementRepository {
  static const pageSize = 20;
  static const _timeout = Duration(seconds: 25);

  // Clés locales. « v2 » : les anciens favoris (ids locaux) ne sont pas repris.
  static const _favKey = 'favorites_v2';
  static const _blockedKey = 'blocked_owners_v1';

  static final _uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  static Future<void>? _signingIn;

  SupabaseClient get _db => Supabase.instance.client;

  // ------------------------------------------------------------------
  //  Connexion anonyme (une seule fois, même si plusieurs appels en même temps)
  // ------------------------------------------------------------------
  static Future<void> ensureSignedIn() {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return Future.value();
    final existing = _signingIn;
    if (existing != null) return existing;
    final f = auth
        .signInAnonymously()
        .timeout(const Duration(seconds: 20))
        .then((_) {})
        .whenComplete(() => _signingIn = null);
    _signingIn = f;
    return f;
  }

  // ------------------------------------------------------------------
  //  Lecture
  // ------------------------------------------------------------------
  Future<AdPage> fetchPage({
    required int page,
    String search = '',
    String? categoryId,
    String? type,
    SortMode sort = SortMode.recent,
    Set<String> blocked = const {},
  }) async {
    await ensureSignedIn();

    var query = _db.from('announcements').select();
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (type != null) query = query.eq('type', type);

    // On retire les caractères qui casseraient la syntaxe du filtre.
    final s = search.replaceAll(RegExp(r'[,()%*\\"]'), ' ').trim();
    if (s.isNotEmpty) {
      query = query.or(
          'title.ilike.%$s%,description.ilike.%$s%,city.ilike.%$s%');
    }

    final ordered = switch (sort) {
      SortMode.recent => query.order('created_at', ascending: false),
      SortMode.priceAsc => query.order('price', ascending: true),
      SortMode.priceDesc => query.order('price', ascending: false),
    };

    final from = page * pageSize;
    final rows = await ordered
        .order('id', ascending: true)
        .range(from, from + pageSize - 1)
        .timeout(_timeout);

    final items = rows
        .map((r) => Announcement.fromRow(r))
        .where((a) => !blocked.contains(a.ownerId))
        .toList();
    return AdPage(items, rows.length == pageSize);
  }

  Future<List<Announcement>> fetchMine() async {
    await ensureSignedIn();
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _db
        .from('announcements')
        .select()
        .eq('owner_id', uid)
        .order('created_at', ascending: false)
        .timeout(_timeout);
    return rows.map((r) => Announcement.fromRow(r)).toList();
  }

  Future<List<Announcement>> fetchByIds(Set<String> ids) async {
    // Les 60 favoris les plus récents (limite la longueur de la requête).
    final valid =
        ids.toList().reversed.where(_uuidRe.hasMatch).take(60).toList();
    if (valid.isEmpty) return [];
    await ensureSignedIn();
    final rows = await _db
        .from('announcements')
        .select()
        .inFilter('id', valid)
        .order('created_at', ascending: false)
        .timeout(_timeout);
    return rows.map((r) => Announcement.fromRow(r)).toList();
  }

  // ------------------------------------------------------------------
  //  Écriture
  // ------------------------------------------------------------------
  Future<void> add({
    required String title,
    required String description,
    required double price,
    required String categoryId,
    required String city,
    required String contactPhone,
    required String type,
    required List<String> localPhotoPaths,
    void Function(int current, int total)? onProgress,
  }) async {
    await ensureSignedIn();
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw AuthException('Utilisateur non connecté');

    final urls = <String>[];
    try {
      for (var i = 0; i < localPhotoPaths.length; i++) {
        onProgress?.call(i + 1, localPhotoPaths.length);
        urls.add(await uploadPhoto(localPhotoPaths[i], index: i));
      }
      await _db.from('announcements').insert({
        'owner_id': uid,
        'title': title,
        'description': description,
        'price': price,
        'category_id': categoryId,
        'city': city,
        'contact_phone': contactPhone,
        'type': type,
        'photo_urls': urls,
      }).timeout(_timeout);
    } catch (e) {
      // Pas d'annonce créée : on nettoie les photos déjà envoyées.
      await deletePhotosByUrl(urls);
      rethrow;
    }
  }

  /// Supprime l'annonce d'abord, puis ses photos (une photo orpheline est sans gravité,
  /// alors qu'une annonce sans photos serait visible et cassée).
  Future<void> delete(Announcement a) async {
    await ensureSignedIn();
    await _db.from('announcements').delete().eq('id', a.id).timeout(_timeout);
    await deletePhotosByUrl(a.photoUrls);
  }

  Future<void> report(String announcementId, String reason) async {
    await ensureSignedIn();
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw AuthException('Utilisateur non connecté');
    try {
      await _db.from('reports').insert({
        'announcement_id': announcementId,
        'reporter_id': uid,
        'reason': reason,
      }).timeout(_timeout);
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // déjà signalée par cet utilisateur
      rethrow;
    }
  }

  // ------------------------------------------------------------------
  //  Données gardées sur le téléphone : favoris et utilisateurs bloqués
  // ------------------------------------------------------------------
  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favKey) ?? []).toSet();
  }

  Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_favKey) ?? <String>[];
    if (favs.contains(id)) {
      favs.remove(id);
    } else {
      favs.add(id);
    }
    await prefs.setStringList(_favKey, favs);
  }

  Future<Set<String>> loadBlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_blockedKey) ?? []).toSet();
  }

  Future<void> blockOwner(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_blockedKey) ?? <String>[];
    if (!list.contains(ownerId)) list.add(ownerId);
    await prefs.setStringList(_blockedKey, list);
  }
}
