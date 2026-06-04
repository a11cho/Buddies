import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../models/user.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/buddies_style.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/profile_avatar.dart';

// 내 정보를 보여주는 최소 Profile 화면입니다.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<User> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = AppServices.userService.getMe();
  }

  void _refreshProfile() {
    setState(() {
      _userFuture = AppServices.userService.getMe();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Profile',
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
                onRetry: _refreshProfile,
              );
            }

            final user = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BuddiesCard(child: _ProfileHeader(user: user)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final didUpdate = await Navigator.pushNamed(
                      context,
                      AppRoutes.editProfile,
                    );
                    if (didUpdate == true) {
                      _refreshProfile();
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Profile'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.paymentSettings);
                  },
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Payment Settings'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.orderHistory);
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Order History'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.help);
                  },
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    await AppServices.authService.logout();
                    await AppServices.tokenStorage.clearAccessToken();
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkAction,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(
          name: user.name,
          profileImageUrl: user.profileImageUrl,
          radius: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_outline,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Trust ${user.trustScore.toStringAsFixed(1)}',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
