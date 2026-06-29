import 'package:flutter/foundation.dart';

import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';

const int _basisPointDenominator = 10000;

enum BillType {
  runningBill('runningBill'),
  finalBill('finalBill'),
  advanceBill('advanceBill');

  const BillType(this.value);
  final String value;

  static BillType fromValue(String value) {
    return values.firstWhere((item) => item.value == value,
        orElse: () => runningBill);
  }

  String get label {
    return switch (this) {
      BillType.runningBill => 'Running bill',
      BillType.finalBill => 'Final bill',
      BillType.advanceBill => 'Advance bill',
    };
  }
}

enum BillStatus {
  draft('draft'),
  submitted('submitted'),
  approved('approved'),
  paid('paid'),
  partial('partial');

  const BillStatus(this.value);
  final String value;

  static BillStatus fromValue(String value) {
    return values.firstWhere((item) => item.value == value,
        orElse: () => draft);
  }

  String get label {
    return switch (this) {
      BillStatus.draft => 'Draft',
      BillStatus.submitted => 'Submitted',
      BillStatus.approved => 'Approved',
      BillStatus.paid => 'Paid',
      BillStatus.partial => 'Partial',
    };
  }
}

enum GstType {
  input('input'),
  output('output');

  const GstType(this.value);
  final String value;

  static GstType fromValue(String value) {
    return values.firstWhere((item) => item.value == value,
        orElse: () => input);
  }

  String get label => this == GstType.input ? 'Input GST' : 'Output GST';
}

enum GstSourceType {
  materialPurchase('materialPurchase'),
  projectBill('projectBill'),
  otherExpense('otherExpense'),
  manual('manual');

  const GstSourceType(this.value);
  final String value;

  static GstSourceType fromValue(String value) {
    return values.firstWhere((item) => item.value == value,
        orElse: () => manual);
  }
}

@immutable
class EstimateItemDraft {
  const EstimateItemDraft({
    required this.itemName,
    this.description,
    this.unit = 'piece',
    required this.quantity,
    required this.rate,
  });

  final String itemName;
  final String? description;
  final String unit;
  final DecimalQuantity quantity;
  final Money rate;

  Map<String, Object?> toPayload({required Money amount}) => {
        'itemName': itemName,
        'description': description,
        'unit': unit,
        'quantity': quantity.toStorageString(),
        'ratePaise': rate.paise,
        'amountPaise': amount.paise,
      };
}

@immutable
class EstimateItemRecord {
  const EstimateItemRecord({
    required this.id,
    required this.estimateId,
    required this.itemName,
    this.description,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.amount,
  });

  final String id;
  final String estimateId;
  final String itemName;
  final String? description;
  final String unit;
  final DecimalQuantity quantity;
  final Money rate;
  final Money amount;
}

@immutable
class ProjectEstimateDraft {
  const ProjectEstimateDraft({
    required this.projectId,
    this.estimateNumber,
    required this.estimateDate,
    required this.title,
    required this.items,
    this.estimatedMaterialCost = Money.zero,
    this.estimatedLaborCost = Money.zero,
    this.estimatedMachineryCost = Money.zero,
    this.estimatedOtherCost = Money.zero,
    this.notes,
  });

  final String projectId;
  final String? estimateNumber;
  final int estimateDate;
  final String title;
  final List<EstimateItemDraft> items;
  final Money estimatedMaterialCost;
  final Money estimatedLaborCost;
  final Money estimatedMachineryCost;
  final Money estimatedOtherCost;
  final String? notes;
}

@immutable
class ProjectEstimateRecord {
  const ProjectEstimateRecord({
    required this.id,
    required this.companyId,
    required this.projectId,
    this.estimateNumber,
    required this.estimateDate,
    required this.title,
    required this.totalEstimatedMaterialCost,
    required this.totalEstimatedLaborCost,
    required this.totalEstimatedMachineryCost,
    required this.totalEstimatedOtherCost,
    required this.totalEstimatedCost,
    required this.estimatedProfit,
    this.notes,
    this.items = const <EstimateItemRecord>[],
  });

  final String id;
  final String companyId;
  final String projectId;
  final String? estimateNumber;
  final int estimateDate;
  final String title;
  final Money totalEstimatedMaterialCost;
  final Money totalEstimatedLaborCost;
  final Money totalEstimatedMachineryCost;
  final Money totalEstimatedOtherCost;
  final Money totalEstimatedCost;
  final Money estimatedProfit;
  final String? notes;
  final List<EstimateItemRecord> items;
}

@immutable
class ProjectBillDraft {
  const ProjectBillDraft({
    required this.projectId,
    required this.billNumber,
    required this.billDate,
    this.billType = BillType.runningBill,
    required this.grossBillAmount,
    this.gstRateBasisPoints = 0,
    this.tdsAmount = Money.zero,
    this.retentionAmount = Money.zero,
    this.otherDeductionAmount = Money.zero,
    this.initialReceivedAmount = Money.zero,
    this.status = BillStatus.draft,
    this.notes,
  });

  final String projectId;
  final String billNumber;
  final int billDate;
  final BillType billType;
  final Money grossBillAmount;
  final int gstRateBasisPoints;
  final Money tdsAmount;
  final Money retentionAmount;
  final Money otherDeductionAmount;
  final Money initialReceivedAmount;
  final BillStatus status;
  final String? notes;
}

@immutable
class ProjectBillRecord {
  const ProjectBillRecord({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.billNumber,
    required this.billDate,
    required this.billType,
    required this.grossBillAmount,
    required this.gstRateBasisPoints,
    required this.gstAmount,
    required this.totalBillAmount,
    required this.tdsAmount,
    required this.retentionAmount,
    required this.otherDeductionAmount,
    required this.netReceivableAmount,
    required this.receivedAmount,
    required this.pendingAmount,
    required this.status,
    this.notes,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String billNumber;
  final int billDate;
  final BillType billType;
  final Money grossBillAmount;
  final int gstRateBasisPoints;
  final Money gstAmount;
  final Money totalBillAmount;
  final Money tdsAmount;
  final Money retentionAmount;
  final Money otherDeductionAmount;
  final Money netReceivableAmount;
  final Money receivedAmount;
  final Money pendingAmount;
  final BillStatus status;
  final String? notes;
}

@immutable
class ProjectBillReceiptDraft {
  const ProjectBillReceiptDraft({
    required this.projectId,
    required this.billId,
    required this.receiptDate,
    required this.amount,
    this.paymentMode = 'bank',
    this.referenceNumber,
    this.notes,
  });

  final String projectId;
  final String billId;
  final int receiptDate;
  final Money amount;
  final String paymentMode;
  final String? referenceNumber;
  final String? notes;
}

@immutable
class ProjectBillReceiptRecord {
  const ProjectBillReceiptRecord({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.billId,
    required this.receiptDate,
    required this.amount,
    this.paymentMode,
    this.referenceNumber,
    this.notes,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String billId;
  final int receiptDate;
  final Money amount;
  final String? paymentMode;
  final String? referenceNumber;
  final String? notes;
}

@immutable
class GstEntryDraft {
  const GstEntryDraft({
    this.projectId,
    this.sourceType = GstSourceType.manual,
    required this.sourceId,
    required this.gstType,
    required this.gstRateBasisPoints,
    required this.taxableAmount,
    required this.gstAmount,
    required this.entryDate,
    this.notes,
  });

  final String? projectId;
  final GstSourceType sourceType;
  final String sourceId;
  final GstType gstType;
  final int gstRateBasisPoints;
  final Money taxableAmount;
  final Money gstAmount;
  final int entryDate;
  final String? notes;
}

@immutable
class GstEntryRecord {
  const GstEntryRecord({
    required this.id,
    required this.companyId,
    this.projectId,
    required this.sourceType,
    required this.sourceId,
    required this.gstType,
    required this.gstRateBasisPoints,
    required this.taxableAmount,
    required this.gstAmount,
    required this.entryDate,
    this.notes,
  });

  final String id;
  final String companyId;
  final String? projectId;
  final GstSourceType sourceType;
  final String sourceId;
  final GstType gstType;
  final int gstRateBasisPoints;
  final Money taxableAmount;
  final Money gstAmount;
  final int entryDate;
  final String? notes;
}

@immutable
class BillTotals {
  const BillTotals({
    required this.gstAmount,
    required this.totalBillAmount,
    required this.netReceivableAmount,
    required this.receivedAmount,
    required this.pendingAmount,
    required this.status,
  });

  final Money gstAmount;
  final Money totalBillAmount;
  final Money netReceivableAmount;
  final Money receivedAmount;
  final Money pendingAmount;
  final BillStatus status;
}

@immutable
class EstimateTotals {
  const EstimateTotals({
    required this.itemTotal,
    required this.materialCost,
    required this.laborCost,
    required this.machineryCost,
    required this.otherCost,
    required this.totalEstimatedCost,
    required this.estimatedProfit,
  });

  final Money itemTotal;
  final Money materialCost;
  final Money laborCost;
  final Money machineryCost;
  final Money otherCost;
  final Money totalEstimatedCost;
  final Money estimatedProfit;
}

@immutable
class BillingDashboardSummary {
  const BillingDashboardSummary({
    required this.agreementValue,
    required this.latestEstimateTotal,
    required this.estimatedProfit,
    required this.materialCost,
    required this.laborCost,
    required this.machineryCost,
    required this.fuelCost,
    required this.repairCost,
    required this.otherExpenseCost,
    required this.totalActualCost,
    required this.gstInput,
    required this.gstOutput,
    required this.totalBilled,
    required this.totalReceived,
    required this.pendingReceivable,
    required this.totalPayable,
    required this.actualProfitByAgreement,
    required this.actualProfitByReceived,
  });

  factory BillingDashboardSummary.empty() {
    return const BillingDashboardSummary(
      agreementValue: Money.zero,
      latestEstimateTotal: Money.zero,
      estimatedProfit: Money.zero,
      materialCost: Money.zero,
      laborCost: Money.zero,
      machineryCost: Money.zero,
      fuelCost: Money.zero,
      repairCost: Money.zero,
      otherExpenseCost: Money.zero,
      totalActualCost: Money.zero,
      gstInput: Money.zero,
      gstOutput: Money.zero,
      totalBilled: Money.zero,
      totalReceived: Money.zero,
      pendingReceivable: Money.zero,
      totalPayable: Money.zero,
      actualProfitByAgreement: Money.zero,
      actualProfitByReceived: Money.zero,
    );
  }

  final Money agreementValue;
  final Money latestEstimateTotal;
  final Money estimatedProfit;
  final Money materialCost;
  final Money laborCost;
  final Money machineryCost;
  final Money fuelCost;
  final Money repairCost;
  final Money otherExpenseCost;
  final Money totalActualCost;
  final Money gstInput;
  final Money gstOutput;
  final Money totalBilled;
  final Money totalReceived;
  final Money pendingReceivable;
  final Money totalPayable;
  final Money actualProfitByAgreement;
  final Money actualProfitByReceived;
}

class BillingCalculator {
  const BillingCalculator();

  Money calculateAmount(DecimalQuantity quantity, Money rate) {
    return quantity.multiplyMoney(rate);
  }

  Money calculateGst(Money taxableAmount, int gstRateBasisPoints) {
    if (gstRateBasisPoints < 0) {
      throw ArgumentError.value(gstRateBasisPoints, 'gstRateBasisPoints',
          'GST rate cannot be negative.');
    }
    return Money.fromPaise((BigInt.from(taxableAmount.paise) *
            BigInt.from(gstRateBasisPoints) ~/
            BigInt.from(_basisPointDenominator))
        .toInt());
  }

  EstimateTotals calculateEstimate(
      ProjectEstimateDraft draft, Money agreementFinalValue) {
    var itemTotal = Money.zero;
    for (final item in draft.items) {
      itemTotal += calculateAmount(item.quantity, item.rate);
    }
    final materialCost = draft.estimatedMaterialCost.isZero
        ? itemTotal
        : draft.estimatedMaterialCost;
    final totalEstimatedCost = materialCost +
        draft.estimatedLaborCost +
        draft.estimatedMachineryCost +
        draft.estimatedOtherCost;
    return EstimateTotals(
      itemTotal: itemTotal,
      materialCost: materialCost,
      laborCost: draft.estimatedLaborCost,
      machineryCost: draft.estimatedMachineryCost,
      otherCost: draft.estimatedOtherCost,
      totalEstimatedCost: totalEstimatedCost,
      estimatedProfit: agreementFinalValue - totalEstimatedCost,
    );
  }

  BillTotals calculateBill(ProjectBillDraft draft) {
    _assertNonNegative('grossBillAmount', draft.grossBillAmount);
    _assertNonNegative('tdsAmount', draft.tdsAmount);
    _assertNonNegative('retentionAmount', draft.retentionAmount);
    _assertNonNegative('otherDeductionAmount', draft.otherDeductionAmount);
    _assertNonNegative('initialReceivedAmount', draft.initialReceivedAmount);

    final gstAmount =
        calculateGst(draft.grossBillAmount, draft.gstRateBasisPoints);
    final totalBillAmount = draft.grossBillAmount + gstAmount;
    final netReceivable = totalBillAmount -
        draft.tdsAmount -
        draft.retentionAmount -
        draft.otherDeductionAmount;
    if (netReceivable.paise < 0) {
      throw ArgumentError(
          'Net receivable cannot be negative. Check deduction amounts.');
    }
    if (draft.initialReceivedAmount.paise > netReceivable.paise) {
      throw ArgumentError(
          'Received amount cannot be greater than net receivable.');
    }
    final pending = netReceivable - draft.initialReceivedAmount;
    final status = draft.initialReceivedAmount.isZero
        ? draft.status
        : pending.isZero
            ? BillStatus.paid
            : BillStatus.partial;
    return BillTotals(
      gstAmount: gstAmount,
      totalBillAmount: totalBillAmount,
      netReceivableAmount: netReceivable,
      receivedAmount: draft.initialReceivedAmount,
      pendingAmount: pending,
      status: status,
    );
  }

  BillStatus statusFromReceipt(Money netReceivable, Money received) {
    if (received.isZero) {
      return BillStatus.approved;
    }
    return received.paise >= netReceivable.paise
        ? BillStatus.paid
        : BillStatus.partial;
  }

  void _assertNonNegative(String field, Money money) {
    if (money.paise < 0) {
      throw ArgumentError.value(money, field, '$field cannot be negative.');
    }
  }
}
