/// Audit Pack screen — the clientAdmin's workflow filling hub.
/// Shows all workflows linked to the current customer, with
/// "Start New Fill" and "Edit Last" buttons per workflow card.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../l10n/app_localizations.dart';

// ── Palette — Kinetic Corporate tokens ────────────────────────
const _kGrad1    = AppColors.blueDark;    // #005A9E deep azure
const _kGrad2    = AppColors.blue;        // #0078D4 azure blue
const _kAccent   = AppColors.success;     // #107C10 active green
const _kAccentBg = AppColors.successLight;// #DFF6DD
const _kBg       = AppColors.background; // #F3F2F1 Office Gray
const _kCardBg   = AppColors.white;
const _kMuted    = AppColors.muted;       // #605E5C
const _kSub      = AppColors.muted;
const _kText     = AppColors.text;        // #201F1E Onyx Black
const _kEditClr  = AppColors.blue;        // #0078D4
const _kEditBg   = AppColors.infoLight;  // #DEECF9

// ── Session summary model ──────────────────────────────────────
class _Session {
  final String id;
  final String workflowId;
  final int answeredCount;
  final DateTime dateModified;
  final DateTime dateCreated;
  final bool isActive;

  const _Session({
    required this.id,
    required this.workflowId,
    required this.answeredCount,
    required this.dateModified,
    required this.dateCreated,
    this.isActive = false,
  });

  _Session copyWith({bool? isActive}) => _Session(
        id:            id,
        workflowId:    workflowId,
        answeredCount: answeredCount,
        dateModified:  dateModified,
        dateCreated:   dateCreated,
        isActive:      isActive ?? this.isActive,
      );

  factory _Session.fromJson(Map<String, dynamic> j) => _Session(
        id:            j['id'] as String,
        workflowId:    j['workflowId'] as String,
        answeredCount: (j['answeredCount'] as num?)?.toInt() ?? 0,
        dateModified:  DateTime.tryParse(j['dateModified'] as String? ?? '') ??
            DateTime.now(),
        dateCreated:   DateTime.tryParse(j['datedCreated'] as String? ?? '') ??
            DateTime.now(),
        isActive:      j['isActive'] as bool? ?? false,
      );
}

// ── State ─────────────────────────────────────────────────────
class _AuditState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> workflows;
  /// workflowId → list of sessions (most-recent first)
  final Map<String, List<_Session>> sessions;
  /// workflowIds currently starting a new session
  final Set<String> starting;

  const _AuditState({
    this.isLoading = true,
    this.error,
    this.workflows = const [],
    this.sessions  = const {},
    this.starting  = const {},
  });

  _AuditState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? workflows,
    Map<String, List<_Session>>? sessions,
    Set<String>? starting,
  }) =>
      _AuditState(
        isLoading: isLoading ?? this.isLoading,
        error:     error,
        workflows: workflows ?? this.workflows,
        sessions:  sessions  ?? this.sessions,
        starting:  starting  ?? this.starting,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class _AuditNotifier extends StateNotifier<_AuditState> {
  final Dio _dio;
  final String customerId;

  _AuditNotifier(this._dio, this.customerId) : super(const _AuditState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Parallel fetch: workflows + existing sessions
      final results = await Future.wait([
        _dio.get<List<dynamic>>('/customers/$customerId/workflows'),
        _dio.get<List<dynamic>>('/workflow-answers/by-customer/$customerId'),
      ]);

      final workflows = (results[0].data ?? []).cast<Map<String, dynamic>>();

      // Group sessions by workflowId
      final rawSessions = (results[1].data ?? []).cast<Map<String, dynamic>>();
      final Map<String, List<_Session>> grouped = {};
      for (final j in rawSessions) {
        final s = _Session.fromJson(j);
        grouped.putIfAbsent(s.workflowId, () => []).add(s);
      }
      // Each list is already sorted desc by dateModified from the API
      for (final list in grouped.values) {
        list.sort((a, b) => b.dateModified.compareTo(a.dateModified));
      }

      state = state.copyWith(
        isLoading: false,
        workflows: workflows,
        sessions:  grouped,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> startSession(String workflowId) async {
    state = state.copyWith(
      starting: {...state.starting, workflowId},
      error: null,
    );
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/workflow-answers',
        data: {'workflowId': workflowId, 'customerId': customerId},
      );
      final sessionId = res.data!['id'] as String;

      // Optimistically add session to local state
      final newSession = _Session(
        id:            sessionId,
        workflowId:    workflowId,
        answeredCount: 0,
        dateModified:  DateTime.now(),
        dateCreated:   DateTime.now(),
      );
      final updated = Map<String, List<_Session>>.from(state.sessions);
      updated[workflowId] = [newSession, ...(updated[workflowId] ?? [])];

      state = state.copyWith(
        starting: state.starting.difference({workflowId}),
        sessions: updated,
      );
      return sessionId;
    } catch (e) {
      state = state.copyWith(
        starting: state.starting.difference({workflowId}),
        error:    e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  /// Set a session as active; deactivates all siblings on the server.
  Future<void> activate(String workflowId, String sessionId) async {
    try {
      await _dio.patch<dynamic>('/workflow-answers/$sessionId/activate');
      // Update local state optimistically
      final updated = Map<String, List<_Session>>.from(state.sessions);
      updated[workflowId] = (updated[workflowId] ?? [])
          .map((s) => s.copyWith(isActive: s.id == sessionId))
          .toList();
      state = state.copyWith(sessions: updated);
    } catch (e) {
      state = state.copyWith(error: e.toString().replaceFirst('Exception: ', ''));
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final _auditProvider = StateNotifierProvider.autoDispose
    .family<_AuditNotifier, _AuditState, String>(
  (ref, customerId) => _AuditNotifier(ref.watch(dioProvider), customerId),
);

// ── Screen ────────────────────────────────────────────────────
class AuditPackScreen extends ConsumerWidget {
  const AuditPackScreen({super.key, this.tenantId});
  final String? tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final customerCtx  = ref.watch(customerContextProvider);
    final customerId   = customerCtx?['customerId'] as String?;
    final customerName = customerCtx?['customerName'] as String? ?? l10n.auditYourOrganisation;

    if (customerId == null) return const _NoContextView();

    final s   = ref.watch(_auditProvider(customerId));
    final not = ref.read(_auditProvider(customerId).notifier);

    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: AppColors.blue,
        onRefresh: not.load,
        child: CustomScrollView(
          slivers: [
            // ── Fancy sliver header ─────────────────────────
            _SliverHeader(customerName: customerName),

            // ── Body ───────────────────────────────────────
            if (s.isLoading)
              const SliverFillRemaining(child: _LoadingView())
            else if (s.error != null && s.workflows.isEmpty)
              SliverFillRemaining(
                child: _ErrorView(message: s.error!, onRetry: not.load))
            else if (s.workflows.isEmpty)
              const SliverFillRemaining(child: _EmptyView())
            else ...[
              // Summary row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _SummaryRow(
                    workflows: s.workflows,
                    sessions:  s.sessions,
                  ),
                ),
              ),
              if (s.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _ErrorBanner(message: s.error!),
                  ),
                ),
              // Cards
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                sliver: SliverList.builder(
                  itemCount: s.workflows.length,
                  itemBuilder: (_, i) {
                    final wf    = s.workflows[i];
                    final wfId  = wf['workflowId'] as String? ?? '';
                    final slist = s.sessions[wfId] ?? [];
                    return _WorkflowCard(
                      wf:       wf,
                      index:    i,
                      sessions: slist,
                      starting: s.starting.contains(wfId),
                      onStartNew: () async {
                        final wfName = wf['workflowName'] as String? ?? 'Workflow';
                        final sid = await not.startSession(wfId);
                        if (sid != null && context.mounted) {
                          context.push(
                            Uri(path: '/workflow-answer/$sid',
                                queryParameters: {'workflowName': wfName})
                                .toString(),
                          );
                        }
                      },
                      onEditLast: slist.isEmpty ? null : () {
                        final sid    = slist.first.id;
                        final wfName = wf['workflowName'] as String? ?? 'Workflow';
                        context.push(
                          Uri(path: '/workflow-answer/$sid',
                              queryParameters: {'workflowName': wfName})
                              .toString(),
                        );
                      },
                      onViewHistory: slist.isEmpty ? null : () {
                        final wfName = wf['workflowName'] as String? ?? 'Workflow';
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _AnswerHistorySheet(
                            workflowName: wfName,
                            sessions: slist,
                            onActivate: (sid) => not.activate(wfId, sid),
                            onView: (sid) => context.push(
                              Uri(
                                path: '/workflow-answer/$sid',
                                queryParameters: {'workflowName': wfName},
                              ).toString(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sliver Header ─────────────────────────────────────────────
class _SliverHeader extends StatelessWidget {
  final String customerName;
  const _SliverHeader({required this.customerName});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // Gradient background with decorative circles
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.blueDark, AppColors.blue, AppColors.blueLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  right: -40,
                  top: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  bottom: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Icon badge
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const Gap(16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).auditPackTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const Gap(2),
                                  Row(
                                    children: [
                                      Icon(Icons.business_rounded,
                                          size: 12,
                                          color: Colors.white.withOpacity(0.6)),
                                      const Gap(4),
                                      Flexible(
                                        child: Text(
                                          customerName,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(20),
                        // Info banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield_outlined,
                                  color: Colors.white70, size: 16),
                              const Gap(10),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).auditPackSubtitle,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
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
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: -0.04, end: 0, duration: 400.ms),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final List<Map<String, dynamic>> workflows;
  final Map<String, List<_Session>> sessions;
  const _SummaryRow({required this.workflows, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final total    = workflows.length;
    final started  = workflows.where((wf) {
      final id = wf['workflowId'] as String? ?? '';
      return sessions.containsKey(id);
    }).length;
    final active   = workflows.where((wf) => wf['isActive'] as bool? ?? true).length;

    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Row(
        children: [
          _StatChip(
            label: '$total',
            sub: l10n.statAssigned,
            icon: Icons.list_alt_rounded,
            color: _kGrad2,
          ),
          const Gap(8),
          _StatChip(
            label: '$started',
            sub: l10n.statInProgress,
            icon: Icons.edit_rounded,
            color: _kEditClr,
          ),
          const Gap(8),
          _StatChip(
            label: '$active',
            sub: l10n.statActive,
            icon: Icons.check_circle_rounded,
            color: _kAccent,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  const _StatChip(
      {required this.label,
      required this.sub,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const Gap(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                Text(sub,
                    style:
                        const TextStyle(color: _kMuted, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Workflow Card ─────────────────────────────────────────────
class _WorkflowCard extends StatefulWidget {
  final Map<String, dynamic> wf;
  final int index;
  final List<_Session> sessions;
  final bool starting;
  final VoidCallback onStartNew;
  final VoidCallback? onEditLast;
  final VoidCallback? onViewHistory;

  const _WorkflowCard({
    required this.wf,
    required this.index,
    required this.sessions,
    required this.starting,
    required this.onStartNew,
    required this.onEditLast,
    this.onViewHistory,
  });

  @override
  State<_WorkflowCard> createState() => _WorkflowCardState();
}

class _WorkflowCardState extends State<_WorkflowCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final wf       = widget.wf;
    final name     = wf['workflowName'] as String? ?? '—';
    final desc     = wf['workflowDescription'] as String?;
    final isActive = wf['isActive'] as bool? ?? true;
    final hasSess  = widget.sessions.isNotEmpty;
    final lastSess = hasSess ? widget.sessions.first : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: 180.ms,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? AppColors.blue.withOpacity(0.3)
                : AppColors.border,
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? _kGrad2.withOpacity(0.1)
                  : Colors.black.withOpacity(0.04),
              blurRadius: _hovered ? 24 : 10,
              offset: Offset(0, _hovered ? 8 : 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top stripe ──────────────────────────────────
            _TopStripe(isActive: isActive, hasSess: hasSess),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title row ───────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WorkflowIcon(isActive: isActive),
                      const Gap(14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: _kText,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const Gap(8),
                                _StatusBadge(isActive: isActive),
                              ],
                            ),
                            if (desc != null && desc.isNotEmpty) ...[
                              const Gap(5),
                              Text(
                                desc,
                                style: const TextStyle(
                                  color: _kSub,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Session info ─────────────────────────
                  if (lastSess != null) ...[
                    const Gap(14),
                    _SessionInfo(session: lastSess),
                  ],

                  const Gap(16),

                  // ── Action buttons ───────────────────────
                  _ActionButtons(
                    isActive:      isActive,
                    starting:      widget.starting,
                    hasSess:       hasSess,
                    sessionCount:  widget.sessions.length,
                    onStartNew:    widget.onStartNew,
                    onEditLast:    widget.onEditLast,
                    onViewHistory: hasSess ? widget.onViewHistory : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: (widget.index * 70).ms, duration: 380.ms)
          .slideY(
              begin: 0.08,
              end: 0,
              delay: (widget.index * 70).ms,
              duration: 380.ms,
              curve: Curves.easeOutCubic),
    );
  }
}

// ── Top stripe ────────────────────────────────────────────────
class _TopStripe extends StatelessWidget {
  final bool isActive;
  final bool hasSess;
  const _TopStripe({required this.isActive, required this.hasSess});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(colors: [AppColors.blueDark, AppColors.blue, AppColors.blueLight])
            : const LinearGradient(
                colors: [AppColors.border, AppColors.surface]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

// ── Workflow Icon ─────────────────────────────────────────────
class _WorkflowIcon extends StatelessWidget {
  final bool isActive;
  const _WorkflowIcon({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [AppColors.infoLight, Color(0xFFBFDFF7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [AppColors.surface, AppColors.border]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.account_tree_rounded,
        color: isActive ? _kGrad1 : _kMuted,
        size: 24,
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? _kAccentBg : AppColors.dangerLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? _kAccent : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const Gap(5),
          Text(
            isActive
                ? AppLocalizations.of(context).statusActive
                : AppLocalizations.of(context).statusInactive,
            style: TextStyle(
              color: isActive ? _kAccent : AppColors.danger,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Session info bar ──────────────────────────────────────────
class _SessionInfo extends StatelessWidget {
  final _Session session;
  const _SessionInfo({required this.session});

  String _timeAgo(AppLocalizations l10n, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inHours < 1)   return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1)    return l10n.timeHoursAgo(diff.inHours);
    if (diff.inDays < 30)   return l10n.timeDaysAgo(diff.inDays);
    if (diff.inDays < 365)  return l10n.timeMonthsAgo((diff.inDays / 30).floor());
    return l10n.timeYearsAgo((diff.inDays / 365).floor());
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final count = session.answeredCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _kEditBg.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kEditClr.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 15, color: _kEditClr),
          const Gap(8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 12, color: _kSub, height: 1.3),
                children: [
                  TextSpan(
                    text: '${l10n.auditLastSession} · ',
                    style: const TextStyle(fontWeight: FontWeight.w600,
                        color: _kEditClr),
                  ),
                  TextSpan(
                    text: '${l10n.auditAnswerCount(count)} · ',
                  ),
                  TextSpan(text: _timeAgo(l10n, session.dateModified)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final bool isActive;
  final bool starting;
  final bool hasSess;
  final int sessionCount;
  final VoidCallback onStartNew;
  final VoidCallback? onEditLast;
  final VoidCallback? onViewHistory;

  const _ActionButtons({
    required this.isActive,
    required this.starting,
    required this.hasSess,
    required this.sessionCount,
    required this.onStartNew,
    required this.onEditLast,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return _InactiveButton();
    }

    if (!hasSess) {
      // No sessions yet — just a single prominent "Start" button
      return _StartButton(starting: starting, onTap: onStartNew, isFirst: true);
    }

    final l10n = AppLocalizations.of(context);

    // Has sessions — three buttons side by side
    return Row(
      children: [
        // Edit last (outline style)
        Expanded(
          child: _EditButton(onTap: onEditLast),
        ),
        const Gap(8),
        // Start new (filled)
        Expanded(
          child: _StartButton(starting: starting, onTap: onStartNew, isFirst: false),
        ),
        const Gap(8),
        // View answers history
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kSub,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: onViewHistory,
            icon: const Icon(Icons.history_rounded, size: 14),
            label: Text(
              l10n.viewAnswers(sessionCount),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _InactiveButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _kMuted,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        onPressed: null,
        icon: const Icon(Icons.block_rounded, size: 16),
        label: Text(l10n.workflowInactive,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool starting;
  final VoidCallback onTap;
  final bool isFirst; // true = first ever fill (larger, full width)

  const _StartButton(
      {required this.starting, required this.onTap, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: isFirst ? double.infinity : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: starting
              ? null
              : const LinearGradient(colors: [AppColors.blueDark, AppColors.blue]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: starting
              ? []
              : [
                  BoxShadow(
                    color: AppColors.blueDark.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          ),
          onPressed: starting ? null : onTap,
          icon: starting
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text(
            starting
                ? l10n.actionStarting
                : isFirst
                    ? l10n.actionStartFill
                    : l10n.actionNewFill,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: _kEditClr,
        side: BorderSide(color: _kEditClr.withOpacity(0.4), width: 1.5),
        backgroundColor: _kEditBg.withOpacity(0.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
      ),
      onPressed: onTap,
      icon: const Icon(Icons.edit_rounded, size: 16),
      label: Text(
        l10n.actionEditLast,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 16),
          const Gap(8),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Utility Views ─────────────────────────────────────────────
class _NoContextView extends StatelessWidget {
  const _NoContextView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _kMuted.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.business_outlined,
                  size: 48, color: _kMuted),
            ),
            const Gap(20),
            Text(
              AppLocalizations.of(context).noWorkspaceSelected,
              style: const TextStyle(
                  color: _kText, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Gap(6),
            Text(
              AppLocalizations.of(context).selectWorkspaceFirst,
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _kGrad2.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 56, color: AppColors.border),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 2200.ms,
                  curve: Curves.easeInOut),
          const Gap(24),
          Text(
            AppLocalizations.of(context).noWorkflowsAssigned,
            style: const TextStyle(
                color: _kText, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const Gap(8),
          Text(
            AppLocalizations.of(context).workflowsAssignedBy,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
            begin: const Offset(0.92, 0.92),
            duration: 380.ms,
            curve: Curves.easeOutBack);
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: _kGrad2,
              strokeWidth: 3,
              backgroundColor: _kGrad2.withOpacity(0.12),
            ),
          ),
          const Gap(16),
          Text(AppLocalizations.of(context).loadingWorkflows,
              style: const TextStyle(color: _kMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                  color: AppColors.dangerLight, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  size: 42, color: AppColors.danger),
            ),
            const Gap(18),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.danger, fontSize: 13)),
            const Gap(24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(AppLocalizations.of(context).tryAgain,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Answer History Bottom Sheet ───────────────────────────────────────────────

class _AnswerHistorySheet extends StatelessWidget {
  final String workflowName;
  final List<_Session> sessions;
  final Future<void> Function(String sessionId) onActivate;
  final void Function(String sessionId) onView;

  const _AnswerHistorySheet({
    required this.workflowName,
    required this.sessions,
    required this.onActivate,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle & header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Gap(14),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 20, color: _kGrad1),
                      const Gap(10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workflowName,
                              style: const TextStyle(
                                color: _kText,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Builder(builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return Text(
                                l10n.viewAnswers(sessions.length),
                                style: const TextStyle(
                                    color: _kMuted, fontSize: 12),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(14),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Session list ─────────────────────────────────
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                itemCount: sessions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 20),
                itemBuilder: (ctx, i) => _HistoryRow(
                  session: sessions[i],
                  onActivate: () async {
                    await onActivate(sessions[i].id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  onView: () {
                    Navigator.pop(ctx);
                    onView(sessions[i].id);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final _Session session;
  final Future<void> Function() onActivate;
  final VoidCallback onView;

  const _HistoryRow({
    required this.session,
    required this.onActivate,
    required this.onView,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _activating = false;

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s        = widget.session;
    final isActive = s.isActive;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Active indicator dot
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _kAccent : _kMuted,
          ),
        ),
        const Gap(12),

        // Date + answer count
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fmt(s.dateCreated),
                style: const TextStyle(
                  color: _kText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(2),
              Row(children: [
                Text(
                  AppLocalizations.of(context).auditAnswerCount(s.answeredCount),
                  style: const TextStyle(color: _kMuted, fontSize: 11),
                ),
                if (isActive) ...[
                  const Gap(6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kAccentBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      AppLocalizations.of(context).statusActive,
                      style: const TextStyle(
                        color: _kAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),

        // View button
        Builder(builder: (context) {
          final l10n = AppLocalizations.of(context);
          return TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: _kEditClr,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: widget.onView,
            icon: const Icon(Icons.visibility_rounded, size: 14),
            label: Text(l10n.view,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          );
        }),

        // Set Active button (hidden when already active)
        if (!isActive)
          _activating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kAccent),
                )
              : Builder(builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: _kAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      setState(() => _activating = true);
                      await widget.onActivate();
                      if (mounted) setState(() => _activating = false);
                    },
                    icon: const Icon(
                        Icons.check_circle_outline_rounded, size: 14),
                    label: Text(l10n.setActive,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  );
                }),
      ],
    );
  }
}
