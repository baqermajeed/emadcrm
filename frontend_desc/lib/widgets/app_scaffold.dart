import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.bottom,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: bottom,
        actions: [
          ...?actions,
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Center(
                child: Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => context.read<AuthController>().logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.primary.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.black.withValues(alpha: 0.55))),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.color = AppTheme.primary,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.black.withValues(alpha: 0.55), fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 22),
          ),
        ],
      ),
    );
  }
}
