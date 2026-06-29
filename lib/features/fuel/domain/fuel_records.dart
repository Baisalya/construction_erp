import 'package:flutter/foundation.dart';

import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';

enum FuelPaymentStatus {
  unpaid('unpaid'),
  partial('partial'),
  paid('paid');

  const FuelPaymentStatus(this.value);
  final String value;

  static FuelPaymentStatus fromValue(String value) =>
      values.firstWhere((item) => item.value == value, orElse: () => unpaid);
}

enum FuelUsedForType {
  machinery('machinery'),
  labor('labor'),
  materialTransport('materialTransport'),
  projectGeneral('projectGeneral'),
  other('other');

  const FuelUsedForType(this.value);
  final String value;

  static FuelUsedForType fromValue(String value) =>
      values.firstWhere((item) => item.value == value, orElse: () => other);
}

@immutable
class FuelTypeDraft {
  const FuelTypeDraft(
      {required this.name, this.unit = 'liter', this.defaultRate = Money.zero});

  final String name;
  final String unit;
  final Money defaultRate;

  Map<String, Object?> toPayload() =>
      {'name': name, 'unit': unit, 'defaultRatePaise': defaultRate.paise};
}

@immutable
class FuelTypeRecord {
  const FuelTypeRecord(
      {required this.id,
      required this.companyId,
      required this.name,
      required this.unit,
      required this.defaultRate});

  final String id;
  final String companyId;
  final String name;
  final String unit;
  final Money defaultRate;
}

@immutable
class FuelEntryDraft {
  const FuelEntryDraft({
    required this.projectId,
    required this.fuelDate,
    required this.fuelTypeId,
    required this.quantity,
    required this.rate,
    required this.usedForType,
    this.machineId,
    this.laborId,
    this.supplierId,
    this.vehicleName,
    this.description,
    this.paidAmount = Money.zero,
    this.notes,
  });

  final String projectId;
  final int fuelDate;
  final String fuelTypeId;
  final DecimalQuantity quantity;
  final Money rate;
  final FuelUsedForType usedForType;
  final String? machineId;
  final String? laborId;
  final String? supplierId;
  final String? vehicleName;
  final String? description;
  final Money paidAmount;
  final String? notes;

  Map<String, Object?> toPayload(
          {required Money totalAmount,
          required Money pendingAmount,
          required FuelPaymentStatus paymentStatus}) =>
      {
        'projectId': projectId,
        'fuelDate': fuelDate,
        'fuelTypeId': fuelTypeId,
        'quantity': quantity.toStorageString(),
        'ratePaise': rate.paise,
        'totalAmountPaise': totalAmount.paise,
        'usedForType': usedForType.value,
        'machineId': machineId,
        'laborId': laborId,
        'supplierId': supplierId,
        'vehicleName': vehicleName,
        'description': description,
        'paidAmountPaise': paidAmount.paise,
        'pendingAmountPaise': pendingAmount.paise,
        'paymentStatus': paymentStatus.value,
        'notes': notes,
      };
}

@immutable
class FuelEntryRecord {
  const FuelEntryRecord({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.fuelDate,
    required this.fuelTypeId,
    required this.quantity,
    required this.rate,
    required this.totalAmount,
    required this.usedForType,
    this.machineId,
    this.laborId,
    this.supplierId,
    this.vehicleName,
    this.description,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentStatus,
    this.notes,
  });

  final String id;
  final String companyId;
  final String projectId;
  final int fuelDate;
  final String fuelTypeId;
  final DecimalQuantity quantity;
  final Money rate;
  final Money totalAmount;
  final FuelUsedForType usedForType;
  final String? machineId;
  final String? laborId;
  final String? supplierId;
  final String? vehicleName;
  final String? description;
  final Money paidAmount;
  final Money pendingAmount;
  final FuelPaymentStatus paymentStatus;
  final String? notes;
}

class FuelCalculator {
  const FuelCalculator();

  FuelEntryTotals calculateEntry(FuelEntryDraft draft) {
    if (draft.quantity.isZero || draft.quantity.isNegative) {
      throw ArgumentError.value(draft.quantity, 'quantity',
          'Fuel quantity must be greater than zero.');
    }
    if (draft.rate.paise < 0 || draft.paidAmount.paise < 0) {
      throw ArgumentError('Fuel rate and paid amount cannot be negative.');
    }
    final total = draft.quantity.multiplyMoney(draft.rate);
    if (draft.paidAmount.paise > total.paise) {
      throw ArgumentError.value(draft.paidAmount, 'paidAmount',
          'Paid fuel amount cannot exceed total.');
    }
    final pending = total - draft.paidAmount;
    final status = pending.isZero
        ? FuelPaymentStatus.paid
        : draft.paidAmount.isZero
            ? FuelPaymentStatus.unpaid
            : FuelPaymentStatus.partial;
    return FuelEntryTotals(
        totalAmount: total, pendingAmount: pending, paymentStatus: status);
  }
}

@immutable
class FuelEntryTotals {
  const FuelEntryTotals(
      {required this.totalAmount,
      required this.pendingAmount,
      required this.paymentStatus});

  final Money totalAmount;
  final Money pendingAmount;
  final FuelPaymentStatus paymentStatus;
}
