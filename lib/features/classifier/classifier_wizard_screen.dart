import 'package:flutter/material.dart';
import '../../app/theme.dart';

// TODO: Implement classifier wizard screen — see TECHNICAL_SPEC.md for full spec
class ClassifierWizardScreen extends StatelessWidget {
  const ClassifierWizardScreen({super.key, this.tenantId});
  final String? tenantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Classifier wizard screen')),
      body: Center(
        child: Text(
          'Classifier wizard screen\n— Coming soon —',
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
