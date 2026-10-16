import 'package:flutter/material.dart';

import '../main.dart';
import '../utils/app_colors.dart';
import '../utils/pop_notification.dart';
import '../widgets/upload_image_sheet.dart';

/// Edit the profile: photo, name and phone.
/// Closes with Navigator.pop(context, true) after saving.
class EditProfileScreen extends StatefulWidget {
  static const routeName = '/edit-profile';
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _email = '';
  String _avatarUrl = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      _nameController.text = (profile?['name'] ?? '').toString();
      _phoneController.text = (profile?['phone'] ?? '').toString();
      _avatarUrl = (profile?['avatar_url'] ?? '').toString();
      _email = user.email ?? '';
    } catch (e) {
      debugPrint('Edit profile load error: $e');
      if (mounted) Pop.error(context, 'Could not load your profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Camera or gallery, then upload to the "avatars" bucket.
  Future<void> _pickPhoto() async {
    setState(() => _uploading = true);
    final String? url = await UploadImageSheet.show(context, prefix: 'avatar', maxWidth: 600);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _avatarUrl = url;
    });
    if (url != null) Pop.info(context, 'Photo uploaded. Tap Save to keep it.');
  }

  Future<void> _save() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().length < 2) {
      Pop.error(context, 'Please enter your name');
      return;
    }

    setState(() => _saving = true);
    try {
      await supabase.from('profiles').update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'avatar_url': _avatarUrl.isEmpty ? null : _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;
      Pop.success(context, 'Profile updated successfully');
      Navigator.pop(context, true); // tell the account screen to reload
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) Pop.error(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 5),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: _photo()),
                        const SizedBox(height: 24),
                        _label('Name'),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(hintText: 'Your name'),
                        ),
                        const SizedBox(height: 16),
                        _label('Phone'),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(hintText: 'Your phone number'),
                        ),
                        const SizedBox(height: 16),
                        _label('Email'),
                        TextFormField(
                          initialValue: _email,
                          readOnly: true, // the email is the login, so it cannot change
                          decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.lock_outline, size: 18),
                          ),
                          style: const TextStyle(color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                ),
                // Save button stays at the bottom (hidden while typing)
                if (!keyboardOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SafeArea(
                      top: false,
                      child: ElevatedButton(
                        onPressed: (_saving || _uploading) ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  /// Round photo with a small camera button.
  Widget _photo() {
    return GestureDetector(
      onTap: _uploading ? null : _pickPhoto,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.card,
            backgroundImage: _avatarUrl.isNotEmpty
                ? NetworkImage(_avatarUrl)
                : const AssetImage('assets/images/blank.png') as ImageProvider,
            child: _uploading ? const CircularProgressIndicator() : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
      );
}
