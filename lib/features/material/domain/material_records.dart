import 'package:flutter/foundation.dart';

import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';

enum MaterialPaymentStatus {
  unpaid('unpaid'),
  partial('partial'),
  paid('paid');

  const MaterialPaymentStatus(this.value);
  final String value;

  static MaterialPaymentStatus fromValue(String value) {
    return values.firstWhere((item) => item.value == value,
        orElse: () => unpaid);
  }
}

enum PaymentMode {
  cash('cash'),
  bank('bank'),
  upi('upi'),
  cheque('cheque'),
  other('other');

  const PaymentMode(this.value);
  final String value;

  static PaymentMode fromValue(String? value) {
    return values.firstWhere((item) => item.value == value, orElse: () => cash);
  }
}

@immutable
class SupplierDraft {
  const SupplierDraft({
    required this.supplierName,
    this.contactPerson,
    this.phone,
    this.gstNumber,
    this.address,
    this.openingBalance = Money.zero,
    this.notes,
  });

  final String supplierName;
  final String? contactPerson;
  final String? phone;
  final String? gstNumber;
  final String? address;
  final Money openingBalance;
  final String? notes;

  Map<String, Object?> toPayload() => {
        'supplierName': supplierName,
        'contactPerson': contactPerson,
        'phone': phone,
        'gstNumber': gstNumber,
        'address': address,
        'openingBalancePaise': openingBalance.paise,
        'notes': notes,
      };
}

@immutable
class SupplierRecord {
  const SupplierRecord({
    required this.id,
    required this.companyId,
    required this.supplierName,
    this.contactPerson,
    this.phone,
    this.gstNumber,
    this.address,
    required this.openingBalance,
    this.notes,
  });

  final String id;
  final String companyId;
  final String supplierName;
  final String? contactPerson;
  final String? phone;
  final String? gstNumber;
  final String? address;
  final Money openingBalance;
  final String? notes;
}

@immutable
class MaterialPurchaseItemDraft {
  const MaterialPurchaseItemDraft({
    required this.materialName,
    this.details,
    this.unit = 'piece',
    required this.quantity,
    required this.rate,
    this.gstRateBasisPoints = 0,
  });

  final String materialName;
  final String? details;
  final String unit;
  final DecimalQuantity quantity;
  final Money rate;
  final int gstRateBasisPoints;

  Map<String, Object?> toPayload(
          {required Money amount,
          required Money gstAmount,
          required Money totalAmount}) =>
      {
        'materialName': materialName,
        'details': details,
        'unit': unit,
        'quantity': quantity.toStorageString(),
        'ratePaise': rate.paise,
        'amountPaise': amount.paise,
        'gstRateBasisPoints': gstRateBasisPoints,
        'gstAmountPaise': gstAmount.paise,
        'totalAmountPaise': totalAmount.paise,
      };
}

@immutable
class MaterialPurchaseItemRecord {
  const MaterialPurchaseItemRecord({
    required this.id,
    required this.purchaseId,
    required this.projectId,
    required this.materialName,
    this.details,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.gstRateBasisPoints,
    required this.gstAmount,
    required this.totalAmount,
  });

  final String id;
  final String purchaseId;
  final String projectId;
  final String materialName;
  final String? details;
  final String unit;
  final DecimalQuantity quantity;
  final Money rate;
  final Money amount;
  final int gstRateBasisPoints;
  final Money gstAmount;
  final Money totalAmount;
}

@immutable
class MaterialPurchaseDraft {
  const MaterialPurchaseDraft({
    required this.projectId,
    this.supplierId,
    required this.purchaseDate,
    this.billNumber,
    this.invoiceNumber,
    this.vehicleNumber,
    this.deliveryLocation,
    required this.items,
    this.paidAmount = Money.zero,
    this.notes,
    this.billImagePath,
  });

  final String projectId;
  final String? supplierId;
  final int purchaseDate;
  final String? billNumber;
  final String? invoiceNumber;
  final String? vehicleNumber;
  final String? deliveryLocation;
  final List<MaterialPurchaseItemDraft> items;
  final Money paidAmount;
  final String? notes;
  final String? billImagePath;
}

@immutable
class MaterialPurchaseRecord {
  const MaterialPurchaseRecord({
    required this.id,
    required this.companyId,
    required this.projectId,
    this.supplierId,
    required this.purchaseDate,
    this.billNumber,
    this.invoiceNumber,
    this.vehicleNumber,
    this.deliveryLocation,
    required this.totalBeforeTax,
    required this.gstAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentStatus,
    this.notes,
    this.billImagePath,
    this.items = const <MaterialPurchaseItemRecord>[],
  });

  final String id;
  final String companyId;
  final String projectId;
  final String? supplierId;
  final int purchaseDate;
  final String? billNumber;
  final String? invoiceNumber;
  final String? vehicleNumber;
  final String? deliveryLocation;
  final Money totalBeforeTax;
  final Money gstAmount;
  final Money totalAmount;
  final Money paidAmount;
  final Money pendingAmount;
  final MaterialPaymentStatus paymentStatus;
  final String? notes;
  final String? billImagePath;
  final List<MaterialPurchaseItemRecord> items;
}

@immutable
class SupplierPaymentDraft {
  const SupplierPaymentDraft({
    required this.supplierId,
    this.projectId,
    this.purchaseId,
    required this.paymentDate,
    required this.amount,
    this.paymentMode = PaymentMode.cash,
    this.referenceNumber,
    this.notes,
  });

  final String supplierId;
  final String? projectId;
  final String? purchaseId;
  final int paymentDate;
  final Money amount;
  final PaymentMode paymentMode;
  final String? referenceNumber;
  final String? notes;

  Map<String, Object?> toPayload() => {
        'supplierId': supplierId,
        'projectId': projectId,
        'purchaseId': purchaseId,
        'paymentDate': paymentDate,
        'amountPaise': amount.paise,
        'paymentMode': paymentMode.value,
        'referenceNumber': referenceNumber,
        'notes': notes,
      };
}

@immutable
class MaterialTotals {
  const MaterialTotals({
    required this.totalBeforeTax,
    required this.gstAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentStatus,
  });

  final Money totalBeforeTax;
  final Money gstAmount;
  final Money totalAmount;
  final Money paidAmount;
  final Money pendingAmount;
  final MaterialPaymentStatus paymentStatus;
}

class MaterialCalculator {
  const MaterialCalculator();

  MaterialPurchaseItemTotals calculateItem(MaterialPurchaseItemDraft item) {
    final amount = item.quantity.multiplyMoney(item.rate);
    final gstAmount = Money.fromPaise((BigInt.from(amount.paise) *
            BigInt.from(item.gstRateBasisPoints) ~/
            BigInt.from(10000))
        .toInt());
    return MaterialPurchaseItemTotals(
        amount: amount, gstAmount: gstAmount, totalAmount: amount + gstAmount);
  }

  MaterialTotals calculatePurchase(
      List<MaterialPurchaseItemDraft> items, Money paidAmount) {
    if (items.isEmpty) {
      throw ArgumentError('At least one material item is required.');
    }
    var beforeTax = Money.zero;
    var gst = Money.zero;
    var total = Money.zero;
    for (final item in items) {
      final itemTotals = calculateItem(item);
      beforeTax += itemTotals.amount;
      gst += itemTotals.gstAmount;
      total += itemTotals.totalAmount;
    }
    if (paidAmount.paise < 0) {
      throw ArgumentError.value(
          paidAmount, 'paidAmount', 'Paid amount cannot be negative.');
    }
    if (paidAmount.paise > total.paise) {
      throw ArgumentError.value(
          paidAmount, 'paidAmount', 'Paid amount cannot exceed total amount.');
    }
    final pending = total - paidAmount;
    final status = pending.isZero
        ? MaterialPaymentStatus.paid
        : paidAmount.isZero
            ? MaterialPaymentStatus.unpaid
            : MaterialPaymentStatus.partial;
    return MaterialTotals(
      totalBeforeTax: beforeTax,
      gstAmount: gst,
      totalAmount: total,
      paidAmount: paidAmount,
      pendingAmount: pending,
      paymentStatus: status,
    );
  }
}

@immutable
class MaterialPurchaseItemTotals {
  const MaterialPurchaseItemTotals(
      {required this.amount,
      required this.gstAmount,
      required this.totalAmount});

  final Money amount;
  final Money gstAmount;
  final Money totalAmount;
}
