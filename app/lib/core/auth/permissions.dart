/// Ma quyen khop voi BE (`SystemPermissions`, tra ve boi `GET /Permission/Mine`).
class Perm {
  Perm._();

  static const customersView = 'BanHang.Customers.Customer.View';
  static const customersManage = 'BanHang.Customers.Customer.Manage';
  static const transactionsView = 'BanHang.Transactions.Transaction.View';
  static const transactionsManage = 'BanHang.Transactions.Transaction.Manage';
  static const reportsView = 'BanHang.Reports.Report.View';
  static const usersManage = 'BanHang.Users.User.Manage';
  static const voiceUse = 'BanHang.Voice.Voice.Use';

  static const all = <String>[
    customersView,
    customersManage,
    transactionsView,
    transactionsManage,
    reportsView,
    usersManage,
    voiceUse,
  ];
}

/// Quyen cua phien hien tai.
class PermissionSet {
  final Set<String> _codes;

  /// True khi quyen duoc suy ra tu `role` (chua lay duoc `/Permission/Mine`).
  final bool fromFallback;

  const PermissionSet(this._codes, {this.fromFallback = false});

  static const empty = PermissionSet(<String>{});

  bool has(String code) => _codes.contains(code);
  bool hasAny(Iterable<String> codes) => codes.any(_codes.contains);
  Set<String> get codes => Set.unmodifiable(_codes);

  /// Doc `result` cua `GET /Permission/Mine` (`MyPermissionsDto`):
  /// `{ userId, username, roleId, roleKey, roleDisplayName, isFullBypass, permissions[] }`.
  factory PermissionSet.fromMine(Map<String, dynamic> json) {
    if (json['isFullBypass'] == true) return PermissionSet(Perm.all.toSet());
    final list = (json['permissions'] as List?)?.whereType<String>() ?? const [];
    return PermissionSet(list.where(Perm.all.contains).toSet());
  }

  /// Du phong khi chua goi duoc `/Permission/Mine` (mat mang...): Admin = tat ca;
  /// Seller = khach, giao dich, xem bao cao, giong noi. May chu moi la noi chan that.
  factory PermissionSet.fromRole(String? role) {
    switch (role) {
      case 'Admin':
        return PermissionSet(Perm.all.toSet(), fromFallback: true);
      case 'Seller':
        return const PermissionSet(
          {
            Perm.customersView,
            Perm.customersManage,
            Perm.transactionsView,
            Perm.transactionsManage,
            Perm.reportsView,
            Perm.voiceUse,
          },
          fromFallback: true,
        );
      default:
        return const PermissionSet(<String>{}, fromFallback: true);
    }
  }

  @override
  String toString() =>
      'PermissionSet(${_codes.length}${fromFallback ? ', suy từ role' : ''})';
}
