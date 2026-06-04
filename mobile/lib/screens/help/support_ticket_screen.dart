import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/service_registry.dart';
import '../../models/lobby.dart';
import '../../services/help_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/buddies_style.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_input_field.dart';

const _noLobbyValue = -1;

// POST /support/tickets에 대응하는 문의 작성 화면입니다.
class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _category = SupportTicketCategory.payment;
  int? _selectedLobbyId;
  late Future<List<_LobbyOption>> _lobbyOptionsFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _lobbyOptionsFuture = _loadLobbyOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<List<_LobbyOption>> _loadLobbyOptions() async {
    final currentUser = await AppServices.userService.getMe();
    final lobbies = await AppServices.lobbyService.getMyLobbies();
    final options = lobbies
        .where(
          (lobby) => lobby.members.any(
            (member) => member.userId == currentUser.id,
          ),
        )
        .map(_LobbyOption.fromLobby)
        .toList();

    options.sort((left, right) => right.lobbyId.compareTo(left.lobbyId));
    return options;
  }

  void _refreshLobbyOptions() {
    setState(() {
      _lobbyOptionsFuture = _loadLobbyOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Direct Contact',
      appBarBackgroundColor: AppColors.background,
      body: BuddiesScreenBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BuddiesCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: SupportTicketCategory.payment,
                        child: Text('Payment'),
                      ),
                      DropdownMenuItem<String>(
                        value: SupportTicketCategory.account,
                        child: Text('Account'),
                      ),
                      DropdownMenuItem<String>(
                        value: SupportTicketCategory.lobby,
                        child: Text('Lobby'),
                      ),
                      DropdownMenuItem<String>(
                        value: SupportTicketCategory.other,
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _category = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextInputField(
                    controller: _titleController,
                    label: 'Title',
                    prefixIcon: Icons.title,
                  ),
                  const SizedBox(height: 12),
                  TextInputField(
                    controller: _bodyController,
                    label: 'Body',
                    maxLines: 5,
                    prefixIcon: Icons.notes_outlined,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<_LobbyOption>>(
                    future: _lobbyOptionsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Related Lobby',
                            prefixIcon: Icon(Icons.tag),
                          ),
                          child: Text('Loading lobbies...'),
                        );
                      }
                      if (snapshot.hasError) {
                        return OutlinedButton.icon(
                          onPressed: _refreshLobbyOptions,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reload Lobby list'),
                        );
                      }

                      final options = snapshot.data!;
                      final selectedValue = _selectedLobbyId == null ||
                              !options.any(
                                (option) => option.lobbyId == _selectedLobbyId,
                              )
                          ? _noLobbyValue
                          : _selectedLobbyId!;

                      return DropdownButtonFormField<int>(
                        initialValue: selectedValue,
                        decoration: const InputDecoration(
                          labelText: 'Related Lobby',
                          prefixIcon: Icon(Icons.tag),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: _noLobbyValue,
                            child: Text('No related Lobby'),
                          ),
                          for (final option in options)
                            DropdownMenuItem<int>(
                              value: option.lobbyId,
                              child: Text(
                                option.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedLobbyId =
                                value == _noLobbyValue ? null : value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Submit ticket',
                    icon: Icons.send_outlined,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await AppServices.helpService.submitSupportTicket(
        SupportTicketRequest(
          category: _category,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          lobbyId: _selectedLobbyId,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support ticket submitted.')),
      );
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
}

class _LobbyOption {
  const _LobbyOption({
    required this.lobbyId,
    required this.label,
  });

  final int lobbyId;
  final String label;

  factory _LobbyOption.fromLobby(Lobby lobby) {
    return _LobbyOption(
      lobbyId: lobby.lobbyId,
      label: 'Lobby #${lobby.lobbyId} - ${lobby.restaurantName} '
          '(${lobby.orderStatus})',
    );
  }
}
