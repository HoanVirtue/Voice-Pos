# Hợp đồng API: Món hàng, Lô hàng, Giao dịch, Chốt sổ, Báo cáo

Quy ước chung (giống Customers): route `api/v1/<Tên>`, phản hồi `ActionResponse<T>`, Id Guid do client sinh, POST/PUT upsert idempotent,
DELETE xóa mềm idempotent, thời gian UTC có hậu tố Z, tiền `long` đồng, khối lượng `int` gram.
Danh sách: `GET ?updatedSince=&includeDeleted=&pageIndex=&pageSize=` (sắp theo UpdatedAt tăng dần khi có updatedSince), kèm `isDeleted`, `updatedAt` trong DTO.
Quyền: Products/Batches/Transactions/DaySettlements dùng `Transactions.View` (GET) và `Transactions.Manage` (POST/PUT/DELETE); Reports dùng `Reports.View`.
Seller (bố/mẹ) phải có cả 3 quyền này mặc định.

## Products — `api/v1/Products`
DTO: `{ id, name, alias?, pricePerKg (long), updatedAt, isDeleted }`
Upsert body: `{ id, name, alias?, pricePerKg }` (name 1..100, pricePerKg >= 0)

## Batches (lô hàng = con lợn) — `api/v1/Batches`
DTO: `{ id, date ("yyyy-MM-dd", ngày VN), pigCount (int), liveWeightGram? (int), carcassWeightGram? (int), buyCost (long), otherCost (long), note?, updatedAt, isDeleted }`
Upsert body: cùng trường, trừ updatedAt/isDeleted. pigCount >= 0, các số tiền >= 0.

## Transactions — `api/v1/Transactions`
DTO:
```
{ id, occurredAt (UTC), type, customerId?, productId?, batchId?, weightGram? (int), amount (long),
  paidAmount (long), rawText?, confidence? (0..1 double), note?, updatedAt, isDeleted }
```
`type` là chuỗi: `Sale` (bán), `DebtPayment` (thu nợ), `BuyPig` (mua lợn), `Expense` (chi khác), `CashOut` (mang tiền đi chợ).
Ý nghĩa `amount`/`paidAmount`:
- Sale: amount = tổng tiền bán, paidAmount = đã trả ngay (nợ = amount − paidAmount, 0 <= paidAmount <= amount). Bắt buộc customerId nếu nợ > 0.
- DebtPayment: amount = số tiền khách trả nợ; paidAmount = amount; bắt buộc customerId.
- BuyPig / Expense / CashOut: amount = số tiền chi (paidAmount = amount); BuyPig có thể kèm batchId.
Validate: type hợp lệ, amount >= 0, weightGram >= 0, rawText <= 1000, note <= 1000.
Danh sách lọc thêm: `from=` `to=` (UTC), `customerId=`, `type=`.

## DaySettlements (chốt sổ ngày) — `api/v1/DaySettlements`
DTO: `{ id, date ("yyyy-MM-dd", ngày VN), openingCash (long), countedCash (long), expectedCash (long), difference (long = countedCash − expectedCash), note?, updatedAt, isDeleted }`
Upsert body: `{ id, date, openingCash, countedCash, note? }`; server tự tính `expectedCash` theo công thức Báo cáo ngày và `difference`.
Mỗi `date` chỉ một bản ghi chưa xóa: upsert với id khác nhưng cùng date → 409 (unique).

## Reports — `api/v1/Reports` (chỉ đọc, `Reports.View`)
- `GET Reports/Daily?date=yyyy-MM-dd&openingCash=0` →
  `{ date, revenue, cashSales, newDebt, debtCollected, cashIn (=cashSales+debtCollected), buyPigCost, expenseCost, cashOut, cashInHand (=openingCash+cashIn-buyPigCost-expenseCost-cashOut), transactionCount }`
  Ngày tính theo giờ VN (UTC+7): [00:00,24:00) VN của `date`.
  `cashOut` (tiền mang đi chợ) là tiền chuyển khỏi két, trừ vào cashInHand như chi.
- `GET Reports/Debts` → `[{ customerId, customerName, totalSale, totalPaid, totalDebtPayment, debt (= totalSale − totalPaid − totalDebtPayment) }]` chỉ khách có debt != 0, sắp debt giảm dần.
- `GET Reports/Debts/{customerId}` → `{ customerId, customerName, debt, items: [{transactionId, occurredAt, type, amount, paidAmount, debtDelta}] }`.
- `GET Reports/MarketCash?pigCount=&pigPrice=&supplierDebt=&reservePercent=10` → `{ pigCost, supplierDebt, reserve, total }` (total = pigCost + supplierDebt + reserve, reserve = round(pigCost*percent/100), pigCost = pigCount*pigPrice).
- `GET Reports/BatchProfit/{batchId}` → `{ batchId, revenue (tổng Sale có batchId), buyCost, otherCost, profit = revenue − buyCost − otherCost }`.

## Đồng bộ ở app
Giống Customers: drift table + outbox (ghi local → outbox → POST/PUT/DELETE), kéo thay đổi bằng `updatedSince`+`includeDeleted=true`.
Báo cáo/công nợ app tính cục bộ từ dữ liệu drift (offline) theo cùng công thức; gọi API Reports chỉ khi cần đối chiếu.
