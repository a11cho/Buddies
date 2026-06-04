import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/service_registry.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/buddies_style.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/text_input_field.dart';

// PATCH /users/me에 대응하는 Profile 수정 화면입니다.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _maxImageBytes = 5 * 1024 * 1024;

  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  late Future<User> _userFuture;
  String? _profileImageUrl;
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  bool _loadedInitialValues = false;

  @override
  void initState() {
    super.initState();
    _userFuture = AppServices.userService.getMe();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _loadInitialValues(User user) {
    if (_loadedInitialValues) {
      return;
    }
    _nameController.text = user.name;
    _profileImageUrl = user.profileImageUrl;
    _loadedInitialValues = true;
  }

  void _refreshUser() {
    setState(() {
      _userFuture = AppServices.userService.getMe();
      _loadedInitialValues = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Edit Profile',
      appBarBackgroundColor: AppColors.background,
      body: BuddiesScreenBody(
        child: FutureBuilder<User>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading profile...');
            }
            if (snapshot.hasError) {
              return ErrorMessageView(
                message: 'Profile 정보를 불러오지 못했습니다.',
                onRetry: _refreshUser,
              );
            }

            _loadInitialValues(snapshot.data!);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BuddiesCard(
                  child: Center(
                    child: Column(
                      children: [
                        ProfileAvatar(
                          name: _nameController.text,
                          profileImageUrl: _profileImageUrl,
                          radius: 44,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isSubmitting || _isUploadingPhoto
                              ? null
                              : _chooseProfilePhoto,
                          icon: _isUploadingPhoto
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _isUploadingPhoto ? 'Uploading...' : 'Choose Photo',
                          ),
                        ),
                        if (_profileImageUrl != null) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: _isSubmitting || _isUploadingPhoto
                                ? null
                                : () {
                                    setState(() {
                                      _profileImageUrl = null;
                                    });
                                  },
                            icon: const Icon(Icons.close),
                            label: const Text('Remove Photo'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                BuddiesCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextInputField(
                        controller: _nameController,
                        label: 'Name',
                        prefixIcon: Icons.badge_outlined,
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Save profile',
                        icon: Icons.save_outlined,
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AppServices.userService.updateMe(
        UpdateProfileRequest(
          name: name,
          profileImageUrl: _profileImageUrl,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _chooseProfilePhoto() async {
    final source = await _chooseImageSource();
    if (source == null || !mounted) {
      return;
    }

    final pickedImage = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (pickedImage == null || !mounted) {
      return;
    }

    final attachment = await _attachmentFromPickedImage(pickedImage);
    if (attachment == null || !mounted) {
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final mediaUrl = await AppServices.userService.uploadProfileImage(
        attachment,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profileImageUrl = mediaUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded. Save to apply it.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (context) {
        return BuddiesStyleScope(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile photo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.softBlue,
                      foregroundColor: AppColors.primaryBlue,
                      child: Icon(Icons.photo_library_outlined),
                    ),
                    title: const Text('Photo Library'),
                    onTap: () {
                      Navigator.pop(context, ImageSource.gallery);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.softBlue,
                      foregroundColor: AppColors.primaryBlue,
                      child: Icon(Icons.photo_camera_outlined),
                    ),
                    title: const Text('Camera'),
                    onTap: () {
                      Navigator.pop(context, ImageSource.camera);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<ProfileImageAttachment?> _attachmentFromPickedImage(
    XFile image,
  ) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be 5 MB or smaller.')),
        );
      }
      return null;
    }

    final contentType = image.mimeType ?? _inferImageContentType(image.name);
    if (contentType == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPEG, PNG, GIF, or WebP images are supported.'),
          ),
        );
      }
      return null;
    }

    return ProfileImageAttachment(
      filename: image.name.isEmpty ? 'profile-image.jpg' : image.name,
      contentType: contentType,
      bytes: bytes,
    );
  }

  String? _inferImageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return null;
  }
}
