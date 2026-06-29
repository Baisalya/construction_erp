import '../../../core/value_objects/money.dart';
import 'agreement_deduction_type.dart';

class AgreementDeduction {
  const AgreementDeduction({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.deductionDate,
    required this.deductionType,
    required this.amount,
    required this.isRecoverable,
    this.description,
    this.notes,
  });

  final String id;
  final String companyId;
  final String projectId;
  final int deductionDate;
  final AgreementDeductionType deductionType;
  final String? description;
  final Money amount;
  final bool isRecoverable;
  final String? notes;

  bool get affectsAgreementFinalValue => !isRecoverable;
}

class AgreementDeductionDraft {
  const AgreementDeductionDraft({
    required this.projectId,
    required this.deductionDate,
    required this.deductionType,
    required this.amount,
    this.isRecoverable = false,
    this.description,
    this.notes,
  });

  final String projectId;
  final int deductionDate;
  final AgreementDeductionType deductionType;
  final String? description;
  final Money amount;
  final bool isRecoverable;
  final String? notes;

  Map<String, Object?> toPayload() {
    return {
      'projectId': projectId,
      'deductionDate': deductionDate,
      'deductionType': deductionType.value,
      'description': description,
      'amountPaise': amount.paise,
      'isRecoverable': isRecoverable,
      'notes': notes,
    };
  }
}
