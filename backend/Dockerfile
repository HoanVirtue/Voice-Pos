# Build context: thư mục backend/ (xem docker-compose.yml: build: ./backend)
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

WORKDIR /src
COPY global.json BanHang.sln ./
COPY BanHang.SharedKernel/BanHang.SharedKernel.csproj BanHang.SharedKernel/
COPY BanHang.Domain/BanHang.Domain.csproj BanHang.Domain/
COPY BanHang.BuildingBlocks/BanHang.BuildingBlocks.csproj BanHang.BuildingBlocks/
COPY BanHang.Application/BanHang.Application.csproj BanHang.Application/
COPY BanHang.Infrastructure/BanHang.Infrastructure.csproj BanHang.Infrastructure/
COPY BanHang.WebAPI/BanHang.WebAPI.csproj BanHang.WebAPI/
COPY BanHang.Tests/BanHang.Tests.csproj BanHang.Tests/
RUN dotnet restore BanHang.WebAPI/BanHang.WebAPI.csproj

COPY . ./
RUN dotnet publish BanHang.WebAPI/BanHang.WebAPI.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime

# Múi giờ Việt Nam (UTC+7) — tránh lệch 7 tiếng khi container mặc định UTC.
ENV TZ=Asia/Ho_Chi_Minh
RUN apt-get update \
    && apt-get install -y --no-install-recommends tzdata \
    && ln -sf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "BanHang.WebAPI.dll"]
