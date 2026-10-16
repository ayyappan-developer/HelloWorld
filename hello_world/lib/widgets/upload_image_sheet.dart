import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../utils/app_colors.dart';
import '../utils/pop_notification.dart';

/// Bottom sheet: "Take a photo" or "Choose from gallery", then uploads it
/// to Supabase Storage and returns the public URL (null when cancelled / failed).
///
///   final String? url = await UploadImageSheet.show(context);
///   if (url != null) setState(() => _avatarUrl = url);
///
/// Files go to `bucket/userId/prefix_time.ext`, so the storage
/// policy in setup.sql lets each user write only inside their own folder.
class UploadImageSheet {
  static Future<String?> show(
    BuildContext context, {
    String bucket = 'avatars',
    String prefix = 'image',
    double maxWidth = 1080,
  }) async {
    // 1. Camera or gallery?
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Choose Image',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _option(sheetContext, Icons.photo_camera_outlined, 'Camera', ImageSource.camera),
                  const SizedBox(width: 12),
                  _option(sheetContext, Icons.photo_library_outlined, 'Gallery', ImageSource.gallery),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !context.mounted) return null; // sheet closed

    // 2. Pick the image
    final XFile? image;
    try {
      image = await ImagePicker().pickImage(source: source, maxWidth: maxWidth, imageQuality: 80);
    } catch (e) {
      debugPrint('Pick image error: $e');
      if (context.mounted) Pop.error(context, 'Could not open the ${source.name}.');
      return null;
    }
    if (image == null || !context.mounted) return null; // user went back

    // 3. Upload it, with a small "Uploading..." dialog
    return _upload(context, image, bucket, prefix);
  }

  static Widget _option(BuildContext context, IconData icon, String label, ImageSource source) {
    return Expanded(
      child: InkWell(
        onTap: () => Navigator.pop(context, source),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Icon(icon, size: 32, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ],
          ),
        ),
      ),
    );
  }

  static Future<String?> _upload(BuildContext context, XFile image, String bucket, String prefix) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );

    String? url;
    try {
      final bytes = await image.readAsBytes();
      final String extension = image.name.contains('.') ? image.name.split('.').last.toLowerCase() : 'jpg';
      final String path = '${user.id}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await supabase.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: image.mimeType ?? 'image/$extension'),
          );
      url = supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('Upload error: $e');
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // close "Uploading..."
      if (url == null) Pop.error(context, 'Could not upload the photo.');
    }
    return url;
  }
}
