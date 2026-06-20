import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});
  @override
  State<RequestPage> createState() => _RequestPageState();
}

enum _ReqFilter { all, mine, fulfilled }

class _RequestPageState extends State<RequestPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  final _uid = supabase.auth.currentUser?.id ?? '';

  _ReqFilter _activeFilter = _ReqFilter.all;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(
        () => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Filter + search
  List<Map<String, dynamic>> get _filtered {
    return _requests.where((r) {
      final matchSearch = _search.isEmpty ||
          (r['subject'] as String).toLowerCase().contains(_search) ||
          ((r['description'] as String?) ?? '').toLowerCase().contains(_search);
      final matchFilter = switch (_activeFilter) {
        _ReqFilter.all => true,
        _ReqFilter.mine => r['user_id'] == _uid,
        _ReqFilter.fulfilled => r['fulfilled'] as bool? ?? false,
      };
      return matchSearch && matchFilter;
    }).toList();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await supabase
        .from('requests')
        .select(
            '*, profiles:user_id(full_name, avatar_url, student_id), request_fulfillments(count)')
        .order('created_at', ascending: false);
    if (mounted)
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
  }

  Future<void> _showRequestSheet({Map<String, dynamic>? existing}) async {
    String? selectedYear;
    String? selectedSubject = existing?['subject'] as String?;
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final courses =
            selectedYear != null ? kCoursesByYear[selectedYear!]! : <String>[];
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
                            borderRadius: BorderRadius.circular(2))))),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          existing == null
                              ? 'Post a Resource Request'
                              : 'Edit Request',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Ask peers to share notes or PDFs you need',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ])),
            // Year chips
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      children: kCoursesByYear.keys
                          .map((y) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setS(() {
                                    selectedYear = y;
                                    selectedSubject = null;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                        color: selectedYear == y
                                            ? const Color(0xFF6A1B9A)
                                            : const Color(0xFF6A1B9A)
                                                .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text(y,
                                        style: TextStyle(
                                            color: selectedYear == y
                                                ? Colors.white
                                                : const Color(0xFF6A1B9A),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                  ),
                                ),
                              ))
                          .toList()),
                )),
            // Selected subject badge
            if (selectedSubject != null)
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: kSecondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_rounded,
                            color: kSecondary, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(selectedSubject!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: kSecondary,
                                    fontWeight: FontWeight.w600))),
                      ]))),
            // Course list
            Expanded(
                child: selectedYear == null
                    ? Center(
                        child: Text(
                            selectedSubject != null
                                ? '✅ Course selected. Change year to pick another.'
                                : '👆 Select a year to see courses',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: courses.length,
                        itemBuilder: (_, i) => RadioListTile<String>(
                              value: courses[i],
                              groupValue: selectedSubject,
                              activeColor: const Color(0xFF6A1B9A),
                              dense: true,
                              title: Text(courses[i],
                                  style: const TextStyle(fontSize: 13)),
                              onChanged: (v) => setS(() => selectedSubject = v),
                            ))),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'What exactly do you need? (optional)',
                        prefixIcon: Icon(Icons.notes_outlined)))),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: ElevatedButton.icon(
                  icon: Icon(
                      existing == null
                          ? Icons.send_rounded
                          : Icons.save_rounded,
                      size: 18),
                  label: Text(
                      selectedSubject == null
                          ? 'Select a course above'
                          : existing == null
                              ? 'Post Request'
                              : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: selectedSubject == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          if (existing == null) {
                            await _postRequest(
                                selectedSubject!, descCtrl.text.trim());
                          } else {
                            await supabase.from('requests').update({
                              'subject': selectedSubject,
                              'description': descCtrl.text.trim(),
                            }).eq('id', existing['id']);
                            _fetch();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFF6A1B9A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                )),
          ]),
        );
      }),
    );
  }

  Future<void> _postRequest(String subject, String desc) async {
    final p = await supabase
        .from('profiles')
        .select('full_name, department')
        .eq('id', _uid)
        .single();
    await supabase.from('requests').insert({
      'user_id': _uid,
      'user_name': p['full_name'],
      'subject': subject,
      'description': desc,
      'department': p['department'],
      'fulfilled': false,
    });
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

  Widget _reqChip(String label, _ReqFilter filter) {
    final active = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6A1B9A) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? const Color(0xFF6A1B9A) : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 130,
          pinned: true,
          backgroundColor: const Color(0xFF6A1B9A),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)),
              child: SafeArea(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      const Text('Resource Requests',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          '${_requests.length} requests · Ask peers for study materials',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
              )),
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by subject or description…',
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
                    _reqChip('All Requests', _ReqFilter.all),
                    const SizedBox(width: 8),
                    _reqChip('My Requests', _ReqFilter.mine),
                    const SizedBox(width: 8),
                    _reqChip('Fulfilled ✅', _ReqFilter.fulfilled),
                  ]),
                ),
              ]),
            ),
          ),
        if (!_loading && _filtered.isEmpty)
          SliverFillRemaining(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                        shape: BoxShape.circle),
                    child: Icon(Icons.request_page_outlined,
                        size: 56,
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.4))),
                const SizedBox(height: 16),
                Text(
                    _activeFilter == _ReqFilter.mine
                        ? 'No requests posted by you'
                        : _activeFilter == _ReqFilter.fulfilled
                            ? 'No fulfilled requests yet'
                            : 'No requests found',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black45)),
                const SizedBox(height: 6),
                const Text('Post what you need — peers will help!',
                    style: TextStyle(color: Colors.grey)),
              ])))
        else if (!_loading)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
            sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
              (_, i) => _RequestCard(
                request: _filtered[i],
                currentUid: _uid,
                timeAgo: _timeAgo(_filtered[i]['created_at'] as String?),
                onEdit: () => _showRequestSheet(existing: _filtered[i]),
                onDelete: () async {
                  await supabase
                      .from('requests')
                      .delete()
                      .eq('id', _filtered[i]['id']);
                  _fetch();
                },
                onToggleFulfill: () async {
                  final cur = _filtered[i]['fulfilled'] as bool? ?? false;
                  await supabase
                      .from('requests')
                      .update({'fulfilled': !cur}).eq('id', _filtered[i]['id']);
                  _fetch();
                },
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _RequestDetailPage(
                            request: _filtered[i],
                            currentUid: _uid))).then((_) => _fetch()),
              ),
              childCount: _filtered.length,
            )),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Request',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A),
      ),
    );
  }
}

// Request Card
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String currentUid, timeAgo;
  final VoidCallback onEdit, onDelete, onToggleFulfill, onTap;

  const _RequestCard(
      {required this.request,
      required this.currentUid,
      required this.timeAgo,
      required this.onEdit,
      required this.onDelete,
      required this.onToggleFulfill,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final isOwner = r['user_id'] == currentUid;
    final isFulfilled = r['fulfilled'] as bool? ?? false;
    final p = r['profiles'];
    final name =
        (p is Map) ? p['full_name'] as String? ?? 'Unknown' : 'Unknown';
    final avatar = (p is Map) ? p['avatar_url'] as String? : null;
    final sid = (p is Map) ? p['student_id'] as String? ?? '' : '';
    final fl = r['request_fulfillments'];
    final count =
        (fl is List && fl.isNotEmpty) ? fl[0]['count'] as int? ?? 0 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isFulfilled
            ? Border.all(color: kSecondary.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF6A1B9A),
                backgroundImage: (avatar != null && avatar.isNotEmpty)
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: (avatar == null || avatar.isEmpty)
                    ? Text(name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))
                    : null),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  if (sid.isNotEmpty)
                    Text('ID: $sid',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                  Text(timeAgo,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
            if (isFulfilled)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: kSecondary,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Fulfilled',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ])),
            if (isOwner)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                  if (v == 'fulfill') onToggleFulfill();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit')
                      ])),
                  PopupMenuItem(
                      value: 'fulfill',
                      child: Row(children: [
                        Icon(
                            isFulfilled
                                ? Icons.undo_rounded
                                : Icons.check_circle_outline,
                            size: 18),
                        const SizedBox(width: 10),
                        Text(
                            isFulfilled ? 'Unmark Fulfilled' : 'Mark Fulfilled')
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
        // Body
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(r['subject'] as String,
                        style: const TextStyle(
                            color: Color(0xFF6A1B9A),
                            fontWeight: FontWeight.bold,
                            fontSize: 12))),
                const SizedBox(width: 8),
                Text(r['department'] as String? ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              if ((r['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(r['description'] as String,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54, height: 1.4)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.upload_file_rounded,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('$count response${count == 1 ? '' : 's'}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('View / Respond',
                      style: TextStyle(fontSize: 12)),
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6A1B9A)),
                ),
              ]),
            ])),
      ]),
    );
  }
}

// Request Detail Page
class _RequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;
  final String currentUid;
  const _RequestDetailPage({required this.request, required this.currentUid});
  @override
  State<_RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<_RequestDetailPage> {
  List<Map<String, dynamic>> _fulfillments = [];
  bool _loading = true, _uploading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await supabase
        .from('request_fulfillments')
        .select('*, profiles:user_id(full_name, avatar_url, student_id)')
        .eq('request_id', widget.request['id'] as String)
        .order('created_at', ascending: false);
    if (mounted)
      setState(() {
        _fulfillments = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.first.bytes == null) return;
    final file = result.files.first;
    setState(() => _uploading = true);
    try {
      final uid = widget.currentUid;
      final path =
          'requests/$uid/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await supabase.storage.from('vault').uploadBinary(path, file.bytes!,
          fileOptions:
              const FileOptions(contentType: 'application/pdf', upsert: false));
      final p = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', uid)
          .single();
      await supabase.from('request_fulfillments').insert({
        'request_id': widget.request['id'],
        'user_id': uid,
        'user_name': p['full_name'],
        'file_name': file.name,
        'file_path': path,
      });
      await supabase
          .rpc('increment_points', params: {'uid': uid, 'amount': 15});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Uploaded! +15 Points earned 🎉'),
            backgroundColor: kSecondary));
        _fetch();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteFulfillment(Map<String, dynamic> f) async {
    await supabase.storage.from('vault').remove([f['file_path'] as String]);
    await supabase.from('request_fulfillments').delete().eq('id', f['id']);
    await supabase.rpc('increment_points',
        params: {'uid': widget.currentUid, 'amount': -15});
    _fetch();
  }

  Future<void> _openPdf(String path) async {
    final url = supabase.storage.from('vault').getPublicUrl(path);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A1B9A),
        title: Text(req['subject'] as String? ?? 'Request',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _uploading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)))
              : TextButton.icon(
                  icon: const Icon(Icons.upload_file,
                      color: Colors.white, size: 18),
                  label: const Text('Upload PDF',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  onPressed: _upload),
        ],
      ),
      body: Column(children: [
        // Request info
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(req['subject'] as String? ?? '',
                      style: const TextStyle(
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13))),
              const SizedBox(width: 8),
              Text(req['department'] as String? ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            if ((req['description'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(req['description'] as String,
                  style: const TextStyle(
                      fontSize: 14, height: 1.5, color: Colors.black87)),
            ],
            const SizedBox(height: 6),
            Text('Posted by ${req['user_name']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            const Icon(Icons.upload_file_rounded,
                color: Color(0xFF6A1B9A), size: 16),
            const SizedBox(width: 6),
            Text(
                '${_fulfillments.length} Response${_fulfillments.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A1B9A),
                    fontSize: 14)),
          ]),
        ),
        // Fulfillments list
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _fulfillments.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Icon(Icons.upload_file_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            const Text('No responses yet',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text('Be the first to help — upload a PDF!',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _fulfillments.length,
                        itemBuilder: (_, i) {
                          final f = _fulfillments[i];
                          final fp = f['profiles'];
                          final isMine = f['user_id'] == widget.currentUid;
                          final name = (fp is Map)
                              ? fp['full_name'] as String? ?? 'Unknown'
                              : 'Unknown';
                          final favatar =
                              (fp is Map) ? fp['avatar_url'] as String? : null;
                          final fsid = (fp is Map)
                              ? fp['student_id'] as String? ?? ''
                              : '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: isMine
                                  ? Border.all(
                                      color: kPrimary.withValues(alpha: 0.4))
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8)
                              ],
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.picture_as_pdf_rounded,
                                  color: Colors.redAccent, size: 28),
                              title: Text(f['file_name'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Row(children: [
                                CircleAvatar(
                                    radius: 11,
                                    backgroundColor: const Color(0xFF6A1B9A),
                                    backgroundImage: (favatar != null &&
                                            favatar.isNotEmpty)
                                        ? CachedNetworkImageProvider(favatar)
                                        : null,
                                    child: (favatar == null || favatar.isEmpty)
                                        ? Text(name[0].toUpperCase(),
                                            style: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold))
                                        : null),
                                const SizedBox(width: 5),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Text(name,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                        if (isMine) ...[
                                          const SizedBox(width: 5),
                                          Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                  color: kPrimary.withValues(
                                                      alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(5)),
                                              child: const Text('You',
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color: kPrimary,
                                                      fontWeight:
                                                          FontWeight.bold))),
                                        ],
                                      ]),
                                      if (fsid.isNotEmpty)
                                        Text('ID: $fsid',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade400)),
                                    ])),
                              ]),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(
                                            Icons.open_in_new_rounded,
                                            color: kPrimary,
                                            size: 20),
                                        tooltip: 'Open PDF',
                                        onPressed: () =>
                                            _openPdf(f['file_path'] as String)),
                                    if (isMine)
                                      IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 20),
                                          tooltip: 'Delete my upload',
                                          onPressed: () =>
                                              _deleteFulfillment(f)),
                                  ]),
                            ),
                          );
                        },
                      )),
      ]),
    );
  }
}
