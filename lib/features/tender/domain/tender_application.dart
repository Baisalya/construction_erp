import 'package:flutter/foundation.dart';

import '../../../core/value_objects/money.dart';
import 'tender_status.dart';

@immutable
class TenderDraft {
  const TenderDraft({
    required this.tenderTitle,
    this.bidderProfileId,
    this.tenderNumber,
    this.departmentName,
    this.clientName,
    this.location,
    this.tenderType,
    this.tenderCategory,
    this.applicationDate,
    this.submissionDate,
    this.openingDate,
    this.resultDate,
    this.estimatedTenderValue = Money.zero,
    this.quotedTenderPrice = Money.zero,
    this.emdAmount = Money.zero,
    this.tenderFee = Money.zero,
    this.documentFee = Money.zero,
    this.processingCost = Money.zero,
    this.otherApplicationCost = Money.zero,
    this.status = TenderStatus.draft,
    this.selectedDate,
    this.rejectionReason,
    this.notes,
  });

  final String tenderTitle;
  final String? bidderProfileId;
  final String? tenderNumber;
  final String? departmentName;
  final String? clientName;
  final String? location;
  final String? tenderType;
  final String? tenderCategory;
  final int? applicationDate;
  final int? submissionDate;
  final int? openingDate;
  final int? resultDate;
  final Money estimatedTenderValue;
  final Money quotedTenderPrice;
  final Money emdAmount;
  final Money tenderFee;
  final Money documentFee;
  final Money processingCost;
  final Money otherApplicationCost;
  final TenderStatus status;
  final int? selectedDate;
  final String? rejectionReason;
  final String? notes;

  int get inlineApplicationCostPaise {
    return tenderFee.paise +
        documentFee.paise +
        processingCost.paise +
        otherApplicationCost.paise;
  }

  Map<String, Object?> toPayload() {
    return {
      'tenderTitle': tenderTitle,
      'bidderProfileId': bidderProfileId,
      'tenderNumber': tenderNumber,
      'departmentName': departmentName,
      'clientName': clientName,
      'location': location,
      'tenderType': tenderType,
      'tenderCategory': tenderCategory,
      'applicationDate': applicationDate,
      'submissionDate': submissionDate,
      'openingDate': openingDate,
      'resultDate': resultDate,
      'estimatedTenderValuePaise': estimatedTenderValue.paise,
      'quotedTenderPricePaise': quotedTenderPrice.paise,
      'emdAmountPaise': emdAmount.paise,
      'tenderFeePaise': tenderFee.paise,
      'documentFeePaise': documentFee.paise,
      'processingCostPaise': processingCost.paise,
      'otherApplicationCostPaise': otherApplicationCost.paise,
      'status': status.value,
      'selectedDate': selectedDate,
      'rejectionReason': rejectionReason,
      'notes': notes,
    };
  }
}

@immutable
class TenderApplication {
  const TenderApplication({
    required this.id,
    required this.companyId,
    required this.tenderTitle,
    required this.status,
    this.bidderProfileId,
    this.tenderNumber,
    this.departmentName,
    this.clientName,
    this.location,
    this.tenderType,
    this.tenderCategory,
    this.applicationDate,
    this.submissionDate,
    this.openingDate,
    this.resultDate,
    this.estimatedTenderValue = Money.zero,
    this.quotedTenderPrice = Money.zero,
    this.emdAmount = Money.zero,
    this.tenderFee = Money.zero,
    this.documentFee = Money.zero,
    this.processingCost = Money.zero,
    this.otherApplicationCost = Money.zero,
    this.selectedDate,
    this.rejectionReason,
    this.notes,
    this.version = 1,
  });

  final String id;
  final String companyId;
  final String tenderTitle;
  final TenderStatus status;
  final String? bidderProfileId;
  final String? tenderNumber;
  final String? departmentName;
  final String? clientName;
  final String? location;
  final String? tenderType;
  final String? tenderCategory;
  final int? applicationDate;
  final int? submissionDate;
  final int? openingDate;
  final int? resultDate;
  final Money estimatedTenderValue;
  final Money quotedTenderPrice;
  final Money emdAmount;
  final Money tenderFee;
  final Money documentFee;
  final Money processingCost;
  final Money otherApplicationCost;
  final int? selectedDate;
  final String? rejectionReason;
  final String? notes;
  final int version;

  int get inlineApplicationCostPaise {
    return tenderFee.paise +
        documentFee.paise +
        processingCost.paise +
        otherApplicationCost.paise;
  }
}
