import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../repository.dart';
import 'detail_screen.dart';
import 'post_ad_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = AnnouncementRepository();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  // Onglet Accueil (chargé page par page depuis le serveur)
  List<Announcement> _ads = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _moreFailed = false;
  String? _error;
  int _reqId = 0;

  // Onglets Favoris et Mes annonces
  List<Announcement> _favAds = [];
  List<Announcement> _mineAds = [];
  bool _favLoading = false;
  bool _mineLoading = false;
  String? _favError;
  String? _mineError;

  Set<String> _favorites = {};
  Set<String> _blocked = {};
  int _tab = 0;
  String? _categoryId;
  String? _type;
  SortMode _sort = SortMode.recent;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _favorites = await _repo.loadFavorites();
    _blocked = await _repo.loadBlocked();
    if (!mounted) return;
    await _reload();
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ------------------------------------------------------------------
  //  Chargement de l'accueil
  // ------------------------------------------------------------------
  Future<void> _reload({bool keepOnError = false}) async {
    final id = ++_reqId;
    if (!keepOnError && _scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    setState(() {
      _loading = true;
      _loadingMore = false;
      _moreFailed = false;
      _error = null;
    });
    try {
      final p = await _repo.fetchPage(
        page: 0,
        search: _searchCtrl.text,
        categoryId: _categoryId,
        type: _type,
        sort: _sort,
        blocked: _blocked,
      );
      if (!mounted || id != _reqId) return;
      setState(() {
        _ads = p.items;
        _page = 0;
        _hasMore = p.hasMore;
        _loading = false;
      });
      _scheduleFillCheck();
    } catch (e) {
      if (!mounted || id != _reqId) return;
      final msg = friendlyError(e);
      setState(() {
        if (!keepOnError) {
          _ads = [];
          _hasMore = false;
        }
        _error = msg;
        _loading = false;
      });
      if (keepOnError) _snack(msg);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final id = _reqId;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final p = await _repo.fetchPage(
        page: _page + 1,
        search: _searchCtrl.text,
        categoryId: _categoryId,
        type: _type,
        sort: _sort,
        blocked: _blocked,
      );
      if (!mounted || id != _reqId) return;
      final seen = _ads.map((a) => a.id).toSet();
      setState(() {
        _ads = [..._ads, ...p.items.where((a) => !seen.contains(a.id))];
        _page += 1;
        _hasMore = p.hasMore;
        _loadingMore = false;
      });
      _scheduleFillCheck();
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) _loadMore();
  }

  /// Si la liste est trop courte pour défiler (annonces masquées par un blocage),
  /// on charge la page suivante sans attendre un défilement.
  void _scheduleFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tab != 0 || !_scrollCtrl.hasClients) return;
      if (_hasMore && _scrollCtrl.position.maxScrollExtent <= 0) _loadMore();
    });
  }

  Future<void> _loadFavs() async {
    setState(() {
      _favLoading = true;
      _favError = null;
    });
    try {
      final favs = await _repo.loadFavorites();
      final list = await _repo.fetchByIds(favs);
      if (!mounted) return;
      setState(() {
        _favorites = favs;
        _favAds = list;
        _favLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _favLoading = false;
        _favError = friendlyError(e);
      });
    }
  }

  Future<void> _loadMine() async {
    setState(() {
      _mineLoading = true;
      _mineError = null;
    });
    try {
      final list = await _repo.fetchMine();
      if (!mounted) return;
      setState(() {
        _mineAds = list;
        _mineLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mineLoading = false;
        _mineError = friendlyError(e);
      });
    }
  }

  Future<void> _refreshCurrentTab() {
    switch (_tab) {
      case 0:
        return _reload(keepOnError: true);
      case 1:
        return _loadFavs();
      default:
        return _loadMine();
    }
  }

  void _selectTab(int i) {
    setState(() => _tab = i);
    if (i == 1) _loadFavs();
    if (i == 2) _loadMine();
  }

  // ------------------------------------------------------------------
  //  Filtres
  // ------------------------------------------------------------------
  bool get _hasActiveFilters =>
      _searchCtrl.text.isNotEmpty || _categoryId != null || _type != null;

  void _clearFilters() {
    _debounce?.cancel();
    setState(() {
      _searchCtrl.clear();
      _categoryId = null;
      _type = null;
    });
    FocusScope.of(context).unfocus();
    _reload();
  }

  void _onSearchChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _reload);
  }

  List<Announcement> get _favList => _favAds
      .where((a) => _favorites.contains(a.id) && !_blocked.contains(a.ownerId))
      .toList();

  // ------------------------------------------------------------------
  //  Actions
  // ------------------------------------------------------------------
  Future<void> _toggleFav(String id) async {
    final wasFav = _favorites.contains(id);
    await _repo.toggleFavorite(id);
    final favs = await _repo.loadFavorites();
    if (!mounted) return;
    setState(() => _favorites = favs);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(wasFav ? '💔 Retiré des favoris' : '❤️ Ajouté aux favoris'),
      duration: const Duration(milliseconds: 1200),
    ));
  }

  Future<void> _openPost() async {
    final created = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const PostAdScreen()));
    if (created == true && mounted) {
      setState(() => _tab = 2);
      _loadMine();
      _reload(keepOnError: true);
      _snack('✅ Annonce publiée avec succès !', color: const Color(0xFF2A9D8F));
    }
  }

  Future<void> _openDetail(Announcement a) async {
    final res = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => DetailScreen(announcement: a)));
    if (!mounted) return;
    final favs = await _repo.loadFavorites();
    if (!mounted) return;
    if (res == 'deleted') {
      setState(() {
        _favorites = favs;
        _ads = _ads.where((x) => x.id != a.id).toList();
        _favAds = _favAds.where((x) => x.id != a.id).toList();
        _mineAds = _mineAds.where((x) => x.id != a.id).toList();
      });
      _snack('Annonce supprimée.');
    } else if (res == 'blocked') {
      final blocked = await _repo.loadBlocked();
      if (!mounted) return;
      setState(() {
        _favorites = favs;
        _blocked = blocked;
        _ads = _ads.where((x) => !blocked.contains(x.ownerId)).toList();
      });
      _snack('Utilisateur bloqué.', color: Colors.red);
    } else {
      setState(() => _favorites = favs);
    }
  }

  // ------------------------------------------------------------------
  //  Interface
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _refreshCurrentTab,
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
        onDestinationSelected: _selectTab,
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
      return AppBar(title: Text(_tab == 1 ? '❤️ Mes favoris' : '📋 Mes annonces'));
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
            child: const Text('🛒', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          const Text('Marché', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        PopupMenuButton<SortMode>(
          tooltip: 'Trier',
          icon: const Icon(Icons.sort),
          initialValue: _sort,
          color: Colors.white,
          onSelected: (s) {
            setState(() => _sort = s);
            _reload();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: SortMode.recent, child: Text('📅 Plus récentes')),
            PopupMenuItem(value: SortMode.priceAsc, child: Text('💰 Prix croissant')),
            PopupMenuItem(value: SortMode.priceDesc, child: Text('💎 Prix décroissant')),
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
                    onChanged: (_) => _onSearchChanged(),
                    onSubmitted: (_) {
                      _debounce?.cancel();
                      _reload();
                    },
                    decoration: InputDecoration(
                      hintText: 'Rechercher un article, une ville...',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _debounce?.cancel();
                                setState(() => _searchCtrl.clear());
                                _reload();
                              },
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
        onSelected: (sel) {
          setState(() => _categoryId = sel ? id : null);
          _reload();
        },
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
                        ButtonSegment(value: 'vente', label: Text('🟢 Vente')),
                        ButtonSegment(value: 'achat', label: Text('🔵 Achat')),
                      ],
                      selected: {_type ?? 'all'},
                      onSelectionChanged: (s) {
                        setState(() => _type = s.first == 'all' ? null : s.first);
                        _reload();
                      },
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
            Expanded(child: _homeContent()),
          ],
        );
      case 1:
        if (_favLoading && _favAds.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_favError != null && _favAds.isEmpty) {
          return _errorView(_favError!, _loadFavs);
        }
        return _buildList(_favList,
            emptyIcon: Icons.favorite_border,
            emptyMsg: 'Aucun favori',
            emptyAction: FilledButton.icon(
                onPressed: () => _selectTab(0),
                icon: const Icon(Icons.explore),
                label: const Text('Découvrir des annonces')));
      default:
        if (_mineLoading && _mineAds.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_mineError != null && _mineAds.isEmpty) {
          return _errorView(_mineError!, _loadMine);
        }
        return _buildList(_mineAds,
            emptyIcon: Icons.inbox_outlined,
            emptyMsg: 'Vous n\'avez publié aucune annonce',
            emptyAction: FilledButton.icon(
                onPressed: _openPost,
                icon: const Icon(Icons.add),
                label: const Text('Publier ma première annonce')));
    }
  }

  Widget _homeContent() {
    if (_loading && _ads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _ads.isEmpty) {
      return _errorView(_error!, _reload);
    }
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _buildList(_ads,
              paged: true,
              emptyIcon: Icons.search_off,
              emptyMsg: 'Aucune annonce trouvée',
              emptyAction: _hasActiveFilters
                  ? TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réinitialiser les filtres'))
                  : null),
        ),
      ],
    );
  }

  Widget _errorView(String msg, VoidCallback retry) {
    return _centered(
      Icons.wifi_off,
      msg,
      FilledButton.icon(
        onPressed: retry,
        icon: const Icon(Icons.refresh),
        label: const Text('Réessayer'),
      ),
    );
  }

  Widget _centered(IconData icon, String msg, Widget? action) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ),
              if (action != null) ...[const SizedBox(height: 16), action],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Announcement> list,
      {required IconData emptyIcon,
      required String emptyMsg,
      Widget? emptyAction,
      bool paged = false}) {
    if (list.isEmpty) {
      return _centered(emptyIcon, emptyMsg, emptyAction);
    }

    final extra = (paged && _hasMore) ? 1 : 0;
    return ListView.builder(
      controller: paged ? _scrollCtrl : null,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 100),
      itemCount: list.length + extra,
      itemBuilder: (_, i) {
        if (i >= list.length) return _footer();
        final a = list[i];
        final cat = categoryById(a.categoryId);
        final isFav = _favorites.contains(a.id);
        return _buildCard(a, cat, isFav);
      },
    );
  }

  Widget _footer() {
    if (_moreFailed) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.refresh),
          label: const Text('Connexion perdue — Réessayer'),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                child: a.photoUrls.isNotEmpty
                    ? Image.network(
                        a.photoUrls.first,
                        width: 68, height: 68, fit: BoxFit.cover,
                        cacheWidth: 204,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _thumbFallback(cat),
                        errorBuilder: (_, __, ___) => _thumbFallback(cat),
                      )
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
