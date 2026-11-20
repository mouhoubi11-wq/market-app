import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../data.dart';
import '../models.dart';
import '../photo_helper.dart';
import '../repository.dart';

class PostAdScreen extends StatefulWidget {
  const PostAdScreen({super.key});
  @override
  State<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends State<PostAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = AnnouncementRepository();
  final _picker = ImagePicker();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final List<String> _tempPhotoPaths = [];
  String _categoryId = kCategories.first.id;
  String _type = 'vente';
  bool _saving = false;
  bool _acceptTerms = false;
  static const _maxPhotos = 5;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _tempPhotoPaths.length;
    if (remaining <= 0) { _showSnack('Maximum $_maxPhotos photos'); return; }
    try {
      final files = await _picker.pickMultiImage(imageQuality: 75, maxWidth: 1600);
      if (files.isEmpty) return;
      setState(() => _tempPhotoPaths.addAll(files.take(remaining).map((f) => f.path)));
    } catch (e) {
      _showSnack('Erreur photos : $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_tempPhotoPaths.length >= _maxPhotos) { _showSnack('Maximum $_maxPhotos'); return; }
    try {
      final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1600);
      if (file == null) return;
      setState(() => _tempPhotoPaths.add(file.path));
    } catch (e) {
      _showSnack('Erreur camera : $e');
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () { Navigator.pop(context); _pickPhotos(); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () { Navigator.pop(context); _takePhoto(); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final permanentPaths = <String>[];
    for (final p in _tempPhotoPaths) {
      try { permanentPaths.add(await savePermanentPhoto(p)); } catch (_) {}
    }
    final ad = Announcement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text) ?? 0,
      categoryId: _categoryId,
      city: _cityCtrl.text.trim(),
      contactPhone: _phoneCtrl.text.trim(),
      type: _type,
      isMine: true,
      createdAt: DateTime.now(),
      photoPaths: permanentPaths,
    );
    await _repo.add(ad);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle annonce'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D71)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Bonne vente !\nRemplissez les champs pour publier.',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
                  ),
                ],
              ),
            ),
            _buildPhotoPicker(),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'vente', label: Text('Je vends'), icon: Icon(Icons.sell_outlined)),
                ButtonSegment(value: 'achat', label: Text('Je recherche'), icon: Icon(Icons.search)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Titre *', hintText: 'Ex: iPhone 13 Pro 128 Go', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 5) ? 'Titre trop court (5 caract. min)' : null,
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Categorie *', border: OutlineInputBorder()),
              items: kCategories.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon}  ${c.name}'))).toList(),
              onChanged: (v) => setState(() => _categoryId = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Prix *', hintText: 'Ex: 65000', border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined), suffixText: 'DA',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Prix requis';
                final p = double.tryParse(v);
                if (p == null || p <= 0) return 'Prix invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ville *', hintText: 'Ex: Alger', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ville requise' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
              decoration: const InputDecoration(labelText: 'Telephone *', hintText: 'Ex: 0555 00 00 00', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length < 6 ? 'Numero invalide' : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 6,
              minLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description *', hintText: 'Decrivez votre article...', border: OutlineInputBorder(), alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Description trop courte (10 caract. min)' : null,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acceptTerms,
              onChanged: (val) => setState(() => _acceptTerms = val ?? false),
              title: const Text(
                "J'accepte les conditions d'utilisation et je certifie que mon annonce est légale.",
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFFFF6B35),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: (_saving || !_acceptTerms) ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Publication...' : 'Publier l annonce'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('* Champs obligatoires', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Photos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 8),
            Text('(${_tempPhotoPaths.length}/$_maxPhotos) - optionnel',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (_tempPhotoPaths.length < _maxPhotos)
                GestureDetector(
                  onTap: _showSourceSheet,
                  child: Container(
                    width: 92, height: 92,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade600, size: 28),
                        const SizedBox(height: 4),
                        Text('Ajouter', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ..._tempPhotoPaths.asMap().entries.map((entry) {
                final idx = entry.key;
                final path = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 92, height: 92,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 2, right: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => _tempPhotoPaths.removeAt(idx)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
