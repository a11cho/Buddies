import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../models/faq_item.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/loading_view.dart';

// FAQ 목록 화면입니다.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late Future<List<FaqItem>> _faqsFuture;

  @override
  void initState() {
    super.initState();
    _faqsFuture = AppServices.helpService.getFaqs();
  }

  void _refreshFaqs() {
    setState(() {
      _faqsFuture = AppServices.helpService.getFaqs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Help',
      body: FutureBuilder<List<FaqItem>>(
        future: _faqsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading FAQs...');
          }
          if (snapshot.hasError) {
            return ErrorMessageView(
              message: 'FAQ를 불러오지 못했습니다.',
              onRetry: _refreshFaqs,
            );
          }

          final faqs = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.supportTicket);
                },
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text('Direct Contact'),
              ),
              const SizedBox(height: 16),
              for (final faq in faqs)
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(faq.question),
                    subtitle: Text(faq.category),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(faq.answer),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
