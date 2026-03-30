import 'package:flutter/material.dart';
import '../../app/theme.dart';

// TODO: Implement gap analysis screen — see TECHNICAL_SPEC.md for full spec
class GapAnalysisScreen extends StatelessWidget {
  const GapAnalysisScreen({super.key, this.tenantId});
  final String? tenantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gap analysis screen')),
      body: Center(
        child: Text(
          'Gap analysis screen\n— Coming soon —',
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
