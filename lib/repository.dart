import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AnnouncementRepository {
  static const _adsKey = 'announcements_v1';
  static const _favKey = 'favorites_v1';

  Future<List<Announcement>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_adsKey);
    if (raw == null) {
      final seeded = _seed();
      await saveAll(seeded);
      return seeded;
    }
    return (jsonDecode(raw) as List)
        .map((e) => Announcement.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveAll(List<Announcement> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _adsKey, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  Future<void> add(Announcement a) async {
    final list = await loadAll();
    list.insert(0, a);
    await saveAll(list);
  }

  Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((a) => a.id == id);
    await saveAll(list);
  }

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favKey) ?? []).toSet();
  }

  Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = (prefs.getStringList(_favKey) ?? []).toSet();
    favs.contains(id) ? favs.remove(id) : favs.add(id);
    await prefs.setStringList(_favKey, favs.toList());
  }

  List<Announcement> _seed() {
    final now = DateTime.now();
    return [
      Announcement(id: 's1', title: 'iPhone 13 Pro 128 Go', description: 'Tres bon etat, facture disponible, boite complete.', price: 65000, categoryId: 'electronique', city: 'Alger', contactPhone: '0555 00 00 01', type: 'vente', createdAt: now.subtract(const Duration(hours: 2))),
      Announcement(id: 's2', title: 'Toyota Yaris 2019 essence', description: '78 000 km, entretien a jour, papiers en regle.', price: 1800000, categoryId: 'vehicules', city: 'Oran', contactPhone: '0555 00 00 02', type: 'vente', createdAt: now.subtract(const Duration(hours: 5))),
      Announcement(id: 's3', title: 'Cherche appartement F3 a louer', description: 'Budget 40 000 DA/mois, centre-ville de preference.', price: 40000, categoryId: 'immobilier', city: 'Constantine', contactPhone: '0555 00 00 03', type: 'achat', createdAt: now.subtract(const Duration(days: 1))),
      Announcement(id: 's4', title: 'Canape d angle 5 places', description: 'Tissu gris, tres confortable, cause demenagement.', price: 45000, categoryId: 'maison', city: 'Alger', contactPhone: '0555 00 00 04', type: 'vente', createdAt: now.subtract(const Duration(days: 2))),
      Announcement(id: 's5', title: 'Cours de soutien maths', description: 'Niveau lycee, a domicile ou en ligne.', price: 2500, categoryId: 'services', city: 'Blida', contactPhone: '0555 00 00 05', type: 'vente', createdAt: now.subtract(const Duration(days: 3))),
    ];
  }
}
