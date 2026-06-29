import 'package:flutter/foundation.dart';

import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';

enum LaborPaymentStatus {
  unpaid('unpaid'),
  partial('partial'),
  paid('paid');

  const LaborPaymentStatus(this.value);
  final String value;

  static LaborPaymentStatus fromValue(String value) {
    return values.firstWhere((item) => item.value == value,
        orElse: () => unpaid);
  }
}

enum LaborWorkType {
  daywise('daywise'),
  thika('thika'),
  hourly('hourly'),
  piecework('piecework'),
  custom('custom');

  const LaborWorkType(this.value);
  final String value;

  static LaborWorkType fromValue(String? value) {
    return values.firstWhere((item) => item.value == value,
        orElse: () => daywise);
  }
}

enum LaborType {
  worker('worker'),
  mason('mason'),
  helper('helper'),
  contractor('contractor'),
  supervisor('supervisor'),
  custom('custom');

  const LaborType(this.value);
  final String value;

  static LaborType fromValue(String? value) {
    return values.firstWhere((item) => item.value == value,
        orElse: () => worker);
  }
}

enum LaborPaymentMode {
  cash('cash'),
  bank('bank'),
  upi('upi'),
  cheque('cheque'),
  other('other');

  const LaborPaymentMode(this.value);
  final String value;
}

@immutable
class LaborerDraft {
  const LaborerDraft({
    required this.name,
    this.phone,
    this.address,
    this.laborType = LaborType.worker,
    this.defaultWorkType = LaborWorkType.daywise,
    this.defaultRate = Money.zero,
    this.notes,
  });

  final String name;
  final String? phone;
  final String? address;
  final LaborType laborType;
  final LaborWorkType defaultWorkType;
  final Money defaultRate;
  final String? notes;

  Map<String, Object?> toPayload() => {
        'name': name,
        'phone': phone,
        'address': address,
        'laborType': laborType.value,
        'defaultWorkType': defaultWorkType.value,
        'defaultRatePaise': defaultRate.paise,
        'notes': notes,
      };
}

@immutable
class LaborerRecord {
  const LaborerRecord({
    required this.id,
    required this.companyId,
    required this.name,
    this.phone,
    this.address,
    required this.laborType,
    required this.defaultWorkType,
    required this.defaultRate,
    this.notes,
  });

  final String id;
  final String companyId;
  final String name;
  final String? phone;
  final String? address;
  final LaborType laborType;
  final LaborWorkType defaultWorkType;
  final Money defaultRate;
  final String? notes;
}

@immutable
class LaborWorkEntryDraft {
  const LaborWorkEntryDraft({
    required this.projectId,
    required this.laborId,
    required this.workDate,
    this.workDescription,
    required this.workType,
    required this.quantity,
    this.unit = 'day',
    required this.rate,
    this.paidAmount = Money.zero,
    this.notes,
  });

  final String projectId;
  final String laborId;
  final int workDate;
  final String? workDescription;
  final LaborWorkType workType;
  final DecimalQuantity quantity;
  final String unit;
  final Money rate;
  final Money paidAmount;
  final String? notes;

  Map<String, Object?> toPayload(
          {required Money totalAmount,
          required Money pendingAmount,
          required LaborPaymentStatus paymentStatus}) =>
      {
        'projectId': projectId,
        'laborId': laborId,
        'workDate': workDate,
        'workDescription': workDescription,
        'workType': workType.value,
        'quantity': quantity.toStorageString(),
        'unit': unit,
        'ratePaise': rate.paise,
        'totalAmountPaise': totalAmount.paise,
        'paidAmountPaise': paidAmount.paise,
        'pendingAmountPaise': pendingAmount.paise,
        'paymentStatus': paymentStatus.value,
        'notes': notes,
      };
}

@immutable
class LaborWorkEntryRecord {
  const LaborWorkEntryRecord({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.laborId,
    required this.workDate,
    this.workDescription,
    required this.workType,
    required this.quantity,
    required this.unit,
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
  final String laborId;
  final int workDate;
  final String? workDescription;
  final LaborWorkType workType;
  final DecimalQuantity quantity;
  final String unit;
  final Money rate;
  final Money totalAmount;
  final Money paidAmount;
  final Money pendingAmount;
  final LaborPaymentStatus paymentStatus;
  final String? notes;
}

@immutable
class LaborPaymentDraft {
  const LaborPaymentDraft({
    required this.laborId,
    this.projectId,
    required this.paymentDate,
    required this.amount,
    this.paymentMode = LaborPaymentMode.cash,
    this.referenceNumber,
    this.notes,
  });

  final String laborId;
  final String? projectId;
  final int paymentDate;
  final Money amount;
  final LaborPaymentMode paymentMode;
  final String? referenceNumber;
  final String? notes;
}

@immutable
class LaborAdvanceDraft {
  const LaborAdvanceDraft({
    required this.laborId,
    this.projectId,
    required this.advanceDate,
    required this.amount,
    this.recoveredAmount = Money.zero,
    this.notes,
  });

  final String laborId;
  final String? projectId;
  final int advanceDate;
  final Money amount;
  final Money recoveredAmount;
  final String? notes;
}

class LaborCalculator {
  const LaborCalculator();

  LaborWorkTotals calculateEntry(LaborWorkEntryDraft draft) {
    if (draft.quantity.isZero || draft.quantity.isNegative) {
      throw ArgumentError.value(draft.quantity, 'quantity',
          'Labor quantity must be greater than zero.');
    }
    if (draft.rate.paise < 0 || draft.paidAmount.paise < 0) {
      throw ArgumentError('Labor rate and paid amount cannot be negative.');
    }
    final total = draft.quantity.multiplyMoney(draft.rate);
    if (draft.paidAmount.paise > total.paise) {
      throw ArgumentError.value(draft.paidAmount, 'paidAmount',
          'Paid amount cannot exceed labor total.');
    }
    final pending = total - draft.paidAmount;
    final status = pending.isZero
        ? LaborPaymentStatus.paid
        : draft.paidAmount.isZero
            ? LaborPaymentStatus.unpaid
            : LaborPaymentStatus.partial;
    return LaborWorkTotals(
        totalAmount: total, pendingAmount: pending, paymentStatus: status);
  }

  Money calculateAdvanceBalance(LaborAdvanceDraft draft) {
    if (draft.amount.paise < 0 || draft.recoveredAmount.paise < 0) {
      throw ArgumentError('Advance amount cannot be negative.');
    }
    if (draft.recoveredAmount.paise > draft.amount.paise) {
      throw ArgumentError.value(draft.recoveredAmount, 'recoveredAmount',
          'Recovered amount cannot exceed advance amount.');
    }
    return draft.amount - draft.recoveredAmount;
  }
}

@immutable
class LaborWorkTotals {
  const LaborWorkTotals(
      {required this.totalAmount,
      required this.pendingAmount,
      required this.paymentStatus});

  final Money totalAmount;
  final Money pendingAmount;
  final LaborPaymentStatus paymentStatus;
}
