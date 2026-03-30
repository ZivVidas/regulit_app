import 'package:flutter/material.dart';
import '../../app/theme.dart';

// TODO: Implement ai chat screen — see TECHNICAL_SPEC.md for full spec
class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key, this.tenantId});
  final String? tenantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ai chat screen')),
      body: Center(
        child: Text(
          'Ai chat screen\n— Coming soon —',
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
