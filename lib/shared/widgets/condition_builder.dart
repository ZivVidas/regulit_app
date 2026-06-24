// Shared rich condition-tree editor.
//
// Used by:
//   * features/quizzes/quiz_numeric_engine_screen.dart (rule conditions)
//   * features/workflows/workflow_total_fine_pipeline_screen.dart
//                                            (Step 46 pipeline conditions)
//
// Wire JSON shape (forward-compatible with core/condition_eval.py):
//   leaf:   {"always": true}
//   leaf:   {"signal": "<name>"}
//   not:    {"not":    <node>}
//   group:  {"operator": "AND"|"OR", "terms": [<node>, ...]}
//
// Old conditions saved as {"operator":"AND|OR", "terms":[...]} still load
// fine — they're a strict subset of the new shape.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';

// ── Term-node data model ─────────────────────────────────────────
class TermNode {
  /// 'signal' | 'group' | 'not' | 'always'
  final String type;
  final String signalName; // when type == 'signal'
  final String operator;   // 'AND' | 'OR' when type == 'group'
  final List<TermNode> children; // when type == 'group' or 'not'

  const TermNode({
    required this.type,
    this.signalName = '',
    this.operator = 'AND',
    this.children = const [],
  });

  factory TermNode.always() => const TermNode(type: 'always');

  factory TermNode.signal(String name) =>
      TermNode(type: 'signal', signalName: name);

  factory TermNode.group({String op = 'AND', List<TermNode>? children}) =>
      TermNode(
        type: 'group',
        operator: op,
        children: children ?? [TermNode.always()],
      );

  factory TermNode.not(TermNode child) =>
      TermNode(type: 'not', children: [child]);

  factory TermNode.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('always')) return TermNode.always();
    if (json.containsKey('signal')) {
      return TermNode.signal(json['signal'] as String);
    }
    if (json.containsKey('not')) {
      return TermNode.not(
          TermNode.fromJson(json['not'] as Map<String, dynamic>));
    }
    final op = json['operator'] as String? ?? 'AND';
    final terms = (json['terms'] as List? ?? [])
        .map((t) => TermNode.fromJson(t as Map<String, dynamic>))
        .toList();
    return TermNode(type: 'group', operator: op, children: terms);
  }

  Map<String, dynamic> toJson() {
    switch (type) {
      case 'always':
        return {'always': true};
      case 'signal':
        return {'signal': signalName};
      case 'not':
        return {'not': children.first.toJson()};
      default: // group
        return {
          'operator': operator,
          'terms': children.map((c) => c.toJson()).toList(),
        };
    }
  }

  TermNode copyWith({
    String? type,
    String? signalName,
    String? operator,
    List<TermNode>? children,
  }) =>
      TermNode(
        type: type ?? this.type,
        signalName: signalName ?? this.signalName,
        operator: operator ?? this.operator,
        children: children ?? this.children,
      );
}

// ── Recursive widget — renders one node + its descendants ──────
class ConditionBuilder extends StatelessWidget {
  final TermNode node;
  /// Each entry must have a 'signalName' key (extra keys ignored). Same
  /// shape the existing workflow_signals + quiz_signals endpoints return.
  final List<Map<String, dynamic>> signals;
  final int depth;
  final void Function(TermNode) onChanged;
  /// Color used by the AND/OR toggle when selected (matches the host
  /// screen's primary color so the editor feels native).
  final Color primaryColor;

  const ConditionBuilder({
    super.key,
    required this.node,
    required this.signals,
    required this.onChanged,
    this.depth = 0,
    this.primaryColor = const Color(0xFF2563EB),
  });

  static const _depthColors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
  ];

  Color get _color => _depthColors[depth % _depthColors.length];

  @override
  Widget build(BuildContext context) {
    return switch (node.type) {
      'always' => _buildAlways(context),
      'signal' => _buildSignalLeaf(context),
      'not' => _buildNot(context),
      _ => _buildGroup(context),
    };
  }

  List<PopupMenuEntry<String>> get _typeMenuItems => const [
        PopupMenuItem(
            value: 'always',
            child: Row(children: [
              Icon(Icons.all_inclusive_rounded, size: 16),
              Gap(8),
              Text('Always (matches all)'),
            ])),
        PopupMenuItem(
            value: 'signal',
            child: Row(children: [
              Icon(Icons.sensors_rounded, size: 16),
              Gap(8),
              Text('Signal'),
            ])),
        PopupMenuItem(
            value: 'group',
            child: Row(children: [
              Icon(Icons.account_tree_rounded, size: 16),
              Gap(8),
              Text('Group (AND / OR)'),
            ])),
        PopupMenuItem(
            value: 'not',
            child: Row(children: [
              Icon(Icons.block_rounded, size: 16),
              Gap(8),
              Text('NOT'),
            ])),
      ];

  void _handleTypeSelect(String value) {
    switch (value) {
      case 'always':
        onChanged(TermNode.always());
      case 'signal':
        onChanged(TermNode.signal(
            signals.isNotEmpty ? signals.first['signalName'] as String : ''));
      case 'group':
        onChanged(TermNode.group());
      case 'not':
        onChanged(TermNode.not(TermNode.always()));
    }
  }

  Widget _buildAlways(BuildContext context) {
    return Row(children: [
      _NodeTypeButton(
        label: 'ALWAYS',
        color: Colors.grey,
        items: _typeMenuItems,
        onSelected: _handleTypeSelect,
      ),
    ]);
  }

  Widget _buildSignalLeaf(BuildContext context) {
    final signalNames = signals.map((s) => s['signalName'] as String).toList();
    final currentName =
        signalNames.contains(node.signalName) ? node.signalName : null;
    return Row(children: [
      _NodeTypeButton(
        label: 'SIGNAL',
        color: _color,
        items: _typeMenuItems,
        onSelected: _handleTypeSelect,
      ),
      const Gap(6),
      Expanded(
        child: DropdownButton<String>(
          value: currentName,
          isExpanded: true,
          hint: const Text('Select signal'),
          isDense: true,
          items: signalNames
              .map((n) => DropdownMenuItem(
                  value: n, child: Text(n, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (v) => onChanged(node.copyWith(signalName: v ?? '')),
        ),
      ),
    ]);
  }

  Widget _buildNot(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _NodeTypeButton(
          label: 'NOT',
          color: AppColors.danger,
          items: _typeMenuItems,
          onSelected: _handleTypeSelect,
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 16, top: 6),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.3), width: 2)),
          ),
          padding: const EdgeInsets.only(left: 10),
          child: ConditionBuilder(
            node: node.children.first,
            signals: signals,
            depth: depth + 1,
            primaryColor: primaryColor,
            onChanged: (child) =>
                onChanged(node.copyWith(children: [child])),
          ),
        ),
      ),
    ]);
  }

  Widget _buildGroup(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _NodeTypeButton(
          label: 'GROUP',
          color: _color,
          items: _typeMenuItems,
          onSelected: _handleTypeSelect,
        ),
        const Gap(6),
        _OperatorToggle(
          value: node.operator,
          primaryColor: primaryColor,
          onChanged: (op) => onChanged(node.copyWith(operator: op)),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => onChanged(node.copyWith(
            children: [...node.children, TermNode.always()],
          )),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: const Text('Add term', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: _color,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]),
      const Gap(4),
      ...node.children.asMap().entries.map((e) {
        final i = e.key;
        final child = e.value;
        return Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: _color.withValues(alpha: 0.3), width: 2)),
            ),
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ConditionBuilder(
                    node: child,
                    signals: signals,
                    depth: depth + 1,
                    primaryColor: primaryColor,
                    onChanged: (updated) {
                      final newChildren = [...node.children];
                      newChildren[i] = updated;
                      onChanged(node.copyWith(children: newChildren));
                    },
                  ),
                ),
                if (node.children.length > 1)
                  GestureDetector(
                    onTap: () {
                      final newChildren = [...node.children]..removeAt(i);
                      onChanged(node.copyWith(children: newChildren));
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: Colors.grey[400]),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    ]);
  }
}

// ── AND/OR toggle ────────────────────────────────────────────────
class _OperatorToggle extends StatelessWidget {
  final String value;
  final Color primaryColor;
  final void Function(String) onChanged;

  const _OperatorToggle({
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['AND', 'OR'].map((op) {
        final selected = value == op;
        return GestureDetector(
          onTap: () => onChanged(op),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? primaryColor : Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              op,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── "Change node type" pill button ───────────────────────────────
class _NodeTypeButton extends StatelessWidget {
  final String label;
  final Color color;
  final List<PopupMenuEntry<String>> items;
  final void Function(String) onSelected;

  const _NodeTypeButton({
    required this.label,
    required this.color,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      tooltip: 'Change type',
      itemBuilder: (_) => items,
      offset: const Offset(0, 28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const Gap(4),
          Icon(Icons.arrow_drop_down_rounded, size: 14, color: color),
        ]),
      ),
    );
  }
}
