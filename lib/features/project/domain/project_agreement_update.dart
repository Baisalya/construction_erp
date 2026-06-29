import '../../../core/value_objects/money.dart';
import 'project_status.dart';

class ProjectAgreementUpdateDraft {
  const ProjectAgreementUpdateDraft({
    required this.projectId,
    required this.agreementGrossValue,
    this.approvedTenderAmount,
    this.gstRateBasisPoints,
    this.retentionPercentBasisPoints,
    this.securityDepositAmount,
    this.performanceGuaranteeAmount,
    this.advanceReceived,
    this.projectStatus,
    this.notes,
  });

  final String projectId;
  final Money agreementGrossValue;
  final Money? approvedTenderAmount;
  final int? gstRateBasisPoints;
  final int? retentionPercentBasisPoints;
  final Money? securityDepositAmount;
  final Money? performanceGuaranteeAmount;
  final Money? advanceReceived;
  final ProjectStatus? projectStatus;
  final String? notes;
}
