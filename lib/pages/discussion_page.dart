import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../main.dart';

enum _Filter { all, mySubjects, myPosts, bookmarked, solved }

const _teal1 = Color(0xFF004D40);
const _teal2 = Color(0xFF00695C);
const _teal3 = Color(0xFF00897B);

class DiscussionPage extends StatefulWidget {
  const DiscussionPage({super.key});
  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  final _uid = supabase.auth.currentUser?.id ?? '';

  _Filter _activeFilter = _Filter.all;
  int _sortMode = 0;
  Set<String> _bookmarkIds = {};
  List<String> _selectedCourses = [];
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetch();
    _loadBookmarks();
    _loadSelectedCourses();
    _searchCtrl.addListener(
        () => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await supabase
        .from('posts')
        .select('*, profiles:user_id(full_name)')
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        _posts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  Future<void> _loadBookmarks() async {
    final data = await supabase
        .from('post_bookmarks')
        .select('post_id')
        .eq('user_id', _uid);
    if (mounted) {
      setState(
          () => _bookmarkIds = {for (final r in data) r['post_id'] as String});
    }
  }

  Future<void> _loadSelectedCourses() async {
    final d = await supabase
        .from('profiles')
        .select('selected_courses')
        .eq('id', _uid)
        .single();
    final raw = d['selected_courses'];
    if (mounted) {
      setState(
          () => _selectedCourses = raw is List ? List<String>.from(raw) : []);
    }
  }

  Future<void> _toggleBookmark(String postId) async {
    if (_bookmarkIds.contains(postId)) {
      await supabase
          .from('post_bookmarks')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _uid);
      setState(() => _bookmarkIds.remove(postId));
    } else {
      await supabase
          .from('post_bookmarks')
          .insert({'post_id': postId, 'user_id': _uid});
      setState(() => _bookmarkIds.add(postId));
    }
  }

  bool _isMySubject(String? tag) {
    if (tag == null || tag.isEmpty || _selectedCourses.isEmpty) return false;
    return _selectedCourses.any((c) =>
        c.toLowerCase().contains(tag.toLowerCase()) ||
        tag.toLowerCase().contains(c.split(' ').first.toLowerCase()));
  }

  List<Map<String, dynamic>> get _filtered {
    return _posts.where((p) {
      final matchSearch = _search.isEmpty ||
          (p['text'] as String).toLowerCase().contains(_search) ||
          ((p['subject_tag'] as String?) ?? '').toLowerCase().contains(_search);

      final matchFilter = switch (_activeFilter) {
        _Filter.all => true,
        _Filter.mySubjects => _isMySubject(p['subject_tag'] as String?),
        _Filter.myPosts => p['user_id'] == _uid,
        _Filter.bookmarked => _bookmarkIds.contains(p['id'] as String),
        _Filter.solved => p['solved'] as bool? ?? false,
      };

      return matchSearch && matchFilter;
    }).toList()
      ..sort((a, b) {
        if (_sortMode == 1) {
          return (a['created_at'] as String)
              .compareTo(b['created_at'] as String);
        }

        return (b['created_at'] as String).compareTo(a['created_at'] as String);
      });
  }

  Future<Uint8List?> _pickImage() async {
    final xf = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    return xf != null ? await xf.readAsBytes() : null;
  }

  Future<String?> _uploadImage(Uint8List bytes, {String prefix = ''}) async {
    final path = '$_uid/$prefix${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('discussion').uploadBinary(path, bytes,
        fileOptions:
            const FileOptions(contentType: 'image/jpeg', upsert: false));
    return supabase.storage.from('discussion').getPublicUrl(path);
  }

  Future<void> _newPost() async {
    final textCtrl = TextEditingController();
    Uint8List? imgBytes;
    String? selectedTag;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
                padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 14),
                      const Text('Share a Problem',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Ask anything — your peers can help',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 12),
                      if (_selectedCourses.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: selectedTag,
                          decoration: const InputDecoration(
                              labelText: 'Subject Tag (optional)',
                              prefixIcon: Icon(Icons.label_outline)),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('No tag')),
                            ..._selectedCourses.map((c) => DropdownMenuItem(
                                value: c,
                                child:
                                    Text(c, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (v) => setS(() => selectedTag = v),
                        ),
                      if (_selectedCourses.isNotEmpty)
                        const SizedBox(height: 12),
                      TextField(
                        controller: textCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Describe your problem in detail…',
                          filled: true,
                          fillColor: const Color(0xFFF4F6FA),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (imgBytes != null) ...[
                        Stack(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(imgBytes!,
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.cover)),
                          Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => setS(() => imgBytes = null),
                                child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 14)),
                              )),
                        ]),
                        const SizedBox(height: 8),
                      ],
                      Row(children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: Text(
                              imgBytes == null ? 'Attach Image' : 'Change',
                              style: const TextStyle(fontSize: 13)),
                          onPressed: () async {
                            final b = await _pickImage();
                            if (b != null) setS(() => imgBytes = b);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _teal2,
                            side: const BorderSide(color: _teal2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Post',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () async {
                          if (textCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          final url = imgBytes != null
                              ? await _uploadImage(imgBytes!)
                              : null;
                          await supabase.from('posts').insert({
                            'user_id': _uid,
                            'text': textCtrl.text.trim(),
                            'image_url': url,
                            'subject_tag': selectedTag,
                            'solved': false,
                          });
                          _fetch();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal2,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ]),
              )),
    );
  }

  Future<void> _editPost(Map<String, dynamic> post) async {
    final textCtrl = TextEditingController(text: post['text'] as String);
    final existingUrl = post['image_url'] as String?;
    Uint8List? newBytes;
    bool removeImg = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
                padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 14),
                      const Text('Edit Post',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: textCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF4F6FA),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none))),
                      const SizedBox(height: 10),
                      if (newBytes != null) ...[
                        Stack(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(newBytes!,
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.cover)),
                          Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                  onTap: () => setS(() => newBytes = null),
                                  child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 14)))),
                        ]),
                        const SizedBox(height: 8),
                      ] else if (existingUrl != null &&
                          existingUrl.isNotEmpty &&
                          !removeImg) ...[
                        Stack(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                  imageUrl: existingUrl,
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.cover)),
                          Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                  onTap: () => setS(() => removeImg = true),
                                  child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 14)))),
                        ]),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton.icon(
                        icon: const Icon(Icons.image_outlined, size: 16),
                        label: Text(
                            (existingUrl != null && !removeImg) ||
                                    newBytes != null
                                ? 'Change Image'
                                : 'Add Image',
                            style: const TextStyle(fontSize: 13)),
                        onPressed: () async {
                          final b = await _pickImage();
                          if (b != null) {
                            setS(() {
                              newBytes = b;
                              removeImg = false;
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _teal2,
                            side: const BorderSide(color: _teal2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save Changes',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () async {
                          if (textCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          String? url = existingUrl;
                          if (newBytes != null) {
                            url =
                                await _uploadImage(newBytes!, prefix: 'edit_');
                          } else if (removeImg) url = null;
                          await supabase.from('posts').update({
                            'text': textCtrl.text.trim(),
                            'image_url': url,
                          }).eq('id', post['id']);
                          _fetch();
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _teal2,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                      ),
                    ]),
              )),
    );
  }

  Future<void> _deletePost(String id) async {
    await supabase.from('posts').delete().eq('id', id);
    _fetch();
  }

  Future<void> _toggleSolved(Map<String, dynamic> post) async {
    await supabase
        .from('posts')
        .update({'solved': !(post['solved'] as bool)}).eq('id', post['id']);
    _fetch();
  }

  String _timeAgo(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final solved = _posts.where((p) => p['solved'] as bool? ?? false).length;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_teal1, _teal2, _teal3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Collaboration',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(children: [
              _Chip('${_posts.length} Posts'),
              const SizedBox(width: 6),
              _Chip('$solved Solved'),
            ]),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPost,
        backgroundColor: _teal2,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('New Post',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search posts or subjects…',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear())
                    : null,
                filled: true,
                fillColor: const Color(0xFFF4F6FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip('All', _Filter.all),
                const SizedBox(width: 8),
                _filterChip('My Subjects', _Filter.mySubjects),
                const SizedBox(width: 8),
                _filterChip('My Posts', _Filter.myPosts),
                const SizedBox(width: 8),
                _filterChip('Bookmarked', _Filter.bookmarked),
                const SizedBox(width: 8),
                _filterChip('Solved ✅', _Filter.solved),
              ]),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                const Text('Sort:',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                _sortChip('Latest ↓', 0),
                const SizedBox(width: 6),
                _sortChip('Oldest ↑', 1),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _PostCard(
                          post: filtered[i],
                          currentUid: _uid,
                          timeAgo:
                              _timeAgo(filtered[i]['created_at'] as String?),
                          isBookmarked:
                              _bookmarkIds.contains(filtered[i]['id']),
                          onBookmark: () =>
                              _toggleBookmark(filtered[i]['id'] as String),
                          onEdit: () => _editPost(filtered[i]),
                          onDelete: () =>
                              _deletePost(filtered[i]['id'] as String),
                          onToggleSolved: () => _toggleSolved(filtered[i]),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, _Filter filter) {
    final active = _activeFilter == filter;
    return GestureDetector(
      onTap: () {
        if (filter == _Filter.mySubjects && _selectedCourses.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Select your courses in Profile first!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
          return;
        }
        setState(() => _activeFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _teal2 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _teal2 : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _sortChip(String label, int mode) {
    final active = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _teal2.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? _teal2 : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? _teal2 : Colors.grey.shade500)),
      ),
    );
  }

  Widget _emptyState() {
    final messages = {
      _Filter.all: ('No posts yet', 'Start the conversation!'),
      _Filter.mySubjects: (
        'No posts for your courses',
        'Posts tagged with your subjects show here'
      ),
      _Filter.myPosts: ('No posts yet', 'Tap + to share a problem'),
      _Filter.bookmarked: ('No bookmarks yet', 'Tap 🔖 on a post to save it'),
      _Filter.solved: (
        'No solved posts yet',
        'Mark a post as solved to see it here'
      ),
    };
    final (title, sub) = messages[_activeFilter]!;
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.forum_outlined, size: 52, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black38)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    ]));
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String currentUid, timeAgo;
  final bool isBookmarked;
  final VoidCallback onBookmark, onEdit, onDelete, onToggleSolved;

  const _PostCard({
    required this.post,
    required this.currentUid,
    required this.timeAgo,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSolved,
  });

  String get _name {
    final p = post['profiles'];
    return (p is Map) ? p['full_name'] as String? ?? 'Unknown' : 'Unknown';
  }

  bool get _isOwner => post['user_id'] == currentUid;
  bool get _isSolved => post['solved'] as bool? ?? false;

  Color get _avatarColor {
    final colors = [
      _teal2,
      const Color(0xFF0055BB),
      const Color(0xFF5C1799),
      const Color(0xFFBF360C),
      const Color(0xFF1565C0)
    ];
    return colors[_name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final tag = post['subject_tag'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: _isSolved
            ? Border.all(color: _teal3.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: _avatarColor.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            CircleAvatar(
                radius: 18,
                backgroundColor: _avatarColor,
                child: Text(_name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(timeAgo,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
            if (_isSolved)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _teal3, borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('Solved',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            IconButton(
              icon: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isBookmarked ? _teal2 : Colors.grey.shade400,
                size: 22,
              ),
              onPressed: onBookmark,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            if (_isOwner)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                  if (v == 'solved') onToggleSolved();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit Post')
                      ])),
                  PopupMenuItem(
                      value: 'solved',
                      child: Row(children: [
                        Icon(
                            _isSolved
                                ? Icons.undo_rounded
                                : Icons.check_circle_outline,
                            size: 18),
                        const SizedBox(width: 10),
                        Text(_isSolved ? 'Unmark Solved' : 'Mark as Solved')
                      ])),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(color: Colors.redAccent))
                      ])),
                ],
              ),
          ]),
        ),
        if (tag != null && tag.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _teal2.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _teal2.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.label_rounded, size: 12, color: _teal2),
                const SizedBox(width: 4),
                Text(tag.split(' ').take(2).join(' '),
                    style: const TextStyle(
                        fontSize: 11,
                        color: _teal2,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Text(post['text'] as String,
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: Colors.black87)),
        ),
        if (post['image_url'] != null &&
            (post['image_url'] as String).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          _FullImage(url: post['image_url'] as String))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: post['image_url'] as String,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2))),
                    errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: Icon(Icons.broken_image_outlined,
                            size: 36, color: Colors.grey.shade400)),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: TextButton.icon(
            icon: Icon(Icons.comment_rounded,
                size: 16, color: _teal2.withValues(alpha: 0.7)),
            label: Text('View Comments',
                style: TextStyle(
                    fontSize: 13, color: _teal2.withValues(alpha: 0.8))),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        _CommentsPage(postId: post['id'] as String))),
          ),
        ),
      ]),
    );
  }
}

class _CommentsPage extends StatefulWidget {
  final String postId;
  const _CommentsPage({required this.postId});
  @override
  State<_CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<_CommentsPage> {
  List<Map<String, dynamic>> _comments = [];
  final _ctrl = TextEditingController();
  final _uid = supabase.auth.currentUser?.id ?? '';
  bool _sending = false;
  Uint8List? _imgBytes;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final data = await supabase
        .from('comments')
        .select('*, profiles:user_id(full_name, student_id)')
        .eq('post_id', widget.postId)
        .order('created_at');
    if (mounted) {
      setState(() => _comments = List<Map<String, dynamic>>.from(data));
    }
  }

  Future<void> _editComment(Map<String, dynamic> c) async {
    final ctrl = TextEditingController(text: c['text'] as String);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Comment'),
        content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _teal2),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    await supabase
        .from('comments')
        .update({'text': ctrl.text.trim()}).eq('id', c['id']);
    _fetch();
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty && _imgBytes == null) return;
    setState(() => _sending = true);

    String? imageUrl;
    if (_imgBytes != null) {
      final path = '$_uid/comment_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('discussion').uploadBinary(path, _imgBytes!,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: false));
      imageUrl = supabase.storage.from('discussion').getPublicUrl(path);
    }

    await supabase.from('comments').insert({
      'post_id': widget.postId,
      'user_id': _uid,
      'text': _ctrl.text.trim(),
      'image_url': imageUrl,
    });
    _ctrl.clear();
    setState(() => _imgBytes = null);
    FocusScope.of(context).unfocus();
    await _fetch();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [_teal1, _teal2, _teal3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
        ),
        title: Text('Answers (${_comments.length})',
            style: const TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        Expanded(
            child: _comments.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text('No answers yet',
                            style: TextStyle(color: Colors.grey, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text('Be the first to help!',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      final p = c['profiles'];
                      final name = (p is Map)
                          ? p['full_name'] as String? ?? 'Unknown'
                          : 'Unknown';
                      final sid =
                          (p is Map) ? p['student_id'] as String? ?? '' : '';
                      final mine = c['user_id'] == _uid;
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, bottom: 4),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: _teal2)),
                                          if (sid.isNotEmpty)
                                            Text('ID: $sid',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade500)),
                                        ])),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: mine ? _teal2 : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft:
                                          Radius.circular(mine ? 16 : 4),
                                      bottomRight:
                                          Radius.circular(mine ? 4 : 16),
                                    ),
                                    border: mine
                                        ? null
                                        : Border.all(
                                            color: const Color(0xFFEEEEEE)),
                                  ),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if ((c['text'] as String).isNotEmpty)
                                          Text(c['text'] as String,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  height: 1.4,
                                                  color: mine
                                                      ? Colors.white
                                                      : Colors.black87)),
                                        if (c['image_url'] != null &&
                                            (c['image_url'] as String)
                                                .isNotEmpty) ...[
                                          if ((c['text'] as String).isNotEmpty)
                                            const SizedBox(height: 6),
                                          GestureDetector(
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) => _FullImage(
                                                        url: c['image_url']
                                                            as String))),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: CachedNetworkImage(
                                                imageUrl:
                                                    c['image_url'] as String,
                                                width: 200,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => Container(
                                                    height: 80,
                                                    color: mine
                                                        ? Colors.white24
                                                        : Colors.grey.shade200,
                                                    child: const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2))),
                                                errorWidget: (_, __, ___) => Icon(
                                                    Icons.broken_image_outlined,
                                                    color:
                                                        Colors.grey.shade400),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ])),
                              if (mine)
                                Padding(
                                    padding:
                                        const EdgeInsets.only(top: 4, right: 4),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _editComment(c),
                                            child: const Text('Edit',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: _teal2)),
                                          ),
                                          const Text('  ·  ',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey)),
                                          GestureDetector(
                                            onTap: () async {
                                              await supabase
                                                  .from('comments')
                                                  .delete()
                                                  .eq('id', c['id']);
                                              _fetch();
                                            },
                                            child: const Text('Delete',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.redAccent)),
                                          ),
                                        ])),
                            ],
                          ),
                        ),
                      );
                    },
                  )),
        Container(
          color: Colors.white,
          padding: EdgeInsets.only(
              left: 16,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_imgBytes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Stack(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_imgBytes!,
                          height: 80,
                          width: double.infinity,
                          fit: BoxFit.cover)),
                  Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _imgBytes = null),
                        child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14)),
                      )),
                ]),
              ),
            Row(children: [
              GestureDetector(
                onTap: () async {
                  final xf = await ImagePicker()
                      .pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (xf != null) {
                    final bytes = await xf.readAsBytes();
                    setState(() => _imgBytes = bytes);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color:
                          _imgBytes != null ? _teal2 : const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(20)),
                  child: Icon(Icons.image_outlined,
                      size: 20,
                      color: _imgBytes != null ? Colors.white : Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Write an answer…',
                        filled: true,
                        fillColor: const Color(0xFFF4F6FA),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending ? null : _send,
                child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: _sending ? Colors.grey : _teal2,
                        shape: BoxShape.circle),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _FullImage extends StatelessWidget {
  final String url;
  const _FullImage({required this.url});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
            child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        const CircularProgressIndicator(color: Colors.white),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                        color: Colors.white, size: 64)))),
      );
}
