/// Duong dan man hinh (tach rieng de cac man hinh dung chung ma khong import vong voi router).
class AppRoutes {
  static const login = '/login';
  static const counter = '/counter';
  static const ledger = '/ledger';
  static const debts = '/debts';
  static String debtDetail(String customerId) => '/debts/$customerId';
  static const settlement = '/settlement';
  static const more = '/more';

  static const customers = '/customers';
  static const customerNew = '/customers/new';
  static String customerEdit(String id) => '/customers/$id';
  static const products = '/products';
  static const batches = '/batches';
  static const marketCash = '/market-cash';
  static const account = '/account';
}
