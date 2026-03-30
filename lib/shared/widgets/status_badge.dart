import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/models/gap.dart';
import '../../core/models/task.dart';

/// Status pill widget for gap and task statuses
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Widget? dot;

  const StatusBadge._({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.dot,
  });

  // ── Gap Status ──────────────────────────────────────────────
  factory StatusBadge.gapStatus(GapStatus status) {
    final (bg, fg, label) = switch (status) {
      GapStatus.open         => (AppColors.infoLight,    AppColors.blue,    'Open'),
      GapStatus.inProgress   => (AppColors.orangeLight,  AppColors.orange,  'In Progress'),
      GapStatus.resolved     => (AppColors.successLight, AppColors.success, 'Resolved'),
      GapStatus.acceptedRisk => (AppColors.surface,      AppColors.muted,   'Accepted Risk'),
    };
    return StatusBadge._(
      label: label,
      backgroundColor: bg,
      textColor: fg,
      dot: _Dot(color: fg),
    );
  }

  // ── Task Status ─────────────────────────────────────────────
  factory StatusBadge.taskStatus(TaskStatus status) {
    final (bg, fg, label) = switch (status) {
      TaskStatus.open          => (AppColors.infoLight,    AppColors.blue,    'To Do'),
      TaskStatus.inProgress    => (AppColors.orangeLight,  AppColors.orange,  'In Progress'),
      TaskStatus.pendingReview => (AppColors.warningLight, AppColors.warning, 'Pending Review'),
      TaskStatus.approved      => (AppColors.successLight, AppColors.success, 'Approved'),
      TaskStatus.rejected      => (AppColors.dangerLight,  AppColors.danger,  'Rejected'),
      TaskStatus.overdue       => (AppColors.dangerLight,  AppColors.danger,  'Overdue'),
    };
    return StatusBadge._(
      label: label,
      backgroundColor: bg,
      textColor: fg,
      dot: _Dot(color: fg),
    );
  }

  // ── Severity ────────────────────────────────────────────────
  factory StatusBadge.severity(GapSeverity severity) {
    final (bg, fg, label) = switch (severity) {
      GapSeverity.critical => (AppColors.dangerLight,  AppColors.danger,  'Critical'),
      GapSeverity.high     => (AppColors.orangeLight,  AppColors.orange,  'High'),
      GapSeverity.medium   => (AppColors.warningLight, AppColors.warning, 'Medium'),
      GapSeverity.low      => (AppColors.successLight, AppColors.success, 'Low'),
    };
    return StatusBadge._(
      label: label,
      backgroundColor: bg,
      textColor: fg,
      dot: _Dot(color: fg),
    );
  }

  // ── Requirement type ─────────────────────────────────────────
  factory StatusBadge.requirementType(RequirementType type) {
    return switch (type) {
      RequirementType.required_ => StatusBadge._(
          label: 'Required',
          backgroundColor: AppColors.dangerLight,
          textColor: AppColors.danger,
        ),
      RequirementType.bestPractice => StatusBadge._(
          label: 'Best Practice',
          backgroundColor: AppColors.infoLight,
          textColor: AppColors.blue,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.pill_,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[dot!, const SizedBox(width: 4)],
          Text(
            label,
            style: AppTextStyles.tag.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
