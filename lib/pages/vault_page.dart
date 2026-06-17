import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});
  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<String> _selectedCourses = [];
  Set<String> _importantIds = {};
  int _filterMode = 0;
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && _tabs.index == 2) _fetchLeaderboard();
    });
    _loadCourses();
    _loadImportantMarks();
    _fetchResources();
    _searchCtrl.addListener(
        () => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImportantMarks() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final d = await supabase
        .from('important_marks')
        .select('resource_id')
        .eq('user_id', uid);
    if (mounted) {
      setState(() =>
          _importantIds = {for (final r in d) r['resource_id'] as String});
    }
  }

  Future<void> _loadCourses() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final d = await supabase
        .from('profiles')
        .select('selected_courses')
        .eq('id', uid)
        .single();
    final raw = d['selected_courses'];
    if (mounted) {
      setState(
          () => _selectedCourses = raw is List ? List<String>.from(raw) : []);
    }
  }

  Future<void> _fetchResources() async {
    setState(() => _loading = true);
    final d = await supabase
        .from('resources')
        .select(
            '*, profiles:uploader_id(full_name, student_id), resource_reviews(rating), helpful_votes(count)')
        .order('uploaded_at', ascending: false);
    if (mounted) {
      setState(() {
        _resources = List<Map<String, dynamic>>.from(d);
        _loading = false;
      });
    }
  }

  Future<void> _fetchLeaderboard() async {
    final d = await supabase.from('leaderboard').select().limit(20);
    if (mounted) {
      setState(() => _leaderboard = List<Map<String, dynamic>>.from(d));
    }
  }

  bool _isMyCourse(String subject) {
    if (_selectedCourses.isEmpty) return false;
    final s = subject.toLowerCase();
    return _selectedCourses.any((c) {
      final code = c.split(' ').first.toLowerCase();
      return s == c.toLowerCase() ||
          c.toLowerCase().contains(s) ||
          s.contains(code);
    });
  }

  double _avgRating(Map<String, dynamic> r) {
    final rv = (r['resource_reviews'] as List?) ?? [];
    if (rv.isEmpty) return 0.0;
    return rv
            .map((x) => (x['rating'] as num).toDouble())
            .reduce((a, b) => a + b) /
        rv.length;
  }

  int _helpfulCount(Map<String, dynamic> r) {
    final h = r['helpful_votes'];
    return (h is List && h.isNotEmpty) ? (h[0]['count'] as int? ?? 0) : 0;
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _resources.where((r) {
      final matchSearch = _search.isEmpty ||
          (r['subject'] as String).toLowerCase().contains(_search);
      if (_filterMode == 1) {
        return matchSearch &&
            (_selectedCourses.isEmpty || _isMyCourse(r['subject'] as String));
      }
      if (_filterMode == 2) {
        return matchSearch &&
            (_selectedCourses.isEmpty || _isMyCourse(r['subject'] as String)) &&
            _importantIds.contains(r['id'] as String);
      }
      if (_filterMode == 3) {
        return matchSearch && _importantIds.contains(r['id'] as String);
      }
      return matchSearch;
    }).toList();

    if (_search.isNotEmpty) {
      list.sort((a, b) => _helpfulCount(b).compareTo(_helpfulCount(a)));
    } else if (_filterMode == 2) {
      list.sort((a, b) => _avgRating(b).compareTo(_avgRating(a)));
    } else if (_filterMode == 0 && _selectedCourses.isNotEmpty) {
      list.sort((a, b) => (_isMyCourse(a['subject'] as String) ? 0 : 1)
          .compareTo(_isMyCourse(b['subject'] as String) ? 0 : 1));
    }
    return list;
  }

  Future<void> _upload() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final descCtrl = TextEditingController();
    String? selYear, selSubject;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final courses =
            selYear != null ? kCoursesByYear[selYear!]! : <String>[];
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.82,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(children: [
                const Icon(Icons.upload_file_rounded, color: kPrimary),
                const SizedBox(width: 10),
                const Text('Upload Study Material',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                    children: kCoursesByYear.keys
                        .map((y) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setS(() {
                                  selYear = y;
                                  selSubject = null;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selYear == y
                                        ? kPrimary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: selYear == y
                                            ? kPrimary
                                            : Colors.grey.shade300),
                                  ),
                                  child: Text(y,
                                      style: TextStyle(
                                          color: selYear == y
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ),
                            ))
                        .toList()),
              ),
            ),
            if (selSubject != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: kSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded,
                        color: kSecondary, size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                        child: Text(selSubject!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: kSecondary,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
            Expanded(
              child: selYear == null
                  ? const Center(
                      child: Text('Select a year first',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: courses.length,
                      itemBuilder: (_, i) => RadioListTile<String>(
                            value: courses[i],
                            groupValue: selSubject,
                            activeColor: kPrimary,
                            dense: true,
                            title: Text(courses[i],
                                style: const TextStyle(fontSize: 13)),
                            onChanged: (v) => setS(() => selSubject = v),
                          )),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: Icon(Icons.notes_outlined))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text(selSubject == null
                    ? 'Pick a course first'
                    : 'Select PDF & Upload'),
                onPressed:
                    selSubject == null ? null : () => Navigator.pop(ctx, true),
              ),
            ),
          ]),
        );
      }),
    );

    if (ok != true || selSubject == null) return;
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.first.bytes == null) return;
    final file = result.files.first;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    _snack('Uploading…');
    try {
      await supabase.storage.from('vault').uploadBinary(path, file.bytes!,
          fileOptions:
              const FileOptions(contentType: 'application/pdf', upsert: false));
      final p = await supabase
          .from('profiles')
          .select('department')
          .eq('id', uid)
          .single();
      await supabase.from('resources').insert({
        'uploader_id': uid,
        'subject': selSubject,
        'description': descCtrl.text.trim(),
        'file_name': file.name,
        'file_path': path,
        'department': p['department'] as String? ?? '',
      });
      await supabase
          .rpc('increment_points', params: {'uid': uid, 'amount': 10});
      _snack('Uploaded! +10 Points 🎉');
      _fetchResources();
    } catch (e) {
      _snack('Upload failed: $e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    await supabase.storage.from('vault').remove([r['file_path'] as String]);
    await supabase.from('resources').delete().eq('id', r['id']);
    _fetchResources();
  }

  Future<void> _openPdf(String path) async {
    final url = supabase.storage.from('vault').getPublicUrl(path);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: error ? Colors.redAccent : kSecondary));

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
              colors: [Color(0xFF002D72), Color(0xFF0055BB), Color(0xFF0077DD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Resource Vault',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: kSecondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Browse'),
            Tab(text: 'My Uploads'),
            Tab(text: 'Top'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        backgroundColor: const Color(0xFF0055BB),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Upload PDF',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildBrowse(), _buildMyUploads(), _buildLeaderboard()],
      ),
    );
  }

  Widget _buildBrowse() {
    final uid = supabase.auth.currentUser?.id ?? '';
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by subject…',
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
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('All', 0, kPrimary),
              const SizedBox(width: 8),
              _filterChip('My Courses', 1, kPrimary),
              const SizedBox(width: 8),
              _filterChip('Exam Mode', 2, const Color(0xFFD84315)),
              const SizedBox(width: 8),
              _filterChip('Bookmarked 🔖', 3, const Color(0xFFE65100)),
            ]),
          ),
          if (_filterMode != 0 || _search.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _search.isNotEmpty
                    ? '🔍 Sorted by helpful count — most helpful first'
                    : _filterMode == 3
                        ? '🔖 Your bookmarked notes'
                        : _filterMode == 2
                            ? '⭐ Showing your important-marked notes from selected courses'
                            : 'Showing materials for your selected courses',
                style: TextStyle(
                    fontSize: 11,
                    color: _filterMode == 2 || _filterMode == 3
                        ? const Color(0xFFD84315)
                        : kPrimary),
              ),
            ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? _empty(_filterMode > 0
                    ? 'No materials for your courses yet'
                    : 'No resources found')
                : RefreshIndicator(
                    onRefresh: _fetchResources,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _ResourceCard(
                        res: _filtered[i],
                        currentUid: uid,
                        isMyCourse:
                            _isMyCourse(_filtered[i]['subject'] as String),
                        showRating: _filterMode == 2,
                        avgRating: _avgRating(_filtered[i]),
                        isImportant: _importantIds
                            .contains(_filtered[i]['id'] as String),
                        onToggleImportant: () async {
                          final rid = _filtered[i]['id'] as String;
                          if (_importantIds.contains(rid)) {
                            await supabase
                                .from('important_marks')
                                .delete()
                                .eq('resource_id', rid)
                                .eq('user_id', uid);
                            setState(() => _importantIds.remove(rid));
                          } else {
                            await supabase
                                .from('important_marks')
                                .insert({'resource_id': rid, 'user_id': uid});
                            setState(() => _importantIds.add(rid));
                          }
                        },
                        onOpen: () =>
                            _openPdf(_filtered[i]['file_path'] as String),
                        onDelete: () => _delete(_filtered[i]),
                        onRefresh: _fetchResources,
                      ),
                    ),
                  ),
      ),
    ]);
  }

  Widget _filterChip(String label, int index, Color color) {
    final active = _filterMode == index;
    return GestureDetector(
      onTap: () {
        if (index > 0 && _selectedCourses.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select your courses in Profile first!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
          return;
        }
        setState(() => _filterMode = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildMyUploads() {
    final uid = supabase.auth.currentUser?.id ?? '';
    final mine = _resources.where((r) => r['uploader_id'] == uid).toList();
    if (mine.isEmpty) return _empty('No uploads yet');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: mine.length,
      itemBuilder: (_, i) => _ResourceCard(
        res: mine[i],
        currentUid: uid,
        isMyCourse: false,
        showRating: false,
        avgRating: 0,
        isImportant: _importantIds.contains(mine[i]['id'] as String),
        onToggleImportant: () async {
          final rid = mine[i]['id'] as String;
          if (_importantIds.contains(rid)) {
            await supabase
                .from('important_marks')
                .delete()
                .eq('resource_id', rid)
                .eq('user_id', uid);
            setState(() => _importantIds.remove(rid));
          } else {
            await supabase
                .from('important_marks')
                .insert({'resource_id': rid, 'user_id': uid});
            setState(() => _importantIds.add(rid));
          }
        },
        onOpen: () => _openPdf(mine[i]['file_path'] as String),
        onDelete: () => _delete(mine[i]),
        onRefresh: _fetchResources,
      ),
    );
  }

  Widget _buildLeaderboard() {
    if (_leaderboard.isEmpty) {
      return Center(
          child: ElevatedButton.icon(
              onPressed: _fetchLeaderboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Load Leaderboard')));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _leaderboard.length,
      itemBuilder: (_, i) {
        final e = _leaderboard[i];
        final isTop = i < 3;
        final medals = ['🥇', '🥈', '🥉'];
        final rankColors = [
          const Color(0xFFFFD700),
          const Color(0xFFB0BEC5),
          const Color(0xFFBCAAA4)
        ];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isTop
                    ? rankColors[i].withValues(alpha: 0.5)
                    : const Color(0xFFEEEEEE)),
          ),
          child: Row(children: [
            SizedBox(
              width: 36,
              child: Text(
                isTop ? medals[i] : '${i + 1}',
                style: TextStyle(
                    fontSize: isTop ? 22 : 14,
                    fontWeight: FontWeight.bold,
                    color: isTop ? rankColors[i] : Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(e['full_name'] as String? ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(e['department'] as String? ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if ((e['student_id'] as String? ?? '').isNotEmpty)
                    Text('ID: ${e['student_id']}',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                const Icon(Icons.upload_file_rounded,
                    size: 13, color: kPrimary),
                const SizedBox(width: 3),
                Text('${e['upload_count']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kPrimary,
                        fontSize: 13)),
              ]),
              Row(children: [
                const Icon(Icons.stars_rounded, size: 12, color: kSecondary),
                const SizedBox(width: 3),
                Text('${e['points']} pts',
                    style: const TextStyle(fontSize: 11, color: kSecondary)),
              ]),
            ]),
          ]),
        );
      },
    );
  }

  Widget _empty(String msg) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off_rounded, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38)),
        ]),
      );
}

class _ResourceCard extends StatefulWidget {
  final Map<String, dynamic> res;
  final String currentUid;
  final bool isMyCourse, showRating;
  final bool isImportant;
  final double avgRating;
  final VoidCallback onOpen, onDelete, onRefresh;
  final VoidCallback onToggleImportant;

  const _ResourceCard({
    required this.res,
    required this.currentUid,
    required this.isMyCourse,
    required this.showRating,
    required this.isImportant,
    required this.avgRating,
    required this.onOpen,
    required this.onDelete,
    required this.onRefresh,
    required this.onToggleImportant,
  });

  @override
  State<_ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<_ResourceCard> {
  int _helpfulCount = 0;
  bool _hasVoted = false;
  bool _voteLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHelpful();
  }

  Future<void> _loadHelpful() async {
    final votes = await supabase
        .from('helpful_votes')
        .select('user_id')
        .eq('resource_id', widget.res['id'] as String);
    if (mounted) {
      setState(() {
        _helpfulCount = votes.length;
        _hasVoted = votes.any((v) => v['user_id'] == widget.currentUid);
      });
    }
  }

  Future<void> _toggleHelpful() async {
    if (_voteLoading || widget.res['uploader_id'] == widget.currentUid) return;
    setState(() => _voteLoading = true);
    try {
      final rid = widget.res['id'] as String;
      final uploId = widget.res['uploader_id'] as String;
      if (_hasVoted) {
        await supabase
            .from('helpful_votes')
            .delete()
            .eq('resource_id', rid)
            .eq('user_id', widget.currentUid);
        await supabase
            .rpc('increment_points', params: {'uid': uploId, 'amount': -2});
        setState(() {
          _hasVoted = false;
          _helpfulCount--;
        });
      } else {
        await supabase
            .from('helpful_votes')
            .insert({'resource_id': rid, 'user_id': widget.currentUid});
        await supabase
            .rpc('increment_points', params: {'uid': uploId, 'amount': 2});
        setState(() {
          _hasVoted = true;
          _helpfulCount++;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _voteLoading = false);
  }

  String get _uploaderName {
    final p = widget.res['profiles'];
    return (p is Map) ? p['full_name'] as String? ?? 'Unknown' : 'Unknown';
  }

  String get _uploaderSid {
    final p = widget.res['profiles'];
    return (p is Map) ? p['student_id'] as String? ?? '' : '';
  }

  bool get _isOwner => widget.res['uploader_id'] == widget.currentUid;

  Color _subjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math') || s.contains('calc'))
      return const Color(0xFF5C35CC);
    if (s.contains('data') || s.contains('db')) return const Color(0xFF0055BB);
    if (s.contains('algo') || s.contains('oop')) return const Color(0xFF007A6E);
    if (s.contains('network') || s.contains('os'))
      return const Color(0xFFBF360C);
    return const Color(0xFF5C1799);
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.res;
    final color = _subjectColor(res['subject'] as String? ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.picture_as_pdf_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(res['file_name'] as String? ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(20)),
                    child: Text(res['subject'] as String? ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ])),
            if (_isOwner)
              IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                  onPressed: widget.onDelete),
            GestureDetector(
              onTap: widget.onToggleImportant,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  widget.isImportant
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: widget.isImportant
                      ? const Color(0xFFE65100)
                      : Colors.grey.shade400,
                  size: 22,
                ),
              ),
            ),
            if (widget.isMyCourse)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bookmark_rounded, color: kPrimary, size: 11),
                    SizedBox(width: 3),
                    Text('Your Course',
                        style: TextStyle(
                            fontSize: 10,
                            color: kPrimary,
                            fontWeight: FontWeight.w600)),
                  ])),
            if (widget.showRating)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFD84315).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFD84315), size: 11),
                    const SizedBox(width: 3),
                    Text(
                        widget.avgRating > 0
                            ? widget.avgRating.toStringAsFixed(1)
                            : 'Unrated',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFD84315),
                            fontWeight: FontWeight.w600)),
                  ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((res['description'] as String?)?.isNotEmpty == true) ...[
              Text(res['description'] as String,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black45, height: 1.4)),
              const SizedBox(height: 8),
            ],
            Row(children: [
              CircleAvatar(
                  radius: 10,
                  backgroundColor: kPrimary.withValues(alpha: 0.12),
                  child: Text(_uploaderName[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 9,
                          color: kPrimary,
                          fontWeight: FontWeight.bold))),
              const SizedBox(width: 6),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_uploaderName,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (_uploaderSid.isNotEmpty)
                      Text('ID: $_uploaderSid',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                  ])),
              Text('· ${res['department']}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _isOwner ? null : _toggleHelpful,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOwner
                      ? Colors.transparent
                      : (_hasVoted ? kSecondary : Colors.transparent),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _isOwner
                          ? Colors.grey.shade200
                          : (_hasVoted ? kSecondary : Colors.grey.shade300)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _voteLoading
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _hasVoted ? Colors.white : kSecondary))
                      : Icon(Icons.thumb_up_rounded,
                          size: 13,
                          color: _isOwner
                              ? Colors.grey.shade300
                              : (_hasVoted
                                  ? Colors.white
                                  : Colors.grey.shade500)),
                  const SizedBox(width: 5),
                  Text('Helpful  $_helpfulCount',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _isOwner
                              ? Colors.grey.shade300
                              : (_hasVoted
                                  ? Colors.white
                                  : Colors.grey.shade500))),
                  if (_isOwner)
                    Text('  (your upload)',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade300)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open PDF', style: TextStyle(fontSize: 12)),
                onPressed: widget.onOpen,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary,
                  side: BorderSide(color: kPrimary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton.icon(
                icon: const Icon(Icons.star_border_rounded, size: 14),
                label: const Text('Reviews', style: TextStyle(fontSize: 12)),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _ReviewSheet(
                      resourceId: res['id'] as String,
                      currentUid: widget.currentUid),
                ).then((_) => widget.onRefresh()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  final String resourceId, currentUid;
  const _ReviewSheet({required this.resourceId, required this.currentUid});
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  List<Map<String, dynamic>> _reviews = [];
  double _myRating = 3;
  final _textCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await supabase
        .from('resource_reviews')
        .select('*, profiles:user_id(full_name)')
        .eq('resource_id', widget.resourceId)
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(d);
        _submitted = _reviews.any((r) => r['user_id'] == widget.currentUid);
      });
    }
  }

  Future<void> _submit() async {
    await supabase.from('resource_reviews').upsert({
      'resource_id': widget.resourceId,
      'user_id': widget.currentUid,
      'rating': _myRating.toInt(),
      'review_text': _textCtrl.text.trim(),
    });
    _load();
    setState(() => _submitted = true);
  }

  double get _avg => _reviews.isEmpty
      ? 0
      : _reviews
              .map((r) => (r['rating'] as int).toDouble())
              .reduce((a, b) => a + b) /
          _reviews.length;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Text('Reviews',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_reviews.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(_avg.toStringAsFixed(1),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(' (${_reviews.length})',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
              ])),
          const Divider(height: 20),
          if (!_submitted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                RatingBar.builder(
                  initialRating: _myRating,
                  minRating: 1,
                  itemCount: 5,
                  itemSize: 34,
                  itemBuilder: (_, __) =>
                      const Icon(Icons.star_rounded, color: Colors.amber),
                  onRatingUpdate: (r) => setState(() => _myRating = r),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _textCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Write a short review…',
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44)),
                  child: const Text('Submit Review'),
                ),
                const Divider(height: 24),
              ]),
            ),
          Expanded(
            child: _reviews.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(Icons.rate_review_outlined,
                            size: 44, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text('No reviews yet',
                            style: TextStyle(color: Colors.grey)),
                      ]))
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _reviews.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final rv = _reviews[i];
                      final name = (rv['profiles'] is Map)
                          ? rv['profiles']['full_name'] as String? ?? 'Unknown'
                          : 'Unknown';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      kPrimary.withValues(alpha: 0.1),
                                  child: Text(name[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: kPrimary,
                                          fontWeight: FontWeight.bold))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Row(children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      const Spacer(),
                                      Row(
                                          children: List.generate(
                                              5,
                                              (si) => Icon(
                                                    si < (rv['rating'] as int)
                                                        ? Icons.star_rounded
                                                        : Icons
                                                            .star_outline_rounded,
                                                    size: 13,
                                                    color: Colors.amber,
                                                  ))),
                                    ]),
                                    if (rv['review_text'] != null &&
                                        rv['review_text'] != '') ...[
                                      const SizedBox(height: 4),
                                      Text(rv['review_text'] as String,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black45,
                                              height: 1.4)),
                                    ],
                                  ])),
                            ]),
                      );
                    }),
          ),
        ]),
      ),
    );
  }
}
