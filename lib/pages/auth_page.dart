import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

final _emailRx = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

final _passwordRx = RegExp(r'^(?=.*[A-Z]).{6,}$');

final _studentRx = RegExp(r'^\d{16}$');

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true;

  bool _loading = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _confirmPassCtrl = TextEditingController();

  bool _obscure = true;

  final _nameCtrl = TextEditingController();
  final _sidCtrl = TextEditingController();
  DateTime? _dob;
  String? _dept;
  Uint8List? _avatarBytes;

  static const _depts = [
    'CSE',
    'BBA',
    'Architecture',
    'English',
    'Bangla',
    'Islamic Studies',
    'Civil Engineering',
    'EEE',
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nameCtrl.dispose();
    _sidCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final xf = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xf == null) return;
    final bytes = await xf.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        await _register();
      }
    } on AuthException catch (e) {
      _snack(e.message, error: true);
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) throw Exception('Enter full name');

    if (!_emailRx.hasMatch(_emailCtrl.text)) throw Exception('Invalid email');

    if (!_passwordRx.hasMatch(_passCtrl.text)) {
      throw Exception('Password: 6+ chars, 1 uppercase');
    }

    if (_passCtrl.text != _confirmPassCtrl.text) {
      throw Exception('Passwords do not match');
    }

    if (!_studentRx.hasMatch(_sidCtrl.text)) {
      throw Exception('Student ID must be 16 digits');
    }

    if (_dept == null) throw Exception('Select department');

    if (_dob == null) throw Exception('Select date of birth');

    String? avatarUrl;
    if (_avatarBytes != null) {
      final path = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('avatars').uploadBinary(path, _avatarBytes!,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true));
      avatarUrl = supabase.storage.from('avatars').getPublicUrl(path);
    }

    final response = await supabase.auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      data: {
        'full_name': _nameCtrl.text.trim(),
        'department': _dept!,
        'student_id': _sidCtrl.text.trim(),
        'date_of_birth': _dob!.toIso8601String().substring(0, 10),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      },
    );

    if (response.user?.identities?.isEmpty ?? false) {
      throw Exception('This email is already registered. Please login.');
    }

    _snack('Account created! Check your email to confirm.');
    setState(() => _isLogin = true);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded,
                      size: 40, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text('LU-Collab',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                const Text('Academic Resource & Mentoring Hub',
                    style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          _TabBtn(
                              label: 'Login',
                              selected: _isLogin,
                              onTap: () => setState(() => _isLogin = true)),
                          const SizedBox(width: 4),
                          _TabBtn(
                              label: 'Register',
                              selected: !_isLogin,
                              onTap: () => setState(() => _isLogin = false)),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      if (!_isLogin) ..._registerFields(),
                      _buildEmail(),
                      const SizedBox(height: 12),
                      _buildPassword(),
                      const SizedBox(height: 12),
                      if (!_isLogin) _buildConfirmPassword(),
                      const SizedBox(height: 16),
                      _loading
                          ? const Center(child: CircularProgressIndicator())
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF002D72),
                                    Color(0xFF0055BB),
                                    Color(0xFF0077DD)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: kPrimary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3)),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: Icon(
                                    _isLogin
                                        ? Icons.login_rounded
                                        : Icons.person_add_rounded,
                                    size: 18),
                                label: Text(
                                    _isLogin ? 'Sign In' : 'Create Account',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ),
                            ),
                    ]),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _isLogin
                    ? 'New here? Tap Register to create your account'
                    : 'Already have an account? Tap Login',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  List<Widget> _registerFields() => [
        Center(
          child: GestureDetector(
            onTap: _pickAvatar,
            child: Stack(children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFFF4F6FA),
                backgroundImage:
                    _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                child: _avatarBytes == null
                    ? Icon(Icons.person_outline,
                        color: Colors.grey.shade400, size: 36)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined,
                      size: 14, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
            child: Text('Profile Photo (optional)',
                style: TextStyle(fontSize: 11, color: Colors.grey))),
        const SizedBox(height: 16),
        _buildField(
            controller: _nameCtrl,
            label: 'Full Name',
            icon: Icons.person_outline),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1980),
              lastDate: DateTime.now(),
            );
            if (d != null) setState(() => _dob = d);
          },
          child: AbsorbPointer(
            child: TextField(
              controller: TextEditingController(
                  text: _dob == null
                      ? ''
                      : '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
              decoration: _fieldDecoration(
                  label: 'Date of Birth', icon: Icons.cake_outlined),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _dept,
          decoration: _fieldDecoration(
              label: 'Department', icon: Icons.school_outlined),
          items: _depts
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) => setState(() => _dept = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sidCtrl,
          keyboardType: TextInputType.number,
          maxLength: 16,
          decoration: _fieldDecoration(
            label: 'Student ID (16 digits)',
            icon: Icons.badge_outlined,
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
      ];

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) =>
      TextField(
        controller: controller,
        decoration: _fieldDecoration(label: label, icon: icon),
      );

  Widget _buildEmail() => TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration:
            _fieldDecoration(label: 'Email', icon: Icons.email_outlined),
      );

  Widget _buildPassword() => TextField(
        controller: _passCtrl,
        obscureText: _obscure,
        decoration: _fieldDecoration(
          label: 'Password',
          icon: Icons.lock_outline,
        ).copyWith(
          suffixIcon: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: Colors.grey),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );

  Widget _buildConfirmPassword() => TextField(
        controller: _confirmPassCtrl,
        obscureText: _obscure,
        decoration: _fieldDecoration(
          label: 'Confirm Password',
          icon: Icons.lock_outline,
        ),
      );

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
        filled: true,
        fillColor: const Color(0xFFF4F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? kPrimary : Colors.grey.shade500,
              )),
        ),
      ),
    );
  }
}
