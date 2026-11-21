import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../models.dart';
import '../repository.dart';

/// Résultat renvoyé à l'écran précédent via Navigator.pop :
///  'deleted' = annonce supprimée, 'blocked' = vendeur bloqué, null = rien de spécial.
class DetailScreen extends StatefulWidget {
  final Announcement announcement;
  const DetailScreen({super.key, required this.announcement});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _repo = AnnouncementRepository();
  bool _isFav = false;
  bool _busy = false;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _repo.loadFavorites().then((f) {
      if (mounted) setState(() => _isFav = f.contains(widget.announcement.id));
    });
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
      _snack('Numéro copié : $phone');
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

  // 🚩 SIGNALER L'ANNONCE (enregistré sur le serveur, table "reports")
  void _report() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signaler cette annonce'),
        content: const Text('Pourquoi signalez-vous cette annonce ?\n\n(Le signalement sera envoyé aux modérateurs)'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendReport('arnaque');
            },
            child: const Text('Arnaque / Fraude'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendReport('inapproprie');
            },
            child: const Text('Contenu inapproprié'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReport(String reason) async {
    try {
      await _repo.report(widget.announcement.id, reason);
      _snack('✅ Merci, votre signalement a été pris en compte.',
          color: Colors.green);
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  // 🚫 BLOQUER L'UTILISATEUR (liste gardée sur ce téléphone)
  void _block() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquer cet utilisateur ?'),
        content: const Text('Vous ne verrez plus ses annonces sur ce téléphone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _repo.blockOwner(widget.announcement.ownerId);
              if (!mounted) return;
              Navigator.pop(context, 'blocked');
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
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.delete(widget.announcement);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(friendlyError(e));
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

  Widget _photoPlaceholder(Color color) {
    return Container(
      color: color.withOpacity(0.3),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image, size: 48, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final cat = categoryById(a.categoryId);
    final mine = a.isMine;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails'),
        actions: [
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.share),
            onPressed: _share,
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (value) {
              if (value == 'report') _report();
              if (value == 'block') _block();
              if (value == 'delete') _delete();
            },
            itemBuilder: (BuildContext context) => [
              if (!mine) const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag, color: Colors.orange), SizedBox(width: 8), Text('Signaler')])),
              if (!mine) const PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text('Bloquer l\'utilisateur')])),
              if (mine) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Supprimer')])),
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
          if (_busy) const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
          if (a.photoUrls.isNotEmpty)
            SizedBox(
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      itemCount: a.photoUrls.length,
                      onPageChanged: (i) => setState(() => _photoIndex = i),
                      itemBuilder: (_, i) => Image.network(
                        a.photoUrls[i],
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                color: cat.color.withOpacity(0.15),
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              ),
                        errorBuilder: (_, __, ___) => _photoPlaceholder(cat.color),
                      ),
                    ),
                    if (a.photoUrls.length > 1)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${_photoIndex + 1}/${a.photoUrls.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
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
              _pill(a.city, const Color(0xFFF77F00)),
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
          if (!mine)
            FilledButton.icon(
              onPressed: _call,
              icon: const Icon(Icons.call),
              label: Text(a.type == 'vente' ? 'Contacter le vendeur' : 'Contacter l\'annonceur'),
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
