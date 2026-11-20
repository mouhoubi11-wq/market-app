import 'dart:io';
import 'package:flutter/material.dart';
import '../data.dart';
import '../models.dart';
import '../repository.dart';
import 'detail_screen.dart';
import 'post_ad_screen.dart';

enum SortMode { recent, priceAsc, priceDesc }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = AnnouncementRepository();
  final _searchCtrl = TextEditingController();
  List<Announcement> _all = [];
  Set<String> _favorites = {};
  bool _loading = true;
  int _tab = 0;
  String? _categoryId;
  String? _type;
  SortMode _sort = SortMode.recent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ads = await _repo.loadAll();
    final favs = await _repo.loadFavorites();
    if (!mounted) return;
    setState(() {
      _all = ads;
      _favorites = favs;
      _loading = false;
    });
  }

  bool get _hasActiveFilters =>
      _searchCtrl.text.isNotEmpty || _categoryId != null || _type != null;

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _categoryId = null;
      _type = null;
    });
    FocusScope.of(context).unfocus();
  }

  List<Announcement> get _homeList {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _all.where((a) {
      final matchSearch = q.isEmpty ||
          a.title.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q) ||
          a.city.toLowerCase().contains(q);
      final matchCat = _categoryId == null || a.categoryId == _categoryId;
      final matchType = _type == null || a.type == _type;
      return matchSearch && matchCat && matchType;
    }).toList();
    switch (_sort) {
      case SortMode.priceAsc: list.sort((a, b) => a.price.compareTo(b.price)); break;
      case SortMode.priceDesc: list.sort((a, b) => b.price.compareTo(a.price)); break;
      case SortMode.recent: list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); break;
    }
    return list;
  }

  List<Announcement> get _favList => _all.where((a) => _favorites.contains(a.id)).toList();
  List<Announcement> get _mineList => _all.where((a) => a.isMine).toList();

  Future<void> _toggleFav(String id) async {
    final wasFav = _favorites.contains(id);
    await _repo.toggleFavorite(id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(wasFav ? 'Retire des favoris' : 'Ajoute aux favoris'),
        duration: const Duration(milliseconds: 1200),
      ));
    }
  }

  Future<void> _openPost() async {
    final created = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const PostAdScreen()));
    if (created == true) {
      await _load();
      if (mounted) {
        setState(() => _tab = 2);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Annonce publiee avec succes !'),
          backgroundColor: Color(0xFF2A9D8F),
        ));
      }
    }
  }

  Future<void> _openDetail(Announcement a) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => DetailScreen(announcement: a)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _load,
              child: _buildBody(),
            ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _openPost,
              backgroundColor: const Color(0xFFFF3D71),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Publier',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Favoris'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Mes annonces'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_tab != 0) {
      return AppBar(title: Text(_tab == 1 ? 'Mes favoris' : 'Mes annonces'));
    }

    return AppBar(
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text('ðŸ›’', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          const Text('Marche', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        PopupMenuButton<SortMode>(
          tooltip: 'Trier',
          icon: const Icon(Icons.sort),
          initialValue: _sort,
          color: Colors.white,
          onSelected: (s) => setState(() => _sort = s),
          itemBuilder: (_) => const [
            PopupMenuItem(value: SortMode.recent, child: Text('Plus recentes')),
            PopupMenuItem(value: SortMode.priceAsc, child: Text('Prix croissant')),
            PopupMenuItem(value: SortMode.priceDesc, child: Text('Prix decroissant')),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(118),
        child: Container(
          color: const Color(0xFFFF6B35),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchCtrl,
                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un article, une ville...',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _searchCtrl.clear()),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                   _categoryChip(id: null, icon: '🌈', label: 'Tout', color: Colors.white),
                    ...kCategories.map((c) => _categoryChip(id: c.id, icon: c.icon, label: c.name, color: c.color)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip({required String? id, required String icon, required String label, required Color color}) {
    final selected = _categoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: color,
        label: Text('$icon $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : Colors.black87,
            )),
        onSelected: (sel) => setState(() => _categoryId = sel ? id : null),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('Tout')),
                        ButtonSegment(value: 'vente', label: Text('Vente')),
                        ButtonSegment(value: 'achat', label: Text('Achat')),
                      ],
                      selected: {_type ?? 'all'},
                      onSelectionChanged: (s) => setState(() => _type = s.first == 'all' ? null : s.first),
                    ),
                  ),
                  if (_hasActiveFilters)
                    IconButton(
                      tooltip: 'Effacer',
                      icon: const Icon(Icons.filter_alt_off),
                      onPressed: _clearFilters,
                    ),
                ],
              ),
            ),
            Expanded(
              child: _buildList(_homeList,
                  emptyIcon: Icons.search_off,
                  emptyMsg: 'Aucune annonce trouvee',
                  emptyAction: _hasActiveFilters
                      ? TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reinitialiser les filtres'))
                      : null),
            ),
          ],
        );
      case 1:
        return _buildList(_favList,
            emptyIcon: Icons.favorite_border,
            emptyMsg: 'Aucun favori',
            emptyAction: FilledButton.icon(
                onPressed: () => setState(() => _tab = 0),
                icon: const Icon(Icons.explore),
                label: const Text('Decouvrir des annonces')));
      default:
        return _buildList(_mineList,
            emptyIcon: Icons.inbox_outlined,
            emptyMsg: 'Vous n avez publie aucune annonce',
            emptyAction: FilledButton.icon(
                onPressed: _openPost,
                icon: const Icon(Icons.add),
                label: const Text('Publier ma premiere annonce')));
    }
  }

  Widget _buildList(List<Announcement> list,
      {required IconData emptyIcon, required String emptyMsg, Widget? emptyAction}) {
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, size: 72, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(emptyMsg, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                if (emptyAction != null) ...[const SizedBox(height: 16), emptyAction],
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 100),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final a = list[i];
        final cat = categoryById(a.categoryId);
        final isFav = _favorites.contains(a.id);
        return _buildCard(a, cat, isFav);
      },
    );
  }

  Widget _buildCard(Announcement a, Category cat, bool isFav) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(a),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: cat.color, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: a.photoPaths.isNotEmpty
                    ? Image.file(File(a.photoPaths.first),
                        width: 68, height: 68, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbFallback(cat))
                    : _thumbFallback(cat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(a.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _toggleFav(a.id),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? const Color(0xFFFF3D71) : Colors.grey, size: 22),
                          ),
                        ),
                      ],
                    ),
                    Text(formatPrice(a.price),
                        style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: a.type == 'vente' ? const Color(0xFF2A9D8F) : const Color(0xFF457B9D),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(a.type == 'vente' ? 'Vente' : 'Achat',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_outlined, size: 14, color: cat.color),
                        Flexible(
                          child: Text(a.city,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                        ),
                        const Spacer(),
                        Text(a.timeAgo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback(Category cat) {
    return Container(
      width: 68, height: 68,
      decoration: BoxDecoration(
        color: cat.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(cat.icon, style: const TextStyle(fontSize: 34)),
    );
  }
}
