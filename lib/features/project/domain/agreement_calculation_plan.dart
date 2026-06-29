import '../../../core/value_objects/money.dart';
import 'agreement_deduction.dart';

class AgreementCalculationInput {
  const AgreementCalculationInput({
    required this.grossValue,
    required this.securityDepositAmount,
    required this.deductions,
    this.includeSecurityDepositAsDeduction = true,
  });

  final Money grossValue;
  final Money securityDepositAmount;
  final List<AgreementDeduction> deductions;
  final bool includeSecurityDepositAsDeduction;
}

class AgreementCalculationResult {
  const AgreementCalculationResult({
    required this.grossValue,
    required this.nonRecoverableDeductions,
    required this.recoverableDeductions,
    required this.securityDepositDeduction,
    required this.finalValue,
  });

  final Money grossValue;
  final Money nonRecoverableDeductions;
  final Money recoverableDeductions;
  final Money securityDepositDeduction;
  final Money finalValue;

  Money get totalShownDeductions =>
      nonRecoverableDeductions + securityDepositDeduction;
}

class AgreementCalculationPlan {
  const AgreementCalculationPlan({
    required this.grossValue,
    required this.nonRecoverableDeductions,
    required this.securityDepositDeduction,
  });

  final Money grossValue;
  final Money nonRecoverableDeductions;
  final Money securityDepositDeduction;

  Money get finalValue =>
      grossValue - nonRecoverableDeductions - securityDepositDeduction;
}

class ProjectAgreementService {
  const ProjectAgreementService();

  AgreementCalculationResult calculate(AgreementCalculationInput input) {
    var nonRecoverablePaise = 0;
    var recoverablePaise = 0;
    for (final deduction in input.deductions) {
      if (deduction.isRecoverable) {
        recoverablePaise += deduction.amount.paise;
      } else {
        nonRecoverablePaise += deduction.amount.paise;
      }
    }

    final securityDepositDeduction = input.includeSecurityDepositAsDeduction
        ? input.securityDepositAmount
        : Money.zero;
    final nonRecoverable = Money.fromPaise(nonRecoverablePaise);
    final recoverable = Money.fromPaise(recoverablePaise);
    final finalValue =
        input.grossValue - nonRecoverable - securityDepositDeduction;

    return AgreementCalculationResult(
      grossValue: input.grossValue,
      nonRecoverableDeductions: nonRecoverable,
      recoverableDeductions: recoverable,
      securityDepositDeduction: securityDepositDeduction,
      finalValue: finalValue,
    );
  }
}
