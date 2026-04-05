import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class ExportService {
  static Future<File> generateProjectReportPdf(
    Project project,
    List<Receipt> receipts,
  ) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    double total = 0;
    int verified = 0;
    int pending = 0;
    for (final r in receipts) {
      total += r.amount;
      if (r.status == 'verified') verified++;
      if (r.status == 'pending') pending++;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Liquidation Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Text(
                  dateFormat.format(DateTime.now()),
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  project.name,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (project.location != null)
                  pw.Text(
                    'Location: ${project.location}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                if (project.phase != null)
                  pw.Text(
                    'Phase: ${project.phase}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBox(
                      'Total',
                      receipts.length.toString(),
                      PdfColors.blue800,
                    ),
                    _buildStatBox(
                      'Verified',
                      verified.toString(),
                      PdfColors.green,
                    ),
                    _buildStatBox(
                      'Pending',
                      pending.toString(),
                      PdfColors.orange,
                    ),
                    _buildStatBox(
                      'Total',
                      currencyFormat.format(total),
                      PdfColors.blue800,
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Receipt Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellPadding: const pw.EdgeInsets.all(8),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Date', 'Vendor', 'Category', 'Amount', 'Status'],
            data: receipts
                .map(
                  (r) => [
                    dateFormat.format(r.receiptDate),
                    r.vendor,
                    r.category ?? '-',
                    currencyFormat.format(r.amount),
                    r.status.toUpperCase(),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File(
      '${output.path}/report_${project.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> generateAuditReportPdf(
    Project project,
    List<Receipt> receipts,
  ) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    final pending = receipts.where((r) => r.status == 'pending').toList();
    final verified = receipts.where((r) => r.status == 'verified').toList();
    final rejected = receipts.where((r) => r.status == 'rejected').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Audit Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Text(
                  dateFormat.format(DateTime.now()),
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  project.name,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatBox(
                      'Pending',
                      pending.length.toString(),
                      PdfColors.orange,
                    ),
                    _buildStatBox(
                      'Verified',
                      verified.length.toString(),
                      PdfColors.green,
                    ),
                    _buildStatBox(
                      'Rejected',
                      rejected.length.toString(),
                      PdfColors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (pending.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            pw.Text(
              'Pending Verification',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.orange800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.orange800,
              ),
              cellPadding: const pw.EdgeInsets.all(6),
              headers: ['Date', 'Vendor', 'Amount'],
              data: pending
                  .map(
                    (r) => [
                      dateFormat.format(r.receiptDate),
                      r.vendor,
                      currencyFormat.format(r.amount),
                    ],
                  )
                  .toList(),
            ),
          ],
          if (verified.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            pw.Text(
              'Verified Receipts',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green800,
              ),
              cellPadding: const pw.EdgeInsets.all(6),
              headers: ['Date', 'Vendor', 'Amount', 'Verified By'],
              data: verified
                  .map(
                    (r) => [
                      dateFormat.format(r.receiptDate),
                      r.vendor,
                      currencyFormat.format(r.amount),
                      r.verifiedById?.toString() ?? '-',
                    ],
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File(
      '${output.path}/audit_${project.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> generateCsvExport(
    Project project,
    List<Receipt> receipts,
  ) async {
    final dateFormat = DateFormat('yyyy-MM-dd');

    final buffer = StringBuffer();
    buffer.writeln('Date,Vendor,Category,Amount,Status,Notes');

    for (final r in receipts) {
      buffer.writeln(
        '${dateFormat.format(r.receiptDate)},'
        '"${r.vendor}",'
        '${r.category ?? ""},'
        '${r.amount},'
        '${r.status},'
        '"${r.notes ?? ""}"',
      );
    }

    final output = await getApplicationDocumentsDirectory();
    final file = File(
      '${output.path}/export_${project.id}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(buffer.toString());
    return file;
  }

  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
          ),
        ],
      ),
    );
  }
}
