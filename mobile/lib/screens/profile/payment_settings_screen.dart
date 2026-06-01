import 'package:flutter/material.dart';

import '../../core/service_registry.dart';
import '../../models/host_payment_info.dart';
import '../../services/user_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_input_field.dart';

// GET/PATCH /auth/me/payment-info에 대응하는 계좌 정보 설정 화면입니다.
class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _accountHolderNameController =
      TextEditingController();
  late Future<HostPaymentInfo?> _paymentInfoFuture;
  bool _loadedInitialValues = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _paymentInfoFuture = AppServices.userService.getPaymentInfo();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderNameController.dispose();
    super.dispose();
  }

  void _loadInitialValues(HostPaymentInfo? paymentInfo) {
    if (_loadedInitialValues) {
      return;
    }
    _bankNameController.text = paymentInfo?.bankName ?? '';
    _accountNumberController.text = paymentInfo?.accountNumber ?? '';
    _accountHolderNameController.text =
        paymentInfo?.accountHolderName ?? '';
    _loadedInitialValues = true;
  }

  void _refreshPaymentInfo() {
    setState(() {
      _paymentInfoFuture = AppServices.userService.getPaymentInfo();
      _loadedInitialValues = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Payment Settings',
      body: FutureBuilder<HostPaymentInfo?>(
        future: _paymentInfoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading payment info...');
          }
          if (snapshot.hasError) {
            return ErrorMessageView(
              message: 'Payment 정보를 불러오지 못했습니다.',
              onRetry: _refreshPaymentInfo,
            );
          }

          _loadInitialValues(snapshot.data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextInputField(
                controller: _bankNameController,
                label: 'Bank name',
                hintText: 'KakaoBank',
                prefixIcon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: 12),
              TextInputField(
                controller: _accountNumberController,
                label: 'Account number',
                hintText: '3333-12-1234567',
                keyboardType: TextInputType.text,
                prefixIcon: Icons.numbers_outlined,
              ),
              const SizedBox(height: 12),
              TextInputField(
                controller: _accountHolderNameController,
                label: 'Account holder name',
                hintText: 'Example User',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Save Payment Info',
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
    final bankName = _bankNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountHolderName = _accountHolderNameController.text.trim();
    if (bankName.isEmpty ||
        accountNumber.isEmpty ||
        accountHolderName.isEmpty) {
      _showSnackBar('All payment fields are required.');
      return;
    }
    if (!_isValidAccountNumber(accountNumber)) {
      _showSnackBar('Account number can contain only digits and hyphens.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AppServices.userService.updatePaymentInfo(
        UpdatePaymentInfoRequest(
          bankName: bankName,
          accountNumber: accountNumber,
          accountHolderName: accountHolderName,
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
      _showSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _isValidAccountNumber(String value) {
    final digitsOnly = value.replaceAll('-', '');
    return RegExp(r'^[0-9-]+$').hasMatch(value) && digitsOnly.length >= 6;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
