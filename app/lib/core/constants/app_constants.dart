class AppConstants {
  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String tokenExpiryKey = 'token_expiry';
  static const String userKey = 'user_data';
  static const String rememberMeKey = 'remember_me';

  // API endpoints (BE: /api/v1/..., envelope ActionResponse<T>)
  static const String loginEndpoint = '/api/v1/Auth/login';
  static const String refreshEndpoint = '/api/v1/Auth/refresh';
  static const String logoutEndpoint = '/api/v1/Auth/logout';
  static const String customersEndpoint = '/api/v1/Customers';
  static String customerEndpoint(String id) => '/api/v1/Customers/$id';
  static const String productsEndpoint = '/api/v1/Products';
  static const String batchesEndpoint = '/api/v1/Batches';
  static const String transactionsEndpoint = '/api/v1/Transactions';
  static const String settlementsEndpoint = '/api/v1/DaySettlements';
  static const String sttTokenEndpoint = '/api/v1/Voice/stt-token';
  static const String myPermissionsEndpoint = '/api/v1/Permission/Mine';

  // Timeouts
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 15000;
  static const int sendTimeoutMs = 10000;

  // Validation
  static const int minPasswordLength = 6;
  static const String phoneRegex = r'^0[35789][0-9]{8}$';

  // Sync
  static const int syncPageSize = 100;
  static const int outboxMaxAttempts = 5;
}
