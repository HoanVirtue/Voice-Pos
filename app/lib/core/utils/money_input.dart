import '../../features/transactions/parser/market_parser.dart' show parseMoneyText;
import 'vn_format.dart';

/// Doc so tien nguoi dung go/noi vao o nhap:
/// - "380.000", "1.200.000", "500 đ" -> dung so dong do;
/// - so tron tu 5 chu so tro len ("380000") -> dong;
/// - con lai theo cach noi o cho: "380" = 380.000, "ba trăm tám", "1,2 triệu", "380k".
/// Tra null neu rong hoac khong doc duoc.
int? parseMoneyInput(String text) {
  final t = text.trim().toLowerCase();
  if (t.isEmpty) return null;
  if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) return int.parse(t.replaceAll('.', ''));
  final suffixed = RegExp(r'^(\d[\d.,]*)\s*(đ|d|đồng|dong|vnd)$').firstMatch(t);
  if (suffixed != null) {
    final digits = suffixed.group(1)!.replaceAll(RegExp(r'[.,]'), '');
    return int.tryParse(digits);
  }
  if (RegExp(r'^\d{5,}$').hasMatch(t)) return int.parse(t);
  return parseMoneyText(t);
}

/// Chuoi dua vao o nhap de doc nguoc lai dung (xem [parseMoneyInput]).
String moneyToInputText(int? v) {
  if (v == null) return '';
  if (v < 1000) return '$v đ';
  return formatMoney(v).replaceAll(' đ', '');
}

/// Doc khoi luong kg go tay ("2,5", "2.5", "1") -> gram. Null neu rong/sai.
int? parseWeightInputGram(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v < 0) return null;
  return (v * 1000).round();
}

/// Gram -> chuoi kg de dua vao o nhap ("2,5").
String gramToKgInputText(int? gram) {
  if (gram == null) return '';
  final kg = gram / 1000;
  if (kg == kg.roundToDouble()) return kg.round().toString();
  return kg.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
}
