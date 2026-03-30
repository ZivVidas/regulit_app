import 'package:flutter/material.dart';
import '../../app/theme.dart';

// TODO: Implement evidence queue screen — see TECHNICAL_SPEC.md for full spec
class EvidenceQueueScreen extends StatelessWidget {
  const EvidenceQueueScreen({super.key, this.tenantId});
  final String? tenantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Evidence queue screen')),
      body: Center(
        child: Text(
          'Evidence queue screen\n— Coming soon —',
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
