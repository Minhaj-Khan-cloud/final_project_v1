import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});
  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  List<Map<String, dynamic>> _plans = [];

  bool _loading = true;

  final _uid = supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);

    final data = await supabase
        .from('planner')
        .select()
        .eq('user_id', _uid)
        .order('plan_date');

    if (mounted) {
      setState(() {
        _plans = List<Map<String, dynamic>>.from(data);

        _loading = false;
      });
    }
  }

  // Schedule notification for a plan
  Future<void> _scheduleIfNeeded(
      Map<String, dynamic> result, int notifId) async {
    final timeStr = result['plan_time'] as String?;
    final dateStr = result['plan_date'] as String?;
    if (timeStr == null || dateStr == null) return;
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return;
    final parts = timeStr.split(':');
    if (parts.length < 2) return;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final planDt = DateTime(dt.year, dt.month, dt.day, h, m);
    final now = DateTime.now();
    final title = result['title'] as String;

    // 24 hours before
    final t24 = planDt.subtract(const Duration(hours: 24));
    if (t24.isAfter(now)) {
      await schedulePlanNotification(
        id: notifId + 1000,
        title: '⏰ 24 hours left: $title',
        scheduledTime: t24,
      );
    }

    // 1 hour before
    final t1 = planDt.subtract(const Duration(hours: 1));
    if (t1.isAfter(now)) {
      await schedulePlanNotification(
        id: notifId + 2000,
        title: '⚡ 1 hour left: $title',
        scheduledTime: t1,
      );
    }

    // Exact time
    if (planDt.isAfter(now)) {
      await schedulePlanNotification(
        id: notifId,
        title: '🔔 Time now: $title',
        scheduledTime: planDt,
      );
    }
  }

  Future<void> _add() async {
    final result = await _showPlanDialog();

    if (result == null) return;

    final res = await supabase
        .from('planner')
        .insert({
          'user_id': _uid,
          'title': result['title'],
          'description': result['description'],
          'plan_date': result['plan_date'],
          'plan_time': result['plan_time'],
        })
        .select()
        .single();

    final notifId = (res['id'] as String).hashCode.abs();

    // Immediate notification to confirm plugin works
    await flutterLocalNotificationsPlugin.show(
      notifId + 9000,
      'LU-Collab Planner',
      '✅ Plan added: ${result['title']}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planner_channel',
          'Planner Alerts',
          channelDescription: 'Reminders for your upcoming academic plans',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    await _scheduleIfNeeded(result, notifId);

    if (mounted) _fetch();
  }

  Future<void> _update(Map<String, dynamic> plan) async {
    final result = await _showPlanDialog(existing: plan);

    if (result == null) return;

    try {
      await supabase.from('planner').update({
        'title': result['title'],
        'description': result['description'],
        'plan_date': result['plan_date'],
        'plan_time': result['plan_time'],
      }).eq('id', plan['id']);

      final notifId = (plan['id'] as String).hashCode.abs();
      await cancelPlanNotification(notifId);
      await cancelPlanNotification(notifId + 1000);
      await cancelPlanNotification(notifId + 2000);
      await _scheduleIfNeeded(result, notifId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plan updated successfully!'),
          backgroundColor: Color(0xFFC2185B),
          behavior: SnackBarBehavior.floating,
        ));
        _fetch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Delete Plan'),
              content: const Text('This plan will be permanently removed.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete')),
              ],
            ));

    if (ok != true) return;

    try {
      final notifId = id.hashCode.abs();
      await cancelPlanNotification(notifId);
      await cancelPlanNotification(notifId + 1000);
      await cancelPlanNotification(notifId + 2000);
      await supabase.from('planner').delete().eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plan deleted.'),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
        ));
        _fetch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<Map<String, dynamic>?> _showPlanDialog(
      {Map<String, dynamic>? existing}) async {
    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');

    DateTime? date = existing?['plan_date'] != null
        ? DateTime.tryParse(existing!['plan_date'] as String)
        : null;

    TimeOfDay? time;
    if (existing?['plan_time'] != null) {
      final parts = (existing!['plan_time'] as String).split(':');
      if (parts.length >= 2) {
        time = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }

    return showModalBottomSheet<Map<String, dynamic>>(
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
                    top: 20,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                      const SizedBox(height: 16),
                      Row(children: [
                        Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: const Color(0xFFC2185B)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(
                                existing == null
                                    ? Icons.add_task
                                    : Icons.edit_calendar_rounded,
                                color: const Color(0xFFC2185B))),
                        const SizedBox(width: 12),
                        Text(existing == null ? 'Add New Plan' : 'Edit Plan',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 20),
                      TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Title *',
                              hintText: 'e.g. DBMS Exam',
                              prefixIcon: Icon(Icons.title_rounded))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Details (optional)',
                              hintText: 'e.g. Cover chapters 4-7',
                              prefixIcon: Icon(Icons.notes_rounded))),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                              context: ctx,
                              initialDate: date != null &&
                                      !date!.isBefore(DateTime.now())
                                  ? date!
                                  : DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 730)));

                          if (picked != null) setS(() => date = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Date *',
                              prefixIcon: Icon(Icons.calendar_today_rounded)),
                          child: Text(
                              date == null
                                  ? 'Tap to pick a date'
                                  : DateFormat('EEE, dd MMM yyyy')
                                      .format(date!),
                              style: TextStyle(
                                  color: date == null
                                      ? Colors.grey
                                      : Colors.black87)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                              context: ctx,
                              initialTime: time ?? TimeOfDay.now());
                          if (picked != null) setS(() => time = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                              labelText: 'Time (optional)',
                              prefixIcon: const Icon(Icons.access_time_rounded),
                              suffixIcon: time != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setS(() => time = null))
                                  : null),
                          child: Text(
                              time == null ? 'No time set' : time!.format(ctx),
                              style: TextStyle(
                                  color: time == null
                                      ? Colors.grey
                                      : Colors.black87)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (titleCtrl.text.trim().isEmpty || date == null) {
                            return;
                          }

                          Navigator.pop(ctx, {
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'plan_date':
                                date!.toIso8601String().substring(0, 10),
                            'plan_time': time == null
                                ? null
                                : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}:00',
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC2185B),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                            existing == null ? 'Add Plan' : 'Save Changes',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ]),
              )),
    );
  }

  int get _upcoming => _plans.where((p) {
        final dt = DateTime.tryParse(p['plan_date'] as String? ?? '');
        return dt != null &&
            !dt.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      }).length;

  int get _past => _plans.length - _upcoming;

  // Plans that are happening soon (within 24 hours + time set)
  List<Map<String, dynamic>> get _upcomingAlerts {
    final now = DateTime.now();
    final alerts = <Map<String, dynamic>>[];
    for (final p in _plans) {
      final dt = DateTime.tryParse(p['plan_date'] as String? ?? '');
      if (dt == null) continue;
      final timeStr = p['plan_time'] as String?;
      if (timeStr == null || timeStr.isEmpty) continue;
      final parts = timeStr.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final planDateTime = DateTime(dt.year, dt.month, dt.day, h, m);
      final diff = planDateTime.difference(now);
      // Show alert if within 24 hours and in the future
      if (diff.inMinutes > 0 && diff.inHours <= 24) {
        alerts.add({...p, '_diff': diff, '_planDateTime': planDateTime});
      }
    }
    alerts.sort((a, b) => (a['_planDateTime'] as DateTime)
        .compareTo(b['_planDateTime'] as DateTime));
    return alerts;
  }

  String _diffLabel(Duration diff) {
    if (diff.inMinutes <= 5) return '🔴 URGENT — In ${diff.inMinutes} min';
    if (diff.inMinutes < 60) return '🔴 URGENT — In ${diff.inMinutes} min';
    if (diff.inHours == 1) return '🟡 Upcoming — In 1 hour';
    return '🟡 Upcoming — In ${diff.inHours} hours';
  }

  bool _isUrgent(Duration diff) => diff.inMinutes > 0 && diff.inMinutes <= 60;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final p in _plans) {
      final dt =
          DateTime.tryParse(p['plan_date'] as String? ?? '') ?? DateTime.now();

      grouped.putIfAbsent(DateFormat('MMMM yyyy').format(dt), () => []).add(p);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFFC2185B),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFC2185B), Color(0xFF880E4F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)),
                child: SafeArea(
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 36),
                        const Text('Academic Planner',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(children: [
                          _StatChip(
                              label: '${_plans.length}',
                              sub: 'Total',
                              icon: Icons.list_alt_rounded),
                          const SizedBox(width: 10),
                          _StatChip(
                              label: '$_upcoming',
                              sub: 'Upcoming',
                              icon: Icons.upcoming_rounded),
                          const SizedBox(width: 10),
                          _StatChip(
                              label: '$_past',
                              sub: 'Past',
                              icon: Icons.history_rounded),
                        ]),
                      ]),
                )),
              ),
            ),
          ),

          // Notification banner — upcoming plans with time set
          if (!_loading && _upcomingAlerts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._upcomingAlerts.map((p) {
                      final diff = p['_diff'] as Duration;
                      final urgent = _isUrgent(diff);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: urgent
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: (urgent
                                      ? Colors.red
                                      : const Color(0xFFC2185B))
                                  .withValues(alpha: 0.35)),
                        ),
                        child: Row(children: [
                          Icon(
                              urgent
                                  ? Icons.warning_amber_rounded
                                  : Icons.alarm_rounded,
                              size: 18,
                              color: urgent
                                  ? Colors.red
                                  : const Color(0xFFC2185B)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: urgent
                                            ? Colors.red
                                            : const Color(0xFFC2185B),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        urgent ? 'URGENT' : 'UPCOMING',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(p['title'] as String,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                                  const SizedBox(height: 3),
                                  Text(_diffLabel(diff),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: urgent
                                              ? Colors.red
                                              : const Color(0xFFC2185B),
                                          fontWeight: FontWeight.w600)),
                                ]),
                          ),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
            ),

          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else if (_plans.isEmpty)
            SliverFillRemaining(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFFC2185B).withValues(alpha: 0.08),
                            shape: BoxShape.circle),
                        child: Icon(Icons.calendar_month_rounded,
                            size: 56,
                            color: const Color(0xFFC2185B)
                                .withValues(alpha: 0.5))),
                    const SizedBox(height: 16),
                    const Text('No plans yet',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black45)),
                    const SizedBox(height: 6),
                    const Text('Start scheduling your academic events',
                        style: TextStyle(color: Colors.grey)),
                  ])),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, idx) {
                    final entries = grouped.entries.toList();
                    int counter = 0;

                    for (final entry in entries) {
                      if (idx == counter) return _MonthHeader(label: entry.key);
                      counter++;

                      if (idx < counter + entry.value.length) {
                        final plan = entry.value[idx - counter];
                        return _PlanTile(
                            plan: plan,
                            onEdit: () => _update(plan),
                            onDelete: () => _delete(plan['id'] as String));
                      }
                      counter += entry.value.length;
                    }
                    return null;
                  },
                  childCount: grouped.entries
                      .fold<int>(0, (s, e) => s + 1 + e.value.length),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Plan',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFC2185B),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  const _StatChip({required this.label, required this.sub, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text('$label $sub',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _MonthHeader extends StatelessWidget {
  final String label;
  const _MonthHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(children: [
          Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: const Color(0xFFC2185B),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC2185B),
                  letterSpacing: 0.3)),
        ]),
      );
}

class _PlanTile extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onEdit, onDelete;
  const _PlanTile(
      {required this.plan, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dt =
        DateTime.tryParse(plan['plan_date'] as String? ?? '') ?? DateTime.now();
    final today = DateTime.now();

    final isToday =
        dt.year == today.year && dt.month == today.month && dt.day == today.day;

    final isPast = dt.isBefore(DateTime(today.year, today.month, today.day));

    final desc = plan['description'] as String? ?? '';
    final timeStr = plan['plan_time'] as String?;
    String? formattedTime;
    if (timeStr != null && timeStr.isNotEmpty) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final period = h >= 12 ? 'PM' : 'AM';
        final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        formattedTime = '$h12:${m.toString().padLeft(2, '0')} $period';
      }
    }

    final Color accent = isToday
        ? const Color(0xFFC2185B)
        : isPast
            ? Colors.grey.shade400
            : kPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isToday
            ? Border.all(color: const Color(0xFFC2185B), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(14)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(DateFormat('dd').format(dt),
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 20, color: accent)),
            Text(DateFormat('MMM').format(dt).toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accent.withValues(alpha: 0.8),
                    letterSpacing: 0.5)),
            if (isToday)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: const Color(0xFFC2185B),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('TODAY',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
        Expanded(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plan['title'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isPast && !isToday ? Colors.grey : Colors.black87,
                  decoration:
                      isPast && !isToday ? TextDecoration.lineThrough : null,
                )),
            if (formattedTime != null) ...[
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time_rounded,
                    size: 12, color: isPast && !isToday ? Colors.grey : accent),
                const SizedBox(width: 3),
                Text(formattedTime,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPast && !isToday ? Colors.grey : accent)),
              ]),
            ],
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey, height: 1.4)),
            ],
          ]),
        )),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: kPrimary.withValues(alpha: 0.7)),
              onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.redAccent),
              onPressed: onDelete),
        ]),
      ]),
    );
  }
}
