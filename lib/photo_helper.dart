import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> savePermanentPhoto(String tempPath) async {
  final dir = await getApplicationDocumentsDirectory();
  final photosDir = Directory('${dir.path}/photos');
  if (!await photosDir.exists()) {
    await photosDir.create(recursive: true);
  }
  final filename =
      '${DateTime.now().microsecondsSinceEpoch}_${tempPath.split('/').last}';
  final dest = File('${photosDir.path}/$filename');
  await File(tempPath).copy(dest.path);
  return dest.path;
}

Future<void> deletePhoto(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

Future<void> deletePhotos(List<String> paths) async {
  for (final p in paths) {
    await deletePhoto(p);
  }
}
