class FirebaseCompanyGateway {
  const FirebaseCompanyGateway._();

  factory FirebaseCompanyGateway.placeholder() =>
      const FirebaseCompanyGateway._();

  String companyDocumentPath(String companyId) => 'companies/$companyId';

  String staffDocumentPath(String companyId, String staffId) {
    return 'companies/$companyId/staff/$staffId';
  }

  String syncDeltaCollectionPath(String companyId) {
    return 'companies/$companyId/sync_deltas';
  }

  String deviceDocumentPath(String companyId, String deviceId) {
    return 'companies/$companyId/devices/$deviceId';
  }
}
