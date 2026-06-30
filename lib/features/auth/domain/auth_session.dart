import '../../staff/domain/staff_access_policy.dart';
import 'app_user.dart';
import 'company_profile.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    this.company,
    this.accessPolicy,
  });

  final AppUser user;
  final CompanyProfile? company;
  final StaffAccessPolicy? accessPolicy;

  bool get hasCompany => company != null;
  bool get canOpenApp => accessPolicy?.isActive == true;
}
