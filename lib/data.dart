import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String icon;
  final Color color;
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

const List<Category> kCategories = [
  Category(id: 'vehicules',    name: 'Véhicules',        icon: '🚗', color: Color(0xFFE63946)),
  Category(id: 'immobilier',   name: 'Immobilier',       icon: '🏠', color: Color(0xFF457B9D)),
  Category(id: 'electronique', name: 'Électronique',     icon: '📱', color: Color(0xFF7B2CBF)),
  Category(id: 'maison',       name: 'Maison & Jardin',  icon: '🛋️', color: Color(0xFF2A9D8F)),
  Category(id: 'mode',         name: 'Mode',             icon: '👕', color: Color(0xFFE91E63)),
  Category(id: 'emploi',       name: 'Emploi',           icon: '💼', color: Color(0xFFF77F00)),
  Category(id: 'services',     name: 'Services',         icon: '🔧', color: Color(0xFF00B4D8)),
  Category(id: 'loisirs',      name: 'Loisirs',          icon: '🎮', color: Color(0xFFFCA311)),
  Category(id: 'bebe',         name: 'Bébé & Enfant',    icon: '👶', color: Color(0xFFFF7EB3)),
  Category(id: 'animaux',      name: 'Animaux',          icon: '🐾', color: Color(0xFFA68A64)),
];

Category categoryById(String id) =>
    kCategories.firstWhere((c) => c.id == id, orElse: () => kCategories.first);

String formatPrice(double p) {
  final s = p.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${buf.toString()} DA';
}
