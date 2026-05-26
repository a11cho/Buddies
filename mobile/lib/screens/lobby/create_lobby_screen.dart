import 'package:flutter/material.dart';

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
  final TextEditingController _deliveryZoneController = TextEditingController();
  final TextEditingController _minimumOrderAmountController =
      TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _deliveryZoneController.dispose();
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
          TextInputField(
            controller: _deliveryZoneController,
            label: 'Delivery Zone',
            hintText: 'N3',
            prefixIcon: Icons.place_outlined,
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
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
