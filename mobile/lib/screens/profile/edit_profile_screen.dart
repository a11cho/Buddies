import 'package:flutter/material.dart';

import '../../core/service_registry.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../widgets/app_scaffold.dart';
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
  final TextEditingController _nameController = TextEditingController();
  late Future<User> _userFuture;
  String? _profileImageUrl;
  bool _isSubmitting = false;
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
      body: FutureBuilder<User>(
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
              Center(
                child: Column(
                  children: [
                    ProfileAvatar(
                      name: _nameController.text,
                      profileImageUrl: _profileImageUrl,
                      radius: 44,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _chooseProfilePhoto,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose Photo'),
                    ),
                    if (_profileImageUrl != null) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () {
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
              const SizedBox(height: 24),
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
          );
        },
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
    // 실제 사진첩 API 연결 전까지는 mock 이미지 값을 선택하는 방식으로 대체합니다.
    final selectedProfile = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final option in _profilePhotoOptions)
                ListTile(
                  leading: CircleAvatar(backgroundColor: option.color),
                  title: Text(option.label),
                  trailing: _profileImageUrl == option.value
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.pop(context, option.value);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (selectedProfile == null) {
      return;
    }

    setState(() {
      _profileImageUrl = selectedProfile;
    });
  }
}

const List<_ProfilePhotoOption> _profilePhotoOptions = [
  _ProfilePhotoOption(
    label: 'Blue Profile',
    value: 'mock://profile/blue',
    color: Color(0xFF2563EB),
  ),
  _ProfilePhotoOption(
    label: 'Green Profile',
    value: 'mock://profile/green',
    color: Color(0xFF059669),
  ),
  _ProfilePhotoOption(
    label: 'Rose Profile',
    value: 'mock://profile/rose',
    color: Color(0xFFE11D48),
  ),
  _ProfilePhotoOption(
    label: 'Yellow Profile',
    value: 'mock://profile/yellow',
    color: Color(0xFFCA8A04),
  ),
];

class _ProfilePhotoOption {
  const _ProfilePhotoOption({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}
