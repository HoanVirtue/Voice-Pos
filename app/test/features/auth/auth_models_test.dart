import 'package:banhang_app/core/auth/permissions.dart';
import 'package:banhang_app/features/auth/data/models/auth_models.dart';
import 'package:banhang_app/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LoginResponse doc LoginResultDto cua BE', () {
    final r = LoginResponse.fromJson({
      'userId': 7,
      'username': 'seller1',
      'role': 'Seller',
      'accessToken': 'a',
      'expiresAtUtc': '2030-01-01T00:00:00Z',
      'refreshToken': 'r',
      'refreshTokenExpiresAtUtc': '2030-02-01T00:00:00Z',
      'displayName': 'Cô Hoa',
    });
    expect(r.accessToken, 'a');
    expect(r.refreshToken, 'r');
    expect(r.expiresAt, '2030-01-01T00:00:00Z');
    expect(r.user.id, '7');
    expect(r.user.role, 'Seller');
    expect(r.user.displayName, 'Cô Hoa');
  });

  test('displayName rong/null -> dung username', () {
    final r = LoginResponse.fromJson({
      'userId': 1,
      'username': 'u',
      'role': 'Admin',
      'accessToken': 'a',
      'displayName': null,
    });
    expect(r.user.displayName, 'u');
  });

  test('UserModel luu/doc lai khong mat truong', () {
    const u = UserModel(id: '1', username: 'u', displayName: 'U', role: 'Admin');
    expect(UserModel.fromJson(u.toJson()), u);
  });

  test('RefreshTokenRequest chi gui refreshToken', () {
    expect(const RefreshTokenRequest(refreshToken: 'x').toJson(), {'refreshToken': 'x'});
  });

  test('quyen suy tu role: Admin tat ca, Seller khong co Users.Manage', () {
    final admin = PermissionSet.fromRole('Admin');
    final seller = PermissionSet.fromRole('Seller');
    expect(Perm.all.every(admin.has), isTrue);
    expect(seller.has(Perm.customersManage), isTrue);
    expect(seller.has(Perm.voiceUse), isTrue);
    expect(seller.has(Perm.reportsView), isTrue);
    expect(seller.has(Perm.usersManage), isFalse);
    expect(PermissionSet.fromRole('Khac').codes, isEmpty);
  });

  test('PermissionSet.fromMine: danh sach ma, IsFullBypass, bo ma la', () {
    final s = PermissionSet.fromMine({
      'isFullBypass': false,
      'permissions': [Perm.customersView, 'BanHang.Khong.Biet'],
    });
    expect(s.codes, {Perm.customersView});
    expect(PermissionSet.fromMine({'isFullBypass': true, 'permissions': []})
        .has(Perm.usersManage), isTrue);
  });
}
