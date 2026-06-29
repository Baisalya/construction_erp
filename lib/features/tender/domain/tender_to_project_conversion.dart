import 'package:flutter/foundation.dart';

@immutable
class TenderProjectConversionDraft {
  const TenderProjectConversionDraft({
    required this.tenderId,
    required this.projectCode,
    this.projectName,
    this.startDate,
    this.expectedEndDate,
    this.notes,
  });

  final String tenderId;
  final String projectCode;
  final String? projectName;
  final int? startDate;
  final int? expectedEndDate;
  final String? notes;
}

@immutable
class TenderProjectConversionResult {
  const TenderProjectConversionResult({
    required this.projectId,
    required this.tenderId,
    required this.projectCode,
    required this.projectName,
  });

  final String projectId;
  final String tenderId;
  final String projectCode;
  final String projectName;
}
