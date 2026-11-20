import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../data.dart';
import '../models.dart';
import '../photo_helper.dart';
import '../repository.dart';

class DetailScreen extends StatefulWidget {
  final Announcement announcement;
  const DetailScreen({super.key, required this.announcement});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _repo = AnnouncementRepository();
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _repo.loadFavorites().then((f) {
      if (mounted) setState(() => _isFav = f.contains(widget.announcement.id));
    });
  }

  Future<void> _toggleFav() async {
    await _repo.toggleFavorite(widget.announcement.id);
    final favs = await _repo.loadFavorites();
    if (!mounted) return;
    setState(() => _isFav = favs.contains(widget.announcement.id));
  }

  Future<void> _call() async {
    final phone = widget.announcement.contactPhone.replaceAll(' ', '');
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception();
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Numero copie : $phone')));
    }
  }

  // 📤 PARTAGER L'ANNONCE
  void _share() {
    final a = widget.announcement;
    final text = 'Regarde cette annonce sur Marché 🛒\n\n'
        '📌 ${a.title}\n'
        '💰 ${formatPrice(a.price)}\n'
        '📍 ${a.city}\n\n'
        '📝 ${a.description}\n\n'
        'Télécharge l\'application pour voir plus d\'annonces !';
    
    Share.share(text, subject: a.title);
  }

  // 🚩 SIGNALER L'ANNONCE
  void _report() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Signaler cette annonce'),
        content: const Text('Pourquoi signalez-vous cette annonce ?\n\n(Le signalement sera envoyé aux modérateurs)'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Merci, votre signalement a été pris en compte.'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Arnaque / Fraude'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Merci, votre signalement a été pris en compte.'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Contenu inapproprié'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // 🚫 BLOQUER L'UTILISATEUR
  void _block() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bloquer cet utilisateur ?'),
        content: const Text('Vous ne verrez plus ses annonces à l\'avenir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Retour à l'accueil
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Utilisateur bloqué.'), backgroundColor: Colors.red),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: const Text('Cette action est irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await deletePhotos(widget.announcement.photoPaths);
      await _repo.delete(widget.announcement.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final cat = categoryById(a.categoryId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.share),
            onPressed: _share,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _report();
              if (value == 'block') _block();
              if (value == 'delete') _delete();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag, color: Colors.orange), SizedBox(width: 8), Text('Signaler')])),
              if (!a.isMine) const PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text('Bloquer l\'utilisateur')])),
              if (a.isMine) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Supprimer')])),
            ],
          ),
          IconButton(
            icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
                color: _isFav ? const Color(0xFFFF3D71) : Colors.white),
            onPressed: _toggleFav,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (a.photoPaths.isNotEmpty)
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: a.photoPaths.length,
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(File(a.photoPaths[i]), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cat.color.withOpacity(0.3),
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image, size: 48, color: Colors.white),
                      )),
                ),
              ),
            )
          else
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cat.color.withOpacity(0.3), cat.color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(cat.icon, style: const TextStyle(fontSize: 100)),
            ),
          const SizedBox(height: 18),
          Text(a.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(formatPrice(a.price),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
          const SizedBox(height: 4),
          Text('Publié ${a.timeAgo}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _pill('${cat.icon} ${cat.name}', cat.color),
              _pill(a.type == 'vente' ? 'Vente' : 'Achat',
                  a.type == 'vente' ? const Color(0xFF2A9D8F) : const Color(0xFF457B9D)),
              _pill('${a.city}', const Color(0xFFF77F00)),
            ],
          ),
          const Divider(height: 36),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 8),
          Text(a.description, style: const TextStyle(height: 1.6, fontSize: 15)),
          const Divider(height: 36),
          const Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF26D0CE), Color(0xFF2A9D8F)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone, color: Colors.white),
              ),
              title: Text(a.contactPhone, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Appuyez pour appeler'),
              trailing: const Icon(Icons.call, color: Color(0xFF26D0CE)),
              onTap: _call,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.share),
            label: const Text('Partager cette annonce'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 16),
          if (!a.isMine)
            FilledButton.icon(
              onPressed: _call,
              icon: const Icon(Icons.call),
              label: const Text('Contacter le vendeur'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                minimumSize: const Size.fromHeight(54),
              ),
            ),
        ],
      ),
    );
  }
}
