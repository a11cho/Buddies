import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../models/faq_item.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/buddies_style.dart';
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
      appBarBackgroundColor: AppColors.background,
      body: BuddiesScreenBody(
        child: FutureBuilder<List<FaqItem>>(
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
                  BuddiesCard(
                    padding: EdgeInsets.zero,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      iconColor: AppColors.primaryBlue,
                      collapsedIconColor: AppColors.primaryBlue,
                      leading: const Icon(
                        Icons.help_outline,
                        color: AppColors.primaryBlue,
                      ),
                      title: Text(
                        faq.question,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      subtitle: Text(
                        faq.category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
      ),
    );
  }
}
