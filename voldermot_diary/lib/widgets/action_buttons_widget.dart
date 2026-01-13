import 'package:flutter/material.dart';

class ActionButtonsWidget extends StatelessWidget {
  final VoidCallback onCreateNewPage;
  final VoidCallback onJoinLatest;

  const ActionButtonsWidget({
    super.key,
    required this.onCreateNewPage,
    required this.onJoinLatest,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onCreateNewPage,
            icon: const Icon(Icons.add),
            label: const Text('Create New Page'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onJoinLatest,
            icon: const Icon(Icons.access_time),
            label: const Text('Join Latest'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: Colors.green,
            ),
          ),
        ),
      ],
    );
  }
}
