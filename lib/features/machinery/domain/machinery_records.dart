import 'package:flutter/foundation.dart';

import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';

enum MachineOwnershipType {
  own('own'),
  rental('rental');

  const MachineOwnershipType(this.value);
  final String value;

  static MachineOwnershipType fromValue(String value) =>
      values.firstWhere((item) => item.value == value, orElse: () => own);
}

enum MachineChargeType {
  hourly('hourly'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  fixed('fixed');

  const MachineChargeType(this.value);
  final String value;

  static MachineChargeType fromValue(String? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => daily);
}

enum MachinePaymentStatus {
  unpaid('unpaid'),
  partial('partial'),
  paid('paid');

  const MachinePaymentStatus(this.value);
  final String value;

  static MachinePaymentStatus fromValue(String value) =>
      values.firstWhere((item) => item.value == value, orElse: () => unpaid);
}

enum MachinePaymentMode {
  cash('cash'),
  bank('bank'),
  upi('upi'),
  cheque('cheque'),
  other('other');

  const MachinePaymentMode(this.value);
  final String value;
}

@immutable
class MachineDraft {
  const MachineDraft({
    required this.machineName,
    this.machineType,
    this.ownershipType = MachineOwnershipType.own,
    this.ownerName,
    this.ownerPhone,
    this.registrationNumber,
    this.defaultChargeType = MachineChargeType.daily,
    this.defaultChargeRate = Money.zero,
    this.notes,
  });

  final String machineName;
  final String? machineType;
  final MachineOwnershipType ownershipType;
  final String? ownerName;
  final String? ownerPhone;
  final String? registrationNumber;
  final MachineChargeType defaultChargeType;
  final Money defaultChargeRate;
  final String? notes;

  Map<String, Object?> toPayload() => {
        'machineName': machineName,
        'machineType': machineType,
        'ownershipType': ownershipType.value,
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'registrationNumber': registrationNumber,
        'defaultChargeType': defaultChargeType.value,
        'defaultChargeRatePaise': defaultChargeRate.paise,
        'notes': notes,
      };
}

@immutable
class MachineRecord {
  const MachineRecord({
    required this.id,
    required this.companyId,
    required this.machineName,
    this.machineType,
    required this.ownershipType,
    this.ownerName,
    this.ownerPhone,
    this.registrationNumber,
    required this.defaultChargeType,
    required this.defaultChargeRate,
    this.notes,
  });

  final String id;
  final String companyId;
  final String machineName;
  final String? machineType;
  final MachineOwnershipType ownershipType;
  final String? ownerName;
  final String? ownerPhone;
  final String? registrationNumber;
  final MachineChargeType defaultChargeType;
  final Money defaultChargeRate;
  final String? notes;
}

@immutable
class MachineUsageDraft {
  const MachineUsageDraft({
    required this.projectId,
    required this.machineId,
    required this.usageDate,
    this.workDescription,
    required this.chargeType,
    this.hoursUsed,
    this.daysUsed,
    this.quantity,
    required this.rate,
    this.paidAmount = Money.zero,
    this.notes,
  });

  final String projectId;
  final String machineId;
  final int usageDate;
  final String? workDescription;
  final MachineChargeType chargeType;
  final DecimalQuantity? hoursUsed;
  final DecimalQuantity? daysUsed;
  final DecimalQuantity? quantity;
  final Money rate;
  final Money paidAmount;
  final String? notes;

  DecimalQuantity get effectiveQuantity {
    return switch (chargeType) {
      MachineChargeType.hourly => hoursUsed ?? DecimalQuantity.zero,
      MachineChargeType.daily => daysUsed ?? DecimalQuantity.zero,
      MachineChargeType.weekly ||
      MachineChargeType.monthly ||
      MachineChargeType.fixed =>
        quantity ?? DecimalQuantity.whole(1),
    };
  }

  Map<String, Object?> toPayload(
          {required Money totalAmount,
          required Money pendingAmount,
          required MachinePaymentStatus paymentStatus}) =>
      {
        'projectId': projectId,
        'machineId': machineId,
        'usageDate': usageDate,
        'workDescription': workDescription,
        'chargeType': chargeType.value,
        'hoursUsed': hoursUsed?.toStorageString(),
        'daysUsed': daysUsed?.toStorageString(),
        'quantity': quantity?.toStorageString(),
        'ratePaise': rate.paise,
        'totalAmountPaise': totalAmount.paise,
        'paidAmountPaise': paidAmount.paise,
        'pendingAmountPaise': pendingAmount.paise,
        'paymentStatus': paymentStatus.value,
        'notes': notes,
      };
}

@immutable
class MachineUsageRecord {
  const MachineUsageRecord({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.machineId,
    required this.usageDate,
    this.workDescription,
    required this.chargeType,
    this.hoursUsed,
    this.daysUsed,
    this.quantity,
    required this.rate,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentStatus,
    this.notes,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String machineId;
  final int usageDate;
  final String? workDescription;
  final MachineChargeType chargeType;
  final DecimalQuantity? hoursUsed;
  final DecimalQuantity? daysUsed;
  final DecimalQuantity? quantity;
  final Money rate;
  final Money totalAmount;
  final Money paidAmount;
  final Money pendingAmount;
  final MachinePaymentStatus paymentStatus;
  final String? notes;
}

@immutable
class MachineRentalPaymentDraft {
  const MachineRentalPaymentDraft({
    required this.machineId,
    this.projectId,
    this.ownerName,
    required this.paymentDate,
    required this.amount,
    this.paymentMode = MachinePaymentMode.cash,
    this.referenceNumber,
    this.notes,
  });

  final String machineId;
  final String? projectId;
  final String? ownerName;
  final int paymentDate;
  final Money amount;
  final MachinePaymentMode paymentMode;
  final String? referenceNumber;
  final String? notes;
}

@immutable
class MachineRepairDraft {
  const MachineRepairDraft({
    required this.machineId,
    this.projectId,
    required this.repairDate,
    this.repairDescription,
    this.mechanicName,
    this.partsCost = Money.zero,
    this.laborCost = Money.zero,
    this.paidAmount = Money.zero,
    this.notes,
  });

  final String machineId;
  final String? projectId;
  final int repairDate;
  final String? repairDescription;
  final String? mechanicName;
  final Money partsCost;
  final Money laborCost;
  final Money paidAmount;
  final String? notes;

  Map<String, Object?> toPayload(
          {required Money totalCost, required Money pendingAmount}) =>
      {
        'machineId': machineId,
        'projectId': projectId,
        'repairDate': repairDate,
        'repairDescription': repairDescription,
        'mechanicName': mechanicName,
        'partsCostPaise': partsCost.paise,
        'laborCostPaise': laborCost.paise,
        'totalCostPaise': totalCost.paise,
        'paidAmountPaise': paidAmount.paise,
        'pendingAmountPaise': pendingAmount.paise,
        'notes': notes,
      };
}

@immutable
class MachineRepairRecord {
  const MachineRepairRecord({
    required this.id,
    required this.companyId,
    required this.machineId,
    this.projectId,
    required this.repairDate,
    this.repairDescription,
    this.mechanicName,
    required this.partsCost,
    required this.laborCost,
    required this.totalCost,
    required this.paidAmount,
    required this.pendingAmount,
    this.notes,
  });

  final String id;
  final String companyId;
  final String machineId;
  final String? projectId;
  final int repairDate;
  final String? repairDescription;
  final String? mechanicName;
  final Money partsCost;
  final Money laborCost;
  final Money totalCost;
  final Money paidAmount;
  final Money pendingAmount;
  final String? notes;
}

class MachineryCalculator {
  const MachineryCalculator();

  MachineUsageTotals calculateUsage(MachineUsageDraft draft) {
    final quantity = draft.effectiveQuantity;
    if (quantity.isZero || quantity.isNegative) {
      throw ArgumentError.value(quantity, 'quantity',
          'Machine usage quantity must be greater than zero.');
    }
    if (draft.rate.paise < 0 || draft.paidAmount.paise < 0) {
      throw ArgumentError('Machine rate and paid amount cannot be negative.');
    }
    final total = quantity.multiplyMoney(draft.rate);
    if (draft.paidAmount.paise > total.paise) {
      throw ArgumentError.value(draft.paidAmount, 'paidAmount',
          'Paid amount cannot exceed machine usage total.');
    }
    final pending = total - draft.paidAmount;
    final status = pending.isZero
        ? MachinePaymentStatus.paid
        : draft.paidAmount.isZero
            ? MachinePaymentStatus.unpaid
            : MachinePaymentStatus.partial;
    return MachineUsageTotals(
        totalAmount: total, pendingAmount: pending, paymentStatus: status);
  }

  MachineRepairTotals calculateRepair(MachineRepairDraft draft) {
    if (draft.partsCost.paise < 0 ||
        draft.laborCost.paise < 0 ||
        draft.paidAmount.paise < 0) {
      throw ArgumentError('Repair costs cannot be negative.');
    }
    final total = draft.partsCost + draft.laborCost;
    if (draft.paidAmount.paise > total.paise) {
      throw ArgumentError.value(draft.paidAmount, 'paidAmount',
          'Paid amount cannot exceed repair total.');
    }
    return MachineRepairTotals(
        totalCost: total, pendingAmount: total - draft.paidAmount);
  }
}

@immutable
class MachineUsageTotals {
  const MachineUsageTotals(
      {required this.totalAmount,
      required this.pendingAmount,
      required this.paymentStatus});

  final Money totalAmount;
  final Money pendingAmount;
  final MachinePaymentStatus paymentStatus;
}

@immutable
class MachineRepairTotals {
  const MachineRepairTotals(
      {required this.totalCost, required this.pendingAmount});

  final Money totalCost;
  final Money pendingAmount;
}
