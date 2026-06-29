import '../../../core/value_objects/money.dart';
import 'project_status.dart';

class ProjectRecord {
  const ProjectRecord({
    required this.id,
    required this.companyId,
    required this.projectName,
    required this.projectStatus,
    required this.tenderQuotedPrice,
    required this.approvedTenderAmount,
    required this.agreementGrossValue,
    required this.agreementFinalValue,
    required this.gstRateBasisPoints,
    required this.retentionPercentBasisPoints,
    required this.securityDepositAmount,
    required this.performanceGuaranteeAmount,
    required this.advanceReceived,
    required this.version,
    this.tenderId,
    this.projectCode,
    this.clientName,
    this.departmentName,
    this.siteLocation,
    this.startDate,
    this.expectedEndDate,
    this.actualEndDate,
    this.notes,
  });

  final String id;
  final String companyId;
  final String? tenderId;
  final String? projectCode;
  final String projectName;
  final String? clientName;
  final String? departmentName;
  final String? siteLocation;
  final int? startDate;
  final int? expectedEndDate;
  final int? actualEndDate;
  final ProjectStatus projectStatus;
  final Money tenderQuotedPrice;
  final Money approvedTenderAmount;
  final Money agreementGrossValue;
  final Money agreementFinalValue;
  final int gstRateBasisPoints;
  final int retentionPercentBasisPoints;
  final Money securityDepositAmount;
  final Money performanceGuaranteeAmount;
  final Money advanceReceived;
  final String? notes;
  final int version;

  String get displayCode => projectCode == null || projectCode!.trim().isEmpty
      ? 'No code'
      : projectCode!;
}

class ProjectDraft {
  const ProjectDraft({
    required this.projectName,
    this.projectCode,
    this.tenderId,
    this.clientName,
    this.departmentName,
    this.siteLocation,
    this.startDate,
    this.expectedEndDate,
    this.projectStatus = ProjectStatus.planned,
    this.tenderQuotedPrice = Money.zero,
    this.approvedTenderAmount = Money.zero,
    this.agreementGrossValue = Money.zero,
    this.gstRateBasisPoints = 0,
    this.retentionPercentBasisPoints = 0,
    this.securityDepositAmount = Money.zero,
    this.performanceGuaranteeAmount = Money.zero,
    this.advanceReceived = Money.zero,
    this.notes,
  });

  final String projectName;
  final String? projectCode;
  final String? tenderId;
  final String? clientName;
  final String? departmentName;
  final String? siteLocation;
  final int? startDate;
  final int? expectedEndDate;
  final ProjectStatus projectStatus;
  final Money tenderQuotedPrice;
  final Money approvedTenderAmount;
  final Money agreementGrossValue;
  final int gstRateBasisPoints;
  final int retentionPercentBasisPoints;
  final Money securityDepositAmount;
  final Money performanceGuaranteeAmount;
  final Money advanceReceived;
  final String? notes;

  Map<String, Object?> toPayload({required Money agreementFinalValue}) {
    return {
      'projectName': projectName,
      'projectCode': projectCode,
      'tenderId': tenderId,
      'clientName': clientName,
      'departmentName': departmentName,
      'siteLocation': siteLocation,
      'startDate': startDate,
      'expectedEndDate': expectedEndDate,
      'projectStatus': projectStatus.value,
      'tenderQuotedPricePaise': tenderQuotedPrice.paise,
      'approvedTenderAmountPaise': approvedTenderAmount.paise,
      'agreementGrossValuePaise': agreementGrossValue.paise,
      'agreementFinalValuePaise': agreementFinalValue.paise,
      'gstRateBasisPoints': gstRateBasisPoints,
      'retentionPercentBasisPoints': retentionPercentBasisPoints,
      'securityDepositAmountPaise': securityDepositAmount.paise,
      'performanceGuaranteeAmountPaise': performanceGuaranteeAmount.paise,
      'advanceReceivedPaise': advanceReceived.paise,
      'notes': notes,
    };
  }
}
