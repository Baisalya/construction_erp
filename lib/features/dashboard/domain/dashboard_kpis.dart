import '../../../core/value_objects/money.dart';

class DashboardKpis {
  const DashboardKpis({
    required this.activeTenders,
    required this.selectedTenders,
    required this.runningProjects,
    required this.pendingSupplier,
    required this.pendingLabor,
    required this.pendingMachinery,
    required this.totalProjectValue,
    required this.totalExpense,
    required this.profitByAgreement,
    required this.gstInput,
    required this.gstOutput,
  });

  final int activeTenders;
  final int selectedTenders;
  final int runningProjects;
  final Money pendingSupplier;
  final Money pendingLabor;
  final Money pendingMachinery;
  final Money totalProjectValue;
  final Money totalExpense;
  final Money profitByAgreement;
  final Money gstInput;
  final Money gstOutput;
}
