import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/repository_write_guard.dart';
import '../../../core/value_objects/money.dart';
import '../../../database/local_database.dart';
import '../../billing/domain/billing_records.dart';
import '../domain/export_document.dart';

class ReportExportService {
  const ReportExportService({
    required ConstructionDatabase database,
    required RepositoryWriteGuard writeGuard,
  })  : _database = database,
        _writeGuard = writeGuard;

  final ConstructionDatabase _database;
  final RepositoryWriteGuard _writeGuard;

  Future<ExportDocument> createPdf({
    required String companyId,
    required BillingDashboardSummary summary,
  }) async {
    _writeGuard.require(PermissionKey.exportReports);
    final companyName = await _companyName(companyId);
    final rows = _rows(summary);
    final document = pw.Document();
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text(companyName,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Construction ERP - Profit and Loss Report'),
        pw.Text('Generated: ${DateTime.now().toLocal()}'),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: const ['Section', 'Item', 'Amount'],
          data: rows
              .map((row) => [row.section, row.label, _pdfMoney(row.money)])
              .toList(growable: false),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellPadding: const pw.EdgeInsets.all(7),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
            'Generated from local ledger entries. SQLite remains the source of truth.',
            style: const pw.TextStyle(fontSize: 9)),
      ],
    ));
    return ExportDocument(
      fileName: 'profit_loss_${_dateStamp()}.pdf',
      extension: 'pdf',
      bytes: await document.save(),
    );
  }

  Future<ExportDocument> createExcel({
    required String companyId,
    required BillingDashboardSummary summary,
  }) async {
    _writeGuard.require(PermissionKey.exportReports);
    final companyName = await _companyName(companyId);
    final workbook = Excel.createExcel();
    final sheet = workbook['Profit Loss'];
    sheet.appendRow([TextCellValue(companyName)]);
    sheet.appendRow([TextCellValue('Construction ERP Profit and Loss Report')]);
    sheet.appendRow([
      TextCellValue('Generated'),
      TextCellValue(DateTime.now().toLocal().toString()),
    ]);
    sheet.appendRow(const []);
    sheet.appendRow([
      TextCellValue('Section'),
      TextCellValue('Item'),
      TextCellValue('Amount (paise)'),
      TextCellValue('Formatted amount'),
    ]);
    for (final row in _rows(summary)) {
      sheet.appendRow([
        TextCellValue(row.section),
        TextCellValue(row.label),
        IntCellValue(row.money.paise),
        TextCellValue(row.money.format()),
      ]);
    }
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != 'Profit Loss') {
      workbook.delete(defaultSheet);
    }
    final encoded = workbook.encode();
    if (encoded == null) throw StateError('Excel export could not be created.');
    return ExportDocument(
      fileName: 'profit_loss_${_dateStamp()}.xlsx',
      extension: 'xlsx',
      bytes: Uint8List.fromList(encoded),
    );
  }

  Future<String> _companyName(String companyId) async {
    await _database.ensureSchema();
    final row = await _database.customSelect(
      'SELECT name FROM companies WHERE id = ? AND is_deleted = 0 LIMIT 1',
      variables: [Variable(companyId)],
    ).getSingleOrNull();
    return row?.data['name']?.toString() ?? 'Construction Company';
  }

  List<_ExportRow> _rows(BillingDashboardSummary summary) => [
        _ExportRow('Revenue', 'Agreement value', summary.agreementValue),
        _ExportRow('Revenue', 'Total billed', summary.totalBilled),
        _ExportRow('Revenue', 'Total received', summary.totalReceived),
        _ExportRow('Revenue', 'Pending receivable', summary.pendingReceivable),
        _ExportRow(
            'Cost', 'Estimated project cost', summary.latestEstimateTotal),
        _ExportRow('Cost', 'Material', summary.materialCost),
        _ExportRow('Cost', 'Labor', summary.laborCost),
        _ExportRow('Cost', 'Machinery', summary.machineryCost),
        _ExportRow('Cost', 'Fuel', summary.fuelCost),
        _ExportRow('Cost', 'Repair', summary.repairCost),
        _ExportRow('Cost', 'Other expenses', summary.otherExpenseCost),
        _ExportRow('Cost', 'Total actual cost', summary.totalActualCost),
        _ExportRow('GST', 'GST input', summary.gstInput),
        _ExportRow('GST', 'GST output', summary.gstOutput),
        _ExportRow(
            'GST', 'Net GST position', summary.gstOutput - summary.gstInput),
        _ExportRow('Profit/Loss', 'Estimated profit', summary.estimatedProfit),
        _ExportRow('Profit/Loss', 'Profit by agreement',
            summary.actualProfitByAgreement),
        _ExportRow('Profit/Loss', 'Profit by received',
            summary.actualProfitByReceived),
        _ExportRow('Profit/Loss', 'Total payable', summary.totalPayable),
      ];

  String _pdfMoney(Money money) => money.format(symbol: 'Rs. ');

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class _ExportRow {
  const _ExportRow(this.section, this.label, this.money);
  final String section;
  final String label;
  final Money money;
}
