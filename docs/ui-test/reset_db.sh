#!/bin/bash
# Reset DB dev local (CHỈ dùng cho test): xóa và tạo lại `banhang`; API tự migrate + seed khi khởi động.
# Mật khẩu root MySQL lấy từ biến môi trường MYSQL_ROOT_PASSWORD hoặc từ .env ở gốc repo.
cd "$(dirname "$0")/../.."
PW="${MYSQL_ROOT_PASSWORD:-$(grep -E '^MYSQL_ROOT_PASSWORD=' .env 2>/dev/null | cut -d= -f2-)}"
[ -z "$PW" ] && { echo "Thiếu MYSQL_ROOT_PASSWORD (env hoặc .env)"; exit 1; }
MYSQL_PWD="$PW" mysql -uroot -e "DROP DATABASE IF EXISTS banhang; CREATE DATABASE banhang CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
