import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'vault_page.dart';
import 'discussion_page.dart';
import 'planner_page.dart';
import 'profile_page.dart';
import 'request_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _avatarUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPlannerAlerts();
  }

  Future<void> _loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final data =
        await supabase.from('profiles').select().eq('id', uid).single();
    if (mounted) {
      setState(() {
        _profile = data;
        _loading = false;
      });
    }
  }

  Future<void> _changeAvatar() async {
    final xf = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (xf == null) return;
    final bytes = await xf.readAsBytes();
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _avatarUploading = true);
    try {
      final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('avatars').uploadBinary(path, bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true));
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      await supabase.from('profiles').update({'avatar_url': url}).eq('id', uid);
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: kSecondary,
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page))
          .then((_) {
        _loadProfile();
        _loadPlannerAlerts();
      });

  @override
  Widget build(BuildContext context) {
    final name = _profile?['full_name'] as String? ?? 'Scholar';
    final dept = _profile?['department'] as String? ?? '';
    final sid = _profile?['student_id'] as String? ?? '';
    final points = _profile?['points'] as int? ?? 50;
    final avatar = _profile?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(children: [
                  Stack(children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [
                              Color(0xFF16213E),
                              Color(0xFF1A1A2E),
                              Color(0xFF0F3460)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(36),
                            bottomRight: Radius.circular(36)),
                      ),
                      child: SafeArea(
                          child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                        child: Column(children: [
                          Row(children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Hello, ${name.split(' ').first} 👋',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14)),
                                  const Text('LU-Collab',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5)),
                                ]),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle),
                              child: IconButton(
                                  icon: const Icon(Icons.logout_rounded,
                                      color: Colors.white, size: 20),
                                  onPressed: () => supabase.auth.signOut()),
                            ),
                          ]),
                          const SizedBox(height: 22),
                          GestureDetector(
                            onTap: () => _push(ProfilePage(profile: _profile!)),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Row(children: [
                                Stack(children: [
                                  Container(
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 10)
                                        ]),
                                    child: CircleAvatar(
                                        radius: 32,
                                        backgroundColor: Colors.white24,
                                        backgroundImage: (avatar != null &&
                                                avatar.isNotEmpty)
                                            ? CachedNetworkImageProvider(avatar)
                                            : null,
                                        child:
                                            (avatar == null || avatar.isEmpty)
                                                ? const Icon(Icons.person,
                                                    size: 32,
                                                    color: Colors.white)
                                                : null),
                                  ),
                                  Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _avatarUploading
                                            ? null
                                            : _changeAvatar,
                                        child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                                color: _avatarUploading
                                                    ? Colors.grey
                                                    : kSecondary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2)),
                                            child: _avatarUploading
                                                ? const SizedBox(
                                                    width: 10,
                                                    height: 10,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white))
                                                : const Icon(Icons.edit,
                                                    size: 10,
                                                    color: Colors.white)),
                                      )),
                                ]),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      if (dept.isNotEmpty)
                                        Row(children: [
                                          const Icon(Icons.school_rounded,
                                              color: Colors.white70, size: 13),
                                          const SizedBox(width: 4),
                                          Text(dept,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                        ]),
                                      if (sid.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text('ID: $sid',
                                              style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11)),
                                        ),
                                    ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(16),
                                      border:
                                          Border.all(color: Colors.white30)),
                                  child: Column(children: [
                                    const Icon(Icons.stars_rounded,
                                        color: Color(0xFFFFD700), size: 20),
                                    const SizedBox(height: 2),
                                    Text('$points',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 17)),
                                    const Text('pts',
                                        style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10)),
                                  ]),
                                ),
                              ]),
                            ),
                          ),
                        ]),
                      )),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                  color: kPrimary,
                                  borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(width: 8),
                            const Text('Modules',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1A2E))),
                          ]),
                          const SizedBox(height: 16),
                          // Row 1
                          Row(children: [
                            Expanded(
                                child: _ModuleCard(
                              icon: Icons.folder_copy_rounded,
                              label: 'Resource Vault',
                              sub: 'Notes & PDFs',
                              gradient: const [
                                Color(0xFF0066CC),
                                Color(0xFF004499)
                              ],
                              onTap: () => _push(const VaultPage()),
                            )),
                            const SizedBox(width: 14),
                            Expanded(
                                child: _ModuleCard(
                              icon: Icons.request_page_rounded,
                              label: 'Request Board',
                              sub: 'Ask for notes ',
                              gradient: const [
                                Color(0xFF6A1B9A),
                                Color(0xFF4A148C)
                              ],
                              onTap: () => _push(const RequestPage()),
                            )),
                          ]),
                          const SizedBox(height: 14),
                          // Row 2
                          Row(children: [
                            Expanded(
                                child: _ModuleCard(
                              icon: Icons.forum_rounded,
                              label: 'Collaboration',
                              sub: 'Ask & answer',
                              gradient: const [
                                Color(0xFF00AA80),
                                Color(0xFF007A5E)
                              ],
                              onTap: () => _push(const DiscussionPage()),
                            )),
                            const SizedBox(width: 14),
                            Expanded(
                                child: _ModuleCard(
                              icon: Icons.calendar_month_rounded,
                              label: 'Planner',
                              sub: 'Track deadlines',
                              gradient: const [
                                Color(0xFFC2185B),
                                Color(0xFF880E4F)
                              ],
                              onTap: () => _push(const PlannerPage()),
                            )),
                          ]),
                          const SizedBox(height: 24),

                          //  Planner alert strip
                          if (_alertCount > 0) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: _urgentCount > 0
                                    ? const Color(0xFFFFEBEE)
                                    : const Color(0xFFFFF0F5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: (_urgentCount > 0
                                            ? Colors.red
                                            : const Color(0xFFC2185B))
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: (_urgentCount > 0
                                              ? Colors.red
                                              : const Color(0xFFC2185B))
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle),
                                  child: Icon(
                                      _urgentCount > 0
                                          ? Icons.alarm_rounded
                                          : Icons.notifications_active_rounded,
                                      color: _urgentCount > 0
                                          ? Colors.red
                                          : const Color(0xFFC2185B),
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _urgentCount > 0
                                        ? '🔴 URGENT — $_urgentCount plan${_urgentCount > 1 ? 's' : ''} within 1 hour!'
                                        : '🟡 UPCOMING — $_alertCount plan${_alertCount > 1 ? 's' : ''} within 24 hours.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _urgentCount > 0
                                            ? const Color(0xFFB71C1C)
                                            : const Color(0xFFC2185B)),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // About banner
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [
                                    kPrimary.withValues(alpha: 0.08),
                                    kSecondary.withValues(alpha: 0.06)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kPrimary.withValues(alpha: 0.12)),
                            ),
                            child: Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: kPrimary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.info_outline_rounded,
                                      color: kPrimary, size: 20)),
                              const SizedBox(width: 12),
                              const Expanded(
                                  child: Text(
                                      'Share notes, earn Points, help peers — all in one place.',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                          height: 1.4))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ]),
                  ),
                ]),
              ),
            ),
    );
  }

  int _alertCount = 0;
  int _urgentCount = 0;

  Future<void> _loadPlannerAlerts() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final data = await supabase.from('planner').select().eq('user_id', uid);
    final now = DateTime.now();
    int alerts = 0, urgent = 0;
    for (final p in data) {
      final dt = DateTime.tryParse(p['plan_date'] as String? ?? '');
      if (dt == null) continue;
      final timeStr = p['plan_time'] as String?;
      if (timeStr == null || timeStr.isEmpty) continue;
      final parts = timeStr.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final planDt = DateTime(dt.year, dt.month, dt.day, h, m);
      final diff = planDt.difference(now);
      if (diff.inMinutes > 0 && diff.inHours <= 24) alerts++;
      if (diff.inMinutes > 0 && diff.inMinutes <= 60) urgent++;
    }
    if (mounted) {
      setState(() {
        _alertCount = alerts;
        _urgentCount = urgent;
      });
    }
  }
}

// Module Card
class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ModuleCard(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.gradient,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: gradient.first.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: Colors.white, size: 22)),
                Icon(Icons.arrow_outward_rounded,
                    color: Colors.white.withValues(alpha: 0.5), size: 18),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(sub,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ]),
      ),
    );
  }
}
