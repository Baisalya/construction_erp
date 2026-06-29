import 'package:flutter/foundation.dart';

import '../../../core/value_objects/money.dart';

enum ProjectExpenseCategory {
  office,
  transport,
  food,
  site,
  document,
  rent,
  electricity,
  custom;

  String get label => switch (this) {
        office => 'Office',
        transport => 'Transport',
        food => 'Food',
        site => 'Site',
        document => 'Document',
        rent => 'Rent',
        electricity => 'Electricity',
        custom => 'Custom',
      };

  static ProjectExpenseCategory fromValue(String value) =>
      values.firstWhere((item) => item.name == value,
          orElse: () => ProjectExpenseCategory.custom);
}

@immutable
class WorkDayDraft {
  const WorkDayDraft({
    required this.projectId,
    required this.workDate,
    this.siteName,
    this.weather,
    this.notes,
  });

  final String projectId;
  final int workDate;
  final String? siteName;
  final String? weather;
  final String? notes;

  Map<String, Object?> toPayload() => {
        'projectId': projectId,
        'workDate': workDate,
        'siteName': siteName,
        'weather': weather,
        'notes': notes,
      };
}

@immutable
class WorkDayRecord {
  const WorkDayRecord({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.workDate,
    this.siteName,
    this.weather,
    this.notes,
  });

  final String id;
  final String companyId;
  final String projectId;
  final int workDate;
  final String? siteName;
  final String? weather;
  final String? notes;
}

@immutable
class ProjectExpenseDraft {
  const ProjectExpenseDraft({
    required this.projectId,
    required this.expenseDate,
    required this.category,
    this.description,
    required this.amount,
    this.paidAmount = Money.zero,
    this.paymentMode,
    this.notes,
  });

  final String projectId;
  final int expenseDate;
  final ProjectExpenseCategory category;
  final String? description;
  final Money amount;
  final Money paidAmount;
  final String? paymentMode;
  final String? notes;

  Money get pendingAmount => amount - paidAmount;

  Map<String, Object?> toPayload() => {
        'projectId': projectId,
        'expenseDate': expenseDate,
        'expenseCategory': category.name,
        'description': description,
        'amountPaise': amount.paise,
        'paidAmountPaise': paidAmount.paise,
        'pendingAmountPaise': pendingAmount.paise,
        'paymentMode': paymentMode,
        'notes': notes,
      };
}

@immutable
class ProjectExpenseRecord {
  const ProjectExpenseRecord({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.expenseDate,
    required this.category,
    this.description,
    required this.amount,
    required this.paidAmount,
    required this.pendingAmount,
    this.paymentMode,
    this.notes,
  });

  final String id;
  final String companyId;
  final String projectId;
  final int expenseDate;
  final ProjectExpenseCategory category;
  final String? description;
  final Money amount;
  final Money paidAmount;
  final Money pendingAmount;
  final String? paymentMode;
  final String? notes;
}
