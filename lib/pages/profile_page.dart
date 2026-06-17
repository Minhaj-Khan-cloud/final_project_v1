import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ProfilePage({super.key, required this.profile});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Map<String, dynamic> _profile;
  bool _uploading = false;
  List<String> _selectedCourses = [];

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
    final raw = _profile['selected_courses'];
    if (raw is List) {
      _selectedCourses = List<String>.from(raw);
    }
  }

  Future<void> _changeAvatar() async {
    final xf = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (xf == null) return;
    final bytes = await xf.readAsBytes();
    setState(() => _uploading = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      await supabase.from('profiles').update({'avatar_url': url}).eq('id', uid);
      setState(() => _profile['avatar_url'] = url);
      _snack('Profile photo updated!');
    } catch (e) {
      _snack('Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Photo'),
        content:
            const Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _uploading = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase
          .from('profiles')
          .update({'avatar_url': null}).eq('id', uid);
      setState(() => _profile['avatar_url'] = null);
      _snack('Profile photo removed.');
    } catch (e) {
      _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveCourses(List<String> courses) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('profiles')
        .update({'selected_courses': courses}).eq('id', uid);
    setState(() => _selectedCourses = courses);
    _snack('Courses saved!');
  }

  Future<void> _showCourseSelector() async {
    List<String> temp = List<String>.from(_selectedCourses);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DefaultTabController(
          length: 4,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Expanded(
                      child: Text('Select Your Courses',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold))),
                  Text('${temp.length} selected',
                      style: const TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 10),
              TabBar(
                isScrollable: false,
                labelColor: kPrimary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: kPrimary,
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Year 1'),
                  Tab(text: 'Year 2'),
                  Tab(text: 'Year 3'),
                  Tab(text: 'Year 4')
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: kCoursesByYear.entries
                      .map(
                        (entry) => ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: entry.value.length,
                          itemBuilder: (_, i) {
                            final course = entry.value[i];
                            final selected = temp.contains(course);
                            return CheckboxListTile(
                              value: selected,
                              activeColor: kPrimary,
                              title: Text(course,
                                  style: const TextStyle(fontSize: 13)),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              onChanged: (_) => setS(() {
                                selected
                                    ? temp.remove(course)
                                    : temp.add(course);
                              }),
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _saveCourses(temp);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Save ${temp.length} Courses'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : kSecondary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile['full_name'] as String? ?? '—';
    final email = _profile['email'] as String? ?? '—';
    final dept = _profile['department'] as String? ?? '—';
    final sid = _profile['student_id'] as String? ?? '—';
    final points = _profile['points'] as int? ?? 0;
    final avatar = _profile['avatar_url'] as String?;
    final created = _profile['created_at'] as String?;
    final dobRaw = _profile['date_of_birth'] as String?;

    String? dob;
    if (dobRaw != null && dobRaw.isNotEmpty) {
      final dt = DateTime.tryParse(dobRaw);
      if (dt != null) dob = '${dt.day}/${dt.month}/${dt.year}';
    }

    String? joinedOn;
    if (created != null) {
      final dt = DateTime.tryParse(created);
      if (dt != null) joinedOn = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: kPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0044AA), Color(0xFF0066CC)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Stack(alignment: Alignment.center, children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white24,
                            backgroundImage:
                                (avatar != null && avatar.isNotEmpty)
                                    ? CachedNetworkImageProvider(avatar)
                                    : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.white)
                                : null,
                          ),
                        ),
                        if (_uploading)
                          const CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.black45,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          ),
                      ]),
                      const SizedBox(height: 10),
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text(dept,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _uploading ? null : _changeAvatar,
                              icon: const Icon(Icons.camera_alt_outlined,
                                  size: 15, color: Colors.white),
                              label: const Text('Change Photo',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                            if (avatar != null && avatar.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: _uploading ? null : _removeAvatar,
                                icon: const Icon(Icons.delete_outline,
                                    size: 15, color: Colors.redAccent),
                                label: const Text('Remove',
                                    style: TextStyle(
                                        color: Colors.redAccent, fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  side:
                                      const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                          ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF00CC99), Color(0xFF00AAAA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: kSecondary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.stars_rounded,
                        color: Color(0xFFFFD700), size: 32),
                    const SizedBox(width: 14),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Points Balance',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text('$points Points',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ]),
                    const Spacer(),
                    const Text('🏆', style: TextStyle(fontSize: 28)),
                  ]),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Personal Information',
                  icon: Icons.person_outline,
                  children: [
                    _InfoRow(Icons.badge_outlined, 'Full Name', name),
                    _InfoRow(Icons.email_outlined, 'Email', email),
                    if (dob != null)
                      _InfoRow(Icons.cake_outlined, 'Date of Birth', dob),
                    _InfoRow(Icons.school_outlined, 'Department', dept),
                    _InfoRow(Icons.numbers_rounded, 'Student ID', sid),
                    if (joinedOn != null)
                      _InfoRow(
                          Icons.calendar_today_outlined, 'Joined', joinedOn),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Account Stats',
                  icon: Icons.bar_chart_rounded,
                  children: [
                    _InfoRow(Icons.stars_rounded, 'Total Points', '$points pts',
                        valueColor: kSecondary),
                    _InfoRow(
                        Icons.verified_outlined, 'Account Status', 'Active',
                        valueColor: Colors.green),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'My Courses',
                  icon: Icons.menu_book_rounded,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedCourses.isEmpty)
                            const Text('No courses selected yet.',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 13))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _selectedCourses.map((c) {
                                final code = c.split(' ').first;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kPrimary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: kPrimary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(code,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: kPrimary,
                                          fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _showCourseSelector,
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: Text(_selectedCourses.isEmpty
                                ? 'Select Courses'
                                : 'Edit Courses (${_selectedCourses.length})'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimary,
                              side: BorderSide(
                                  color: kPrimary.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text('Sign Out',
                      style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    await supabase.auth.signOut();
                  },
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Icon(icon, color: kPrimary, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: kPrimary)),
          ]),
        ),
        const Divider(height: 1),
        ...children,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _InfoRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: valueColor ?? Colors.black87))),
      ]),
    );
  }
}
