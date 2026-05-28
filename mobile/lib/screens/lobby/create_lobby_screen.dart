import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/service_registry.dart';
import '../../services/lobby_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_input_field.dart';

// Lobby 생성 화면의 임시 뼈대입니다.
// Phase 2 component와 Phase 4 service가 준비되면 TextInputField와 mock service를 연결합니다.
class CreateLobbyScreen extends StatefulWidget {
  const CreateLobbyScreen({super.key});

  @override
  State<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends State<CreateLobbyScreen> {
  final TextEditingController _restaurantNameController =
      TextEditingController();
  final TextEditingController _minimumOrderAmountController =
      TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();
  String _selectedDeliveryZone = DeliveryZone.n3;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _minimumOrderAmountController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Create Lobby',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextInputField(
            controller: _restaurantNameController,
            label: 'Restaurant name',
            prefixIcon: Icons.restaurant_outlined,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedDeliveryZone,
            decoration: const InputDecoration(
              labelText: 'Delivery Zone',
              prefixIcon: Icon(Icons.place_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final zone in DeliveryZone.values)
                DropdownMenuItem(
                  value: zone,
                  child: Text(zone),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedDeliveryZone = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextInputField(
            controller: _minimumOrderAmountController,
            label: 'Minimum order amount',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.payments_outlined,
          ),
          const SizedBox(height: 12),
          TextInputField(
            controller: _deliveryFeeController,
            label: 'Delivery fee',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.delivery_dining_outlined,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Create Lobby',
            icon: Icons.add,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final minimumOrderAmount = int.tryParse(
      _minimumOrderAmountController.text.trim(),
    );
    final deliveryFee = int.tryParse(_deliveryFeeController.text.trim());

    if (_restaurantNameController.text.trim().isEmpty ||
        minimumOrderAmount == null ||
        minimumOrderAmount < 0 ||
        deliveryFee == null ||
        deliveryFee < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please check the form values.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AppServices.lobbyService.createLobby(
        CreateLobbyRequest(
          restaurantName: _restaurantNameController.text.trim(),
          deliveryZone: _selectedDeliveryZone,
          minimumOrderAmount: minimumOrderAmount,
          deliveryFee: deliveryFee,
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
}
