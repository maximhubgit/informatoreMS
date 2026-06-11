import 'package:flutter/material.dart';

/// Schermata Report (placeholder)
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          'Report - In sviluppo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
