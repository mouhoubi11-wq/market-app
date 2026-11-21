import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

const String kPhotosBucket = 'photos';

/// Envoie une photo vers le stockage en ligne et renvoie son adresse web.
/// La photo est rangée dans le dossier de l'utilisateur : <son id>/<nom>.
/// En cas d'échec, l'exception remonte (l'appelant prévient l'utilisateur).
Future<String> uploadPhoto(String localPath, {required int index}) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) {
    throw AuthException('Utilisateur non connecté');
  }

  final lower = localPath.toLowerCase();
  var ext = 'jpg';
  var mime = 'image/jpeg';
  if (lower.endsWith('.png')) {
    ext = 'png';
    mime = 'image/png';
  } else if (lower.endsWith('.webp')) {
    ext = 'webp';
    mime = 'image/webp';
  }

  final name = '$uid/${DateTime.now().microsecondsSinceEpoch}_$index.$ext';
  final bucket = client.storage.from(kPhotosBucket);
  await bucket.upload(
    name,
    File(localPath),
    fileOptions: FileOptions(contentType: mime, cacheControl: '2592000'),
  ).timeout(const Duration(seconds: 90));
  return bucket.getPublicUrl(name);
}

/// Supprime des photos à partir de leurs adresses web.
/// Un échec est ignoré : une photo orpheline est sans gravité.
Future<void> deletePhotosByUrl(List<String> urls) async {
  const marker = '/object/public/$kPhotosBucket/';
  final paths = <String>[];
  for (final u in urls) {
    final i = u.indexOf(marker);
    if (i >= 0) {
      paths.add(Uri.decodeComponent(u.substring(i + marker.length)));
    }
  }
  if (paths.isEmpty) return;
  try {
    await Supabase.instance.client.storage.from(kPhotosBucket).remove(paths);
  } catch (_) {}
}
