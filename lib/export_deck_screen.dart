import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExportDeckScreen extends StatelessWidget {
  final String decklist;

  ExportDeckScreen({required this.decklist});

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: decklist));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Decklist copied to clipboard!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Export Decklist"),
        actions: [
          IconButton(
            icon: Icon(Icons.copy),
            onPressed: () => _copyToClipboard(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  decklist,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
