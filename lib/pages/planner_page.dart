// ─────────────────────────────────────────────────────────────
// planner_page.dart — Academic Planner Module
// LU-Collab Project | Team: Afsana, Minhaj, Amlan
// ─────────────────────────────────────────────────────────────

// Flutter UI package — সব widget যেমন Text, Column, Row এখান থেকে আসে
import 'package:flutter/material.dart';

// Date format করার জন্য — যেমন "Mon, 18 Jun 2026" এই format এ দেখানো
import 'package:intl/intl.dart';

// Device notification দেওয়ার জন্য plugin
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// main.dart থেকে supabase, kPrimary, schedulePlanNotification ইত্যাদি আনা হচ্ছে
import '../main.dart';

// ─────────────────────────────────────────────────────────────
// PlannerPage — StatefulWidget কারণ data load হয় এবং state change হয়
// ─────────────────────────────────────────────────────────────
class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key}); // const constructor — performance এর জন্য

  @override
  // State object তৈরি করে — এখানেই সব logic থাকবে
  State<PlannerPage> createState() => _PlannerPageState();
}

// ─────────────────────────────────────────────────────────────
// _PlannerPageState — PlannerPage এর সব state এবং logic এখানে
// ─────────────────────────────────────────────────────────────
class _PlannerPageState extends State<PlannerPage> {
  // সব plan গুলো এই list এ রাখা হয় — প্রতিটা plan একটা Map
  List<Map<String, dynamic>> _plans = [];

  // true থাকলে loading spinner দেখায়, false হলে list দেখায়
  bool _loading = true;

  // বর্তমানে logged-in user এর ID — Supabase থেকে নেওয়া হচ্ছে
  // ?? '' মানে null হলে empty string দাও
  final _uid = supabase.auth.currentUser?.id ?? '';

  @override
  // Widget screen এ আসলে প্রথমবার এই function run হয়
  void initState() {
    super.initState(); // parent class এর initState call করা জরুরি
    _fetch(); // page খুললেই plans load করো
  }

  // ─── Database থেকে plans load করার function ───────────────
  Future<void> _fetch() async {
    // loading শুরু — UI তে spinner দেখাবে
    setState(() => _loading = true);

    // Supabase এর 'planner' table থেকে data নিচ্ছি
    final data = await supabase
        .from('planner') // planner table
        .select() // সব column select করো
        .eq('user_id', _uid) // শুধু এই user এর plans
        .order('plan_date'); // date অনুযায়ী sort করো

    // mounted check — widget এখনো screen এ আছে কিনা দেখছি
    // না থাকলে setState call করলে error হবে
    if (mounted) {
      setState(() {
        // data কে List<Map> format এ convert করে _plans এ রাখছি
        _plans = List<Map<String, dynamic>>.from(data);
        // loading শেষ — spinner সরিয়ে list দেখাবে
        _loading = false;
      });
    }
  }

  // ─── Notification Schedule করার function ──────────────────
  // result = plan এর data, notifId = unique notification ID
  Future<void> _scheduleIfNeeded(
      Map<String, dynamic> result, int notifId) async {
    // plan এর time এবং date নেওয়া হচ্ছে
    final timeStr = result['plan_time'] as String?;
    final dateStr = result['plan_date'] as String?;

    // time বা date না থাকলে notification দেওয়া সম্ভব না, তাই return
    if (timeStr == null || dateStr == null) return;

    // date string কে DateTime object এ convert করছি
    final dt = DateTime.tryParse(dateStr);

    // date parse না হলে return
    if (dt == null) return;

    // time string কে ':' দিয়ে ভাগ করছি — যেমন "14:30:00" → ["14","30","00"]
    final parts = timeStr.split(':');

    // কমপক্ষে 2 part না থাকলে (hour, minute) return
    if (parts.length < 2) return;

    // hour এবং minute আলাদা করে নিচ্ছি
    final h = int.tryParse(parts[0]) ?? 0; // hour, parse না হলে 0
    final m = int.tryParse(parts[1]) ?? 0; // minute, parse না হলে 0

    // plan এর সম্পূর্ণ date+time মিলিয়ে একটা DateTime তৈরি করছি
    final planDt = DateTime(dt.year, dt.month, dt.day, h, m);

    // এখনকার সময়
    final now = DateTime.now();

    // plan এর title নিচ্ছি notification message এর জন্য
    final title = result['title'] as String;

    // ── 24 ঘণ্টা আগের notification ──
    // plan time থেকে 24 ঘণ্টা বিয়োগ করে alert time বের করছি
    final t24 = planDt.subtract(const Duration(hours: 24));

    // যদি 24 ঘণ্টা আগের সময়টা এখনও ভবিষ্যতে থাকে তাহলে schedule করো
    if (t24.isAfter(now)) {
      await schedulePlanNotification(
        id: notifId + 1000, // unique ID — 1000 যোগ করে আলাদা করা
        title: '⏰ 24 hours left: $title', // notification এর message
        scheduledTime: t24, // কখন দেখাবে
      );
    }

    // ── 1 ঘণ্টা আগের notification ──
    // plan time থেকে 1 ঘণ্টা বিয়োগ করে alert time বের করছি
    final t1 = planDt.subtract(const Duration(hours: 1));

    // যদি 1 ঘণ্টা আগের সময়টা এখনও ভবিষ্যতে থাকে তাহলে schedule করো
    if (t1.isAfter(now)) {
      await schedulePlanNotification(
        id: notifId + 2000, // unique ID — 2000 যোগ করে আলাদা করা
        title: '⚡ 1 hour left: $title', // notification এর message
        scheduledTime: t1, // কখন দেখাবে
      );
    }

    // ── Exact time notification (plan এর সময়ে) ──
    // plan এর সময় যদি এখনও ভবিষ্যতে থাকে তাহলে schedule করো
    if (planDt.isAfter(now)) {
      await schedulePlanNotification(
        id: notifId, // original ID
        title: '🔔 Time now: $title', // notification এর message
        scheduledTime: planDt, // plan এর exact সময়ে
      );
    }
  }

  // ─── নতুন Plan যোগ করার function ──────────────────────────
  Future<void> _add() async {
    // Dialog খুলে user থেকে plan এর details নেওয়া হচ্ছে
    // result = user যা input দিয়েছে, cancel করলে null আসে
    final result = await _showPlanDialog();

    // user cancel করলে কিছু করা হবে না
    if (result == null) return;

    // Supabase 'planner' table এ নতুন row insert করছি
    // .select().single() মানে — insert এর পর ঐ row টাই return করো
    final res = await supabase
        .from('planner')
        .insert({
          'user_id': _uid, // কোন user এর plan
          'title': result['title'], // plan এর title
          'description': result['description'], // plan এর details
          'plan_date': result['plan_date'], // plan এর date
          'plan_time': result['plan_time'], // plan এর time (optional)
        })
        .select() // insert এর পর data return করো
        .single(); // একটাই row থাকবে

    // Supabase এর UUID (id) কে integer এ convert করছি notification ID হিসেবে
    // .hashCode দিয়ে string থেকে int, .abs() দিয়ে positive করছি
    final notifId = (res['id'] as String).hashCode.abs();

    // ── Plan add হওয়ার সাথে সাথে একটা immediate notification দেখাচ্ছি ──
    // এটা confirm করে যে notification plugin ঠিকমতো কাজ করছে
    await flutterLocalNotificationsPlugin.show(
      notifId +
          9000, // unique ID (9000 যোগ করা যাতে অন্যগুলোর সাথে clash না হয়)
      'LU-Collab Planner', // notification এর title
      '✅ Plan added: ${result['title']}', // notification এর body
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planner_channel', // channel ID — AndroidManifest এ register করা
          'Planner Alerts', // channel এর নাম
          channelDescription: 'Reminders for your upcoming academic plans',
          importance: Importance.high, // notification priority high
          priority: Priority.high, // notification priority high
        ),
      ),
    );

    // plan এর time থাকলে scheduled notifications দেওয়া হবে
    await _scheduleIfNeeded(result, notifId);

    // widget এখনো screen এ থাকলে plans list refresh করো
    if (mounted) _fetch();
  }

  // ─── Plan Edit করার function ──────────────────────────────
  // plan = যে plan edit হবে তার data
  Future<void> _update(Map<String, dynamic> plan) async {
    // Dialog খুলে existing plan এর data pre-fill করে দিচ্ছি
    final result = await _showPlanDialog(existing: plan);

    // user cancel করলে কিছু করা হবে না
    if (result == null) return;

    try {
      // Supabase 'planner' table এ existing row update করছি
      await supabase.from('planner').update({
        'title': result['title'], // নতুন title
        'description': result['description'], // নতুন description
        'plan_date': result['plan_date'], // নতুন date
        'plan_time': result['plan_time'], // নতুন time
      }).eq('id', plan['id']); // শুধু এই specific plan update করো

      // plan এর ID থেকে notification ID বের করছি
      final notifId = (plan['id'] as String).hashCode.abs();

      // পুরনো সব notifications cancel করছি (3টা — exact, 1h, 24h)
      await cancelPlanNotification(notifId); // exact time notification
      await cancelPlanNotification(
          notifId + 1000); // 24 ঘণ্টা আগের notification
      await cancelPlanNotification(notifId + 2000); // 1 ঘণ্টা আগের notification

      // নতুন time দিয়ে আবার notifications schedule করছি
      await _scheduleIfNeeded(result, notifId);

      // widget এখনো screen এ থাকলে success message এবং list refresh
      if (mounted) {
        // সবুজ snackbar দিয়ে success জানাচ্ছি
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plan updated successfully!'),
          backgroundColor: Color(0xFFC2185B), // magenta রঙ
          behavior: SnackBarBehavior.floating, // নিচে ভাসমান দেখাবে
        ));
        _fetch(); // plans list আবার load করো
      }
    } catch (e) {
      // কোনো error হলে user কে error message দেখাচ্ছি
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), // error message দেখাচ্ছি
          backgroundColor: Colors.redAccent, // লাল রঙ
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ─── Plan Delete করার function ────────────────────────────
  // id = যে plan delete হবে তার Supabase UUID
  Future<void> _delete(String id) async {
    // Confirmation dialog দেখাচ্ছি — user কে নিশ্চিত করতে হবে
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              // dialog এর corner গোলাকার করছি
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Delete Plan'), // dialog এর title
              content: const Text(
                  'This plan will be permanently removed.'), // সতর্কবার্তা
              actions: [
                // Cancel button — dialog বন্ধ করে false return করে
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                // Delete button — dialog বন্ধ করে true return করে
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent), // লাল button
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete')),
              ],
            ));

    // user cancel করলে (false বা null) কিছু করা হবে না
    if (ok != true) return;

    try {
      // plan এর ID থেকে notification ID বের করছি
      final notifId = id.hashCode.abs();

      // সব scheduled notifications cancel করছি delete করার আগে
      await cancelPlanNotification(notifId); // exact time
      await cancelPlanNotification(notifId + 1000); // 24h আগে
      await cancelPlanNotification(notifId + 2000); // 1h আগে

      // Supabase 'planner' table থেকে এই plan delete করছি
      await supabase.from('planner').delete().eq('id', id);

      // widget এখনো screen এ থাকলে success message এবং list refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plan deleted.'),
          backgroundColor: Colors.grey, // ধূসর রঙ
          behavior: SnackBarBehavior.floating,
        ));
        _fetch(); // plans list আবার load করো
      }
    } catch (e) {
      // error হলে user কে জানাচ্ছি
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ─── Plan Add/Edit Dialog (Bottom Sheet) ──────────────────
  // existing = null হলে Add, কিছু থাকলে Edit mode
  Future<Map<String, dynamic>?> _showPlanDialog(
      {Map<String, dynamic>? existing}) async {
    // Title এর জন্য TextEditingController — edit mode এ existing title pre-fill
    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');

    // Description এর জন্য controller — edit mode এ existing description pre-fill
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');

    // Edit mode এ existing date নেওয়া হচ্ছে, নাহলে null
    DateTime? date = existing?['plan_date'] != null
        ? DateTime.tryParse(existing!['plan_date'] as String)
        : null;

    // Edit mode এ existing time নেওয়া হচ্ছে
    TimeOfDay? time;
    if (existing?['plan_time'] != null) {
      // "14:30:00" কে ":" দিয়ে ভাগ করছি
      final parts = (existing!['plan_time'] as String).split(':');
      if (parts.length >= 2) {
        // TimeOfDay object তৈরি করছি hour এবং minute দিয়ে
        time = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }

    // Bottom sheet দেখাচ্ছি — screen এর নিচ থেকে উঠে আসবে
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true, // keyboard উঠলে sheet ও উপরে উঠবে
      backgroundColor: Colors.white,
      // উপরের দুই কোণ গোলাকার
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      // StatefulBuilder — sheet এর ভেতরে state manage করার জন্য
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
                // keyboard উঠলে bottom padding বাড়বে যাতে content দেখা যায়
                padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
                child: Column(
                    mainAxisSize: MainAxisSize.min, // content এর সমান উচ্চতা
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Sheet এর উপরে ছোট drag indicator line ──
                      Center(
                          child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2)))),

                      const SizedBox(height: 16), // ফাঁকা জায়গা

                      // ── Sheet এর header — icon + title ──
                      Row(children: [
                        Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                // icon এর background — হালকা magenta
                                color: const Color(0xFFC2185B)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(
                                // Add mode এ add icon, Edit mode এ edit icon
                                existing == null
                                    ? Icons.add_task
                                    : Icons.edit_calendar_rounded,
                                color: const Color(0xFFC2185B))),
                        const SizedBox(width: 12),
                        // Add mode এ "Add New Plan", Edit mode এ "Edit Plan"
                        Text(existing == null ? 'Add New Plan' : 'Edit Plan',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),

                      const SizedBox(height: 20),

                      // ── Title input field ──
                      TextField(
                          controller:
                              titleCtrl, // এই controller দিয়ে value পড়া হবে
                          decoration: const InputDecoration(
                              labelText: 'Title *', // * মানে required
                              hintText: 'e.g. DBMS Exam', // placeholder
                              prefixIcon: Icon(Icons.title_rounded))),

                      const SizedBox(height: 12),

                      // ── Description input field (optional) ──
                      TextField(
                          controller: descCtrl,
                          maxLines: 2, // সর্বোচ্চ 2 line দেখাবে
                          decoration: const InputDecoration(
                              labelText: 'Details (optional)',
                              hintText: 'e.g. Cover chapters 4-7',
                              prefixIcon: Icon(Icons.notes_rounded))),

                      const SizedBox(height: 12),

                      // ── Date picker ──
                      InkWell(
                        onTap: () async {
                          // Calendar dialog খুলছি
                          final picked = await showDatePicker(
                              context: ctx,
                              // যদি existing date future এ হয় তাহলে সেটা দেখাও
                              // নাহলে আজকের date দেখাও
                              initialDate: date != null &&
                                      !date!.isBefore(DateTime.now())
                                  ? date!
                                  : DateTime.now(),
                              firstDate: DateTime.now(), // আজ থেকে শুরু
                              lastDate: DateTime.now().add(
                                  const Duration(days: 730))); // 2 বছর পর্যন্ত

                          // date select হলে state update করো
                          if (picked != null) setS(() => date = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Date *',
                              prefixIcon: Icon(Icons.calendar_today_rounded)),
                          // date select না হলে placeholder, হলে formatted date
                          child: Text(
                              date == null
                                  ? 'Tap to pick a date'
                                  : DateFormat('EEE, dd MMM yyyy')
                                      .format(date!),
                              style: TextStyle(
                                  // date না থাকলে ধূসর, থাকলে কালো
                                  color: date == null
                                      ? Colors.grey
                                      : Colors.black87)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Time picker (optional) ──
                      InkWell(
                        onTap: () async {
                          // Time picker dialog খুলছি
                          final picked = await showTimePicker(
                              context: ctx,
                              // time আগে set থাকলে সেটা দেখাও, নাহলে এখনকার time
                              initialTime: time ?? TimeOfDay.now());
                          // time select হলে state update করো
                          if (picked != null) setS(() => time = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                              labelText: 'Time (optional)',
                              prefixIcon: const Icon(Icons.access_time_rounded),
                              // time set থাকলে clear button দেখাচ্ছি
                              suffixIcon: time != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      // clear button এ tap করলে time সরিয়ে দাও
                                      onPressed: () => setS(() => time = null))
                                  : null),
                          // time না থাকলে "No time set", থাকলে formatted time
                          child: Text(
                              time == null ? 'No time set' : time!.format(ctx),
                              style: TextStyle(
                                  color: time == null
                                      ? Colors.grey
                                      : Colors.black87)),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Save button ──
                      ElevatedButton(
                        onPressed: () {
                          // Validation — title খালি বা date না থাকলে কিছু করবে না
                          if (titleCtrl.text.trim().isEmpty || date == null) {
                            return;
                          }

                          // sheet বন্ধ করে data return করছি
                          Navigator.pop(ctx, {
                            'title': titleCtrl.text
                                .trim(), // title (trim করে whitespace সরাচ্ছি)
                            'description': descCtrl.text.trim(),
                            // date কে "2026-06-18" format এ convert করছি
                            'plan_date':
                                date!.toIso8601String().substring(0, 10),
                            // time থাকলে "14:30:00" format এ, না থাকলে null
                            'plan_time': time == null
                                ? null
                                : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}:00',
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFC2185B), // magenta button
                          minimumSize: const Size.fromHeight(48), // full width
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        // Add mode এ "Add Plan", Edit mode এ "Save Changes"
                        child: Text(
                            existing == null ? 'Add Plan' : 'Save Changes',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ]),
              )),
    );
  }

  // ─── Upcoming plans count (আজ বা ভবিষ্যতের plans) ─────────
  // getter — property এর মতো use করা যায় কিন্তু calculate করে
  int get _upcoming => _plans.where((p) {
        // plan এর date parse করছি
        final dt = DateTime.tryParse(p['plan_date'] as String? ?? '');
        // আজকের আগের দিন থেকে শুরু করে future plans count করছি
        return dt != null &&
            !dt.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      }).length;

  // ─── Past plans count ──────────────────────────────────────
  // মোট plans থেকে upcoming বিয়োগ করলে past পাওয়া যাবে
  int get _past => _plans.length - _upcoming;

  // ─── 24 ঘণ্টার মধ্যে upcoming plans এর list ───────────────
  // এই list টা notification banner এ দেখানো হয়
  List<Map<String, dynamic>> get _upcomingAlerts {
    final now = DateTime.now(); // এখনকার সময়
    final alerts = <Map<String, dynamic>>[]; // alert এর list

    // সব plans loop করছি
    for (final p in _plans) {
      // plan এর date parse করছি
      final dt = DateTime.tryParse(p['plan_date'] as String? ?? '');
      if (dt == null) continue; // date parse না হলে skip

      // plan এর time নিচ্ছি
      final timeStr = p['plan_time'] as String?;
      // time না থাকলে skip — time ছাড়া alert দেওয়া সম্ভব না
      if (timeStr == null || timeStr.isEmpty) continue;

      // time string ভাগ করছি
      final parts = timeStr.split(':');
      if (parts.length < 2) continue; // invalid time হলে skip

      // hour এবং minute আলাদা করছি
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;

      // plan এর সম্পূর্ণ date+time
      final planDateTime = DateTime(dt.year, dt.month, dt.day, h, m);

      // plan time থেকে এখনকার সময় বিয়োগ করে পার্থক্য বের করছি
      final diff = planDateTime.difference(now);

      // শুধু ভবিষ্যতের এবং 24 ঘণ্টার মধ্যের plans alert এ দেখাবো
      if (diff.inMinutes > 0 && diff.inHours <= 24) {
        // plan data তে diff এবং planDateTime যোগ করে alerts list এ রাখছি
        alerts.add({...p, '_diff': diff, '_planDateTime': planDateTime});
      }
    }

    // সময় অনুযায়ী sort করছি — সবচেয়ে কাছের plan আগে দেখাবে
    alerts.sort((a, b) => (a['_planDateTime'] as DateTime)
        .compareTo(b['_planDateTime'] as DateTime));
    return alerts;
  }

  // ─── Alert এর label text তৈরির function ──────────────────
  // diff = এখন থেকে plan পর্যন্ত সময়ের পার্থক্য
  String _diffLabel(Duration diff) {
    // 5 মিনিট বা কম — URGENT এবং minute দেখাচ্ছি
    if (diff.inMinutes <= 5) return '🔴 URGENT — In ${diff.inMinutes} min';
    // 1 ঘণ্টার কম — URGENT এবং minute দেখাচ্ছি
    if (diff.inMinutes < 60) return '🔴 URGENT — In ${diff.inMinutes} min';
    // ঠিক 1 ঘণ্টা — Upcoming দেখাচ্ছি
    if (diff.inHours == 1) return '🟡 Upcoming — In 1 hour';
    // 1+ ঘণ্টা — Upcoming এবং hour দেখাচ্ছি
    return '🟡 Upcoming — In ${diff.inHours} hours';
  }

  // ─── 1 ঘণ্টার মধ্যে থাকলে urgent true ────────────────────
  bool _isUrgent(Duration diff) => diff.inMinutes > 0 && diff.inMinutes <= 60;

  // ─── UI তৈরির main function ────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // plans গুলোকে month অনুযায়ী group করছি
    // key = "June 2026", value = ঐ মাসের plans এর list
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final p in _plans) {
      // plan এর date বের করছি, না পেলে আজকের date
      final dt =
          DateTime.tryParse(p['plan_date'] as String? ?? '') ?? DateTime.now();
      // "MMMM yyyy" format মানে "June 2026" এই format
      // putIfAbsent — key না থাকলে নতুন list তৈরি করো, তারপর plan যোগ করো
      grouped.putIfAbsent(DateFormat('MMMM yyyy').format(dt), () => []).add(p);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF), // হালকা নীল background

      // CustomScrollView — SliverAppBar এর জন্য দরকার
      body: CustomScrollView(
        slivers: [
          // ── Collapsible header (scroll করলে ছোট হয়) ──
          SliverAppBar(
            expandedHeight: 160, // সর্বোচ্চ height
            pinned: true, // scroll করলে pinned থাকে
            backgroundColor: const Color(0xFFC2185B), // magenta রঙ
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                // magenta থেকে dark magenta gradient
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFC2185B), Color(0xFF880E4F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)),
                child: SafeArea(
                    // status bar এর নিচ থেকে শুরু করছি
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 36), // back button এর জায়গা
                        // Page এর title
                        const Text('Academic Planner',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        // Stats chips — Total, Upcoming, Past
                        Row(children: [
                          // মোট plans count
                          _StatChip(
                              label: '${_plans.length}',
                              sub: 'Total',
                              icon: Icons.list_alt_rounded),
                          const SizedBox(width: 10),
                          // আজ বা ভবিষ্যতের plans count
                          _StatChip(
                              label: '$_upcoming',
                              sub: 'Upcoming',
                              icon: Icons.upcoming_rounded),
                          const SizedBox(width: 10),
                          // পুরনো plans count
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

          // ── Upcoming alerts banner (24 ঘণ্টার মধ্যে plans থাকলে দেখাবে) ──
          // loading না হলে এবং alerts থাকলে এই section দেখাবে
          if (!_loading && _upcomingAlerts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // প্রতিটা alert এর জন্য একটা card দেখাচ্ছি
                    ..._upcomingAlerts.map((p) {
                      final diff = p['_diff'] as Duration; // সময়ের পার্থক্য
                      final urgent =
                          _isUrgent(diff); // 1 ঘণ্টার মধ্যে হলে urgent

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          // urgent হলে হালকা লাল, নাহলে হালকা গোলাপী
                          color: urgent
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              // urgent হলে লাল border, নাহলে magenta border
                              color: (urgent
                                      ? Colors.red
                                      : const Color(0xFFC2185B))
                                  .withValues(alpha: 0.35)),
                        ),
                        child: Row(children: [
                          // urgent হলে warning icon, নাহলে alarm icon
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
                                    // URGENT বা UPCOMING badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        // urgent হলে লাল badge, নাহলে magenta
                                        color: urgent
                                            ? Colors.red
                                            : const Color(0xFFC2185B),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        // urgent হলে "URGENT", নাহলে "UPCOMING"
                                        urgent ? 'URGENT' : 'UPCOMING',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Plan এর title — overflow হলে ... দেখাবে
                                    Expanded(
                                      child: Text(p['title'] as String,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                                  const SizedBox(height: 3),
                                  // কতক্ষণ পরে plan — যেমন "🔴 URGENT — In 45 min"
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

          // ── Loading spinner দেখাচ্ছি ──
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))

          // ── কোনো plan না থাকলে empty state দেখাচ্ছি ──
          else if (_plans.isEmpty)
            SliverFillRemaining(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    // Calendar icon — background circle এর মধ্যে
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

          // ── Plans list দেখাচ্ছি (month অনুযায়ী grouped) ──
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, 100), // নিচে FAB এর জায়গা
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, idx) {
                    // grouped map এর entries list
                    final entries = grouped.entries.toList();
                    int counter = 0; // current index tracker

                    // প্রতিটা month group loop করছি
                    for (final entry in entries) {
                      // এই index এ month header দেখাবে
                      if (idx == counter) return _MonthHeader(label: entry.key);
                      counter++;

                      // এই index এ কোনো plan card দেখাবে
                      if (idx < counter + entry.value.length) {
                        final plan =
                            entry.value[idx - counter]; // specific plan
                        // Plan card widget return করছি
                        return _PlanTile(
                            plan: plan,
                            onEdit: () => _update(plan), // edit button
                            onDelete: () =>
                                _delete(plan['id'] as String)); // delete button
                      }
                      counter += entry.value.length; // counter এগিয়ে নিচ্ছি
                    }
                    return null; // কোনো widget না থাকলে null
                  },
                  // মোট item count — প্রতিটা month এর জন্য 1 header + তার plans count
                  childCount: grouped.entries
                      .fold<int>(0, (s, e) => s + 1 + e.value.length),
                ),
              ),
            ),
        ],
      ),

      // ── Floating Action Button — Add Plan ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add, // tap করলে _add() call হবে
        icon: const Icon(Icons.add_rounded), // + icon
        label: const Text('Add Plan',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFC2185B), // magenta রঙ
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _StatChip — Header এ stats দেখানোর ছোট widget
// label = সংখ্যা, sub = নাম, icon = icon
// ─────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label; // যেমন "5"
  final String sub; // যেমন "Total"
  final IconData icon; // যেমন Icons.list_alt_rounded

  const _StatChip({required this.label, required this.sub, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            // সাদা রঙ — কিন্তু 20% opacity তে (semi-transparent)
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20)), // pill shape
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 14), // ছোট icon
          const SizedBox(width: 5),
          // "5 Total" এই format এ দেখাচ্ছি
          Text('$label $sub',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// _MonthHeader — Month এর নাম দেখানোর widget
// যেমন "| June 2026"
// ─────────────────────────────────────────────────────────────
class _MonthHeader extends StatelessWidget {
  final String label; // যেমন "June 2026"
  const _MonthHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(children: [
          // বাম দিকে magenta vertical line — accent bar
          Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: const Color(0xFFC2185B),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          // Month এর নাম
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC2185B),
                  letterSpacing: 0.3)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// _PlanTile — একটা plan card widget
// plan = plan এর data, onEdit/onDelete = callback functions
// ─────────────────────────────────────────────────────────────
class _PlanTile extends StatelessWidget {
  final Map<String, dynamic> plan; // plan এর সব data
  final VoidCallback onEdit; // edit button tap হলে কী করবে
  final VoidCallback onDelete; // delete button tap হলে কী করবে

  const _PlanTile(
      {required this.plan, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    // plan এর date parse করছি, না পারলে আজকের date
    final dt =
        DateTime.tryParse(plan['plan_date'] as String? ?? '') ?? DateTime.now();

    // আজকের date
    final today = DateTime.now();

    // plan আজকের দিনে কিনা check করছি (year, month, day সবই মিলতে হবে)
    final isToday =
        dt.year == today.year && dt.month == today.month && dt.day == today.day;

    // plan এর date আজকের আগে কিনা — তাহলে past
    final isPast = dt.isBefore(DateTime(today.year, today.month, today.day));

    // plan এর description — না থাকলে empty string
    final desc = plan['description'] as String? ?? '';

    // plan এর time string — optional
    final timeStr = plan['plan_time'] as String?;

    // formatted time string — যেমন "2:30 PM"
    String? formattedTime;
    if (timeStr != null && timeStr.isNotEmpty) {
      // "14:30:00" কে ভাগ করছি
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0; // hour (24h format)
        final m = int.tryParse(parts[1]) ?? 0; // minute
        // 12h format এ convert করছি
        final period = h >= 12 ? 'PM' : 'AM'; // AM বা PM
        // 12h convert — 0 হলে 12, 12+ হলে বিয়োগ করো
        final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        // "2:30 PM" format এ রাখছি
        formattedTime = '$h12:${m.toString().padLeft(2, '0')} $period';
      }
    }

    // card এর accent রঙ — আজকে হলে magenta, past হলে grey, নাহলে blue
    final Color accent = isToday
        ? const Color(0xFFC2185B) // আজকের plan — magenta
        : isPast
            ? Colors.grey.shade400 // পুরনো plan — grey
            : kPrimary; // ভবিষ্যতের plan — blue

    return Container(
      margin: const EdgeInsets.only(bottom: 10), // নিচে ফাঁকা জায়গা
      decoration: BoxDecoration(
        color: Colors.white, // সাদা card
        borderRadius: BorderRadius.circular(14), // গোলাকার কোণ
        // আজকের plan এ magenta border
        border: isToday
            ? Border.all(color: const Color(0xFFC2185B), width: 1.5)
            : null,
        // হালকা shadow
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        // ── বাম দিকে date column ──
        Container(
          width: 56, // fixed width
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            // accent রঙের হালকা background
            color: accent.withValues(alpha: 0.1),
            // শুধু বাম দিকে গোলাকার
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(14)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // দিনের সংখ্যা — যেমন "18"
            Text(DateFormat('dd').format(dt),
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 20, color: accent)),
            // মাসের নাম সংক্ষেপে — যেমন "JUN"
            Text(DateFormat('MMM').format(dt).toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accent.withValues(alpha: 0.8),
                    letterSpacing: 0.5)),
            // আজকের plan এ "TODAY" badge দেখাচ্ছি
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

        // ── মাঝখানে plan এর details ──
        Expanded(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Plan এর title
            Text(plan['title'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  // past plan এ grey রঙ
                  color: isPast && !isToday ? Colors.grey : Colors.black87,
                  // past plan এ strikethrough (কাটা দাগ)
                  decoration:
                      isPast && !isToday ? TextDecoration.lineThrough : null,
                )),

            // Time set থাকলে দেখাচ্ছি
            if (formattedTime != null) ...[
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                // ঘড়ির icon
                Icon(Icons.access_time_rounded,
                    size: 12, color: isPast && !isToday ? Colors.grey : accent),
                const SizedBox(width: 3),
                // formatted time — যেমন "2:30 PM"
                Text(formattedTime,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPast && !isToday ? Colors.grey : accent)),
              ]),
            ],

            // Description থাকলে দেখাচ্ছি
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey, height: 1.4)),
            ],
          ]),
        )),

        // ── ডান দিকে Edit এবং Delete buttons ──
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Edit button — tap করলে onEdit callback call হবে
          IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: kPrimary.withValues(alpha: 0.7)),
              onPressed: onEdit), // _update(plan) call হবে

          // Delete button — tap করলে onDelete callback call হবে
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.redAccent),
              onPressed: onDelete), // _delete(plan['id']) call হবে
        ]),
      ]),
    );
  }
}
