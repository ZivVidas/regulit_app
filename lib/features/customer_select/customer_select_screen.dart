import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../l10n/app_localizations.dart';

/// Full-screen workspace picker shown after login for client-side users.
///
/// • Auto-selects and skips if the user belongs to exactly 1 customer.
/// • Shows a card grid when linked to 2+ customers.
/// • Shows an empty state if not linked to any customer.
class CustomerSelectScreen extends ConsumerWidget {
  const CustomerSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(userLinkedCustomersProvider);
    final user = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(l10n.failedLoadWorkspaces, style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: AppTextStyles.body.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(userLinkedCustomersProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (customers) {
          // ── Auto-select when user belongs to exactly 1 customer ──
          if (customers.length == 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(customerContextProvider.notifier).state = customers[0];
            });
            return const Center(child: CircularProgressIndicator());
          }

          return SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.blue, AppColors.blueLight],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + brand
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo_without_name.png',
                            width: 36,
                            height: 36,
                            filterQuality: FilterQuality.high,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'ReguLit',
                            style: AppTextStyles.h2
                                .copyWith(color: AppColors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.selectWorkspace,
                        style:
                            AppTextStyles.h1.copyWith(color: AppColors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.hiChooseWorkspace(user?.name ?? ''),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.white.withOpacity(0.80),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Customer grid / empty state ─────────────────────
                Expanded(
                  child: customers.isEmpty
                      ? const _EmptyState()
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 320,
                              childAspectRatio: 1.6,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: customers.length,
                            itemBuilder: (context, i) => _CustomerCard(
                              data: customers[i],
                              onTap: () {
                                ref
                                    .read(customerContextProvider.notifier)
                                    .state = customers[i];
                              },
                            ),
                          ),
                        ),
                ),

                // ── Sign-out link at bottom ─────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(authStateProvider.notifier).logout(),
                    icon: const Icon(Icons.logout, size: 16),
                    label: Text(l10n.signOut),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Customer Card ─────────────────────────────────────────────
class _CustomerCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _CustomerCard({required this.data, required this.onTap});

  @override
  State<_CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<_CustomerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.data['customerName'] as String? ?? '';
    final role = widget.data['role'] as String? ?? '';
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? AppColors.orange : AppColors.border,
              width: _hovered ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? AppColors.orange.withOpacity(0.15)
                    : Colors.black.withOpacity(0.05),
                blurRadius: _hovered ? 18 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: avatar + arrow
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.blue.withOpacity(0.10),
                    child: Text(
                      initials,
                      style: AppTextStyles.h4
                          .copyWith(color: AppColors.blue),
                    ),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          _hovered ? AppColors.orange : AppColors.border,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: _hovered ? AppColors.white : AppColors.muted,
                    ),
                  ),
                ],
              ),

              // Bottom: name + role badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.h4,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      role,
                      style: AppTextStyles.tag
                          .copyWith(color: AppColors.blue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.business_outlined,
              size: 72, color: AppColors.border),
          const SizedBox(height: 20),
          Text(l10n.noWorkspacesFound, style: AppTextStyles.h3),
          const SizedBox(height: 10),
          Text(
            l10n.notLinkedToCustomer,
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
