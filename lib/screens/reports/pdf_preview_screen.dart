import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final DateTime month;
  final Future<Uint8List> Function() buildPdf;

  const PdfPreviewScreen({
    super.key,
    required this.month,
    required this.buildPdf,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'es').format(month);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Extracto PDF - $monthName'),
      ),
      body: PdfPreview(
        build: (_) => buildPdf(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        previewPageMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        loadingWidget: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Generando extracto financiero...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        pdfFileName: 'extracto_${DateFormat('yyyy_MM').format(month)}.pdf',
      ),
    );
  }
}
