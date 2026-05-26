# Development Log

이 문서는 SRS/SDD 기반 구현 과정에서 발생한 개발 변경 사항을 누적 기록한다.

## 기록 원칙

- 모든 코드/DB/API 구조 변경은 날짜별로 추가한다.
- 각 항목에는 변경 목적, 주요 수정 파일, 검증 결과, 남은 작업을 기록한다.
- 구현 세부사항은 SRS/SDD 용어와 최대한 맞춘다.
- 검증하지 못한 사항은 검증 완료처럼 쓰지 않고, 사유를 함께 남긴다.

## 2026-05-21

### 계정 및 관리자 기능 기반 데이터 구조 추가

#### 목적

계정, 인증, 관리자 페이지 구현을 시작하기 위한 백엔드 도메인 기반을 추가했다. 현재 컨트롤러는 SDD API 표면만 placeholder로 제공하는 상태이므로, 이후 서비스 계층에서 실제 로직을 연결할 수 있도록 JPA Entity, Enum, Repository를 먼저 구성했다.

#### 주요 변경 사항

- 사용자 계정 도메인 추가
  - `users` 테이블에 대응하는 `User` Entity 추가
  - 사용자 역할 `UserRole` 추가: `USER`, `ADMIN`
  - 계정 상태 `UserStatus` 추가: `ACTIVE`, `SUSPENDED`, `BANNED`
  - 이메일 조회 및 중복 확인을 위한 `UserRepository` 추가

- 회원가입/인증 도메인 추가
  - `pending_signups` 테이블에 대응하는 `PendingSignup` Entity 추가
  - OTP 재발급/검증 흐름에서 사용할 상태 갱신 메서드 추가
  - `password_reset_tokens` 테이블에 대응하는 `PasswordResetToken` Entity 추가
  - `PendingSignupRepository`, `PasswordResetTokenRepository` 추가

- 관리자 도메인 추가
  - 신고 상태 `ReportStatus` 추가: `OPEN`, `UNDER_REVIEW`, `RESOLVED`
  - 조정 조치 유형 `ModerationActionType` 추가: `WARNING`, `SUSPEND`, `BAN`, `UNSUSPEND`
  - `reports` 테이블에 대응하는 `Report` Entity 추가
  - `moderation_actions` 테이블에 대응하는 `ModerationAction` Entity 추가
  - `admin_audit_logs` 테이블에 대응하는 `AdminAuditLog` Entity 추가
  - 각 도메인에 대한 Repository 추가

- DB 마이그레이션 보강
  - `moderation_actions.reason`을 `NOT NULL`로 변경
  - `moderation_actions.starts_at`, `moderation_actions.ends_at` 추가
  - `moderation_actions.action_type` 체크 제약 추가
  - `admin_audit_logs.metadata_json JSONB` 추가
  - 관리자 조회 성능을 위한 인덱스 추가

#### 수정 파일

- `backend/src/main/resources/db/migration/V1__initial_schema.sql`
- `backend/src/main/java/kr/kaist/buddies/user/domain/User.java`
- `backend/src/main/java/kr/kaist/buddies/user/domain/UserRole.java`
- `backend/src/main/java/kr/kaist/buddies/user/domain/UserStatus.java`
- `backend/src/main/java/kr/kaist/buddies/user/domain/UserRepository.java`
- `backend/src/main/java/kr/kaist/buddies/auth/domain/PendingSignup.java`
- `backend/src/main/java/kr/kaist/buddies/auth/domain/PendingSignupRepository.java`
- `backend/src/main/java/kr/kaist/buddies/auth/domain/PasswordResetToken.java`
- `backend/src/main/java/kr/kaist/buddies/auth/domain/PasswordResetTokenRepository.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/Report.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/ReportStatus.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/ReportRepository.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/ModerationAction.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/ModerationActionType.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/ModerationActionRepository.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/AdminAuditLog.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/AdminAuditLogRepository.java`

#### 검증

- `git status --short`로 변경 파일 범위를 확인했다.
- `rg`로 추가된 도메인 클래스와 SQL 변경 위치를 확인했다.
- `mvn -DskipTests compile` 실행을 시도했으나, 현재 환경에서 `mvn` 명령을 찾을 수 없어 컴파일 검증은 수행하지 못했다.
- 프로젝트에는 아직 Maven wrapper가 없다.

#### 남은 작업

- Maven 설치 또는 Maven wrapper 추가 후 컴파일 검증
- `AuthService` 구현
  - 회원가입 요청
  - OTP 검증
  - 로그인
  - JWT 발급
  - 비밀번호 재설정
- `AdminService` 구현
  - 사용자 목록/상세 조회
  - 사용자 정지/차단/해제
  - 신고 해결
  - 감사 로그 기록
- Spring Security에 JWT 인증 필터와 관리자 권한 검사 추가
- 현재 placeholder 컨트롤러를 서비스 계층과 연결

## 2026-05-22

### SDD 업데이트 반영 및 서버-클라이언트 통신 기반 추가

#### 목적

업데이트된 SDD의 DB/API 정리 문서를 기준으로 초기 DB 스키마와 API endpoint 표면을 다시 맞추고, 클라이언트가 서버와 통신할 때 네트워크 호출을 한 곳에서 관리할 수 있도록 공통 API client 기반을 추가했다.

#### 주요 변경 사항

- DB 마이그레이션 재정렬
  - `V1__initial_schema.sql`을 최신 SDD 테이블 목록 기준으로 재작성
  - `delivery_zones`/PostGIS 기반 구조를 제거하고 `lobbies.delivery_location` 기반으로 변경
  - `lobbies`, `lobby_memberships`, `cart_items`, `payment_records`, `chat_messages`, `chat_read_states`, `chat_archives`, `ratings`, `support_tickets`, `reports`, `moderation_actions`, `admin_audit_logs`를 최신 필드명에 맞춤
  - 주요 enum은 PostgreSQL `CHECK` 제약으로 표현
  - SDD 권장 인덱스를 PostgreSQL 형태로 추가
  - 논의가 필요한 cart item 보존 정책, restricted keyword 정책, refresh/logout token 저장 정책은 TODO 주석으로 명시

- 백엔드 API 표면 정리
  - Auth API에 `/auth/refresh` 추가
  - password reset confirm 요청에 `newPasswordConfirm` 추가
  - Profile/Rating/Support DTO를 최신 API 문서에 맞춤
  - Lobby API 경로를 `/cart/lock`, `/transfer-host`, `DELETE /lobbies/{lobbyId}` 형태로 정리
  - Cart item 삭제를 `DELETE /lobbies/{lobbyId}/cart-items/{itemId}`로 변경
  - Payment confirm을 `POST /lobbies/{lobbyId}/payment-records/{paymentRecordId}/confirm`으로 변경
  - Chat API를 `/api/lobbies/{lobbyId}/chat/...` 하위로 정리하고 `/chat/connection`, `/chat/upload-url`, `/chat/read-state` 추가
  - STOMP endpoint를 `/ws`로 정리하고 destination은 `/topic/lobbies/{lobbyId}/chat`, `/app/lobbies/{lobbyId}/chat/send` 기준으로 변경
  - Admin lobby detail/payment-record endpoint 추가
  - Admin overview 응답을 최신 SDD 필드명으로 변경

- JPA 도메인 보정
  - `User` Entity를 최신 스키마에 맞춰 보정
  - `ReportStatus`를 `IN_REVIEW` 기준으로 변경
  - `Report` Entity를 `reported_message_id`, `description`, `updated_at` 등 최신 스키마에 맞춤
  - `AdminAuditLog` 필드 길이와 `target_id NOT NULL` 조건을 최신 스키마에 맞춤

- 클라이언트 네트워크 기반 추가
  - Admin Web에 `ApiClient` 클래스 추가
  - Admin overview 화면이 직접 `fetch`를 호출하지 않고 `ApiClient.getSystemOverview()`를 사용하도록 변경
  - Mobile에 `BuddiesApiClient` 클래스 추가
  - Mobile lobby browser가 `/api/lobbies`를 호출해 서버 통신 가능 여부를 표시하도록 변경

#### 수정 파일

- `backend/src/main/resources/db/migration/V1__initial_schema.sql`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthController.java`
- `backend/src/main/java/kr/kaist/buddies/user/UserController.java`
- `backend/src/main/java/kr/kaist/buddies/lobby/LobbyController.java`
- `backend/src/main/java/kr/kaist/buddies/lobby/CartPaymentController.java`
- `backend/src/main/java/kr/kaist/buddies/chat/ChatController.java`
- `backend/src/main/java/kr/kaist/buddies/admin/AdminController.java`
- `backend/src/main/java/kr/kaist/buddies/config/SecurityConfig.java`
- `backend/src/main/java/kr/kaist/buddies/config/WebSocketConfig.java`
- `backend/src/main/java/kr/kaist/buddies/user/domain/User.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/Report.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/ReportStatus.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/AdminAuditLog.java`
- `admin-web/src/apiClient.ts`
- `admin-web/src/main.tsx`
- `admin-web/src/styles.css`
- `mobile/lib/api_client.dart`
- `mobile/lib/main.dart`

#### TODO로 남긴 논의 사항

- JWT 인증 및 User/Lobby Member/Host/Admin RBAC 적용
- refresh token 및 logout token invalidation 저장 방식
- cart item 삭제와 정산 근거 보존 정책
- 채팅 restricted keyword 필터 정책
- object storage provider 선택 후 image upload URL 발급 방식
- 모바일 JWT secure storage 방식
- admin self-moderation 방지 및 감사 로그 transaction 처리

#### 검증

- `admin-web` TypeScript 타입 검증: `cmd /c npx tsc --noEmit` 성공
- `npm run build`는 PowerShell 실행 정책 문제를 우회해 `cmd /c`로 실행했으나, Vite/esbuild가 상위 디렉터리 접근 권한 문제로 config를 읽지 못해 실패했다.
- `npm run dev`도 같은 Vite/esbuild config 접근 권한 문제로 시작하지 못했다.
- 백엔드는 현재 환경에 `mvn` 명령이 없어 Maven 컴파일 검증을 수행하지 못했다.
- 현재 환경에서 `flutter`/`dart` 명령도 감지되지 않아 모바일 정적 검증은 수행하지 못했다.

#### 남은 작업

- Maven wrapper 추가 후 백엔드 컴파일/테스트 검증
- Flutter SDK가 있는 환경에서 모바일 `flutter analyze` 실행
- Spring Security JWT 필터와 role 기반 접근 제어 구현
- placeholder 컨트롤러를 service/repository 기반 실제 DB 로직으로 연결
- API error response 공통 포맷 적용

### 보안 정책 기반 네트워크 통신 보강

#### 목적

`SDD/보안_정책_정리.md`의 전송 보안, 민감값 보호, JWT 전달 정책을 클라이언트 공통 네트워크 계층과 서버 보안 설정에 반영했다.

#### 주요 변경 사항

- Admin Web `ApiClient`
  - non-local API base URL은 HTTPS가 아니면 생성 시 예외 발생
  - 모든 요청에 `Accept`, `Content-Type`, `Cache-Control: no-store` 적용
  - `fetch` 요청에 `cache: no-store`, `credentials: same-origin` 적용
  - JWT는 `Authorization: Bearer <token>` 헤더로만 전달
  - OTP와 password reset token은 SHA-256 hex 값으로 인코딩 후 전송
  - 비밀번호는 SHA-256으로 변환하지 않고 HTTPS/TLS 전송 후 서버 bcrypt 처리 대상으로 유지

- Mobile `BuddiesApiClient`
  - non-local API base URL은 HTTPS가 아니면 생성 시 예외 발생
  - 요청에 `Accept`, `Content-Type`, `Cache-Control: no-store`, `Pragma: no-cache` 적용
  - JWT는 `Authorization: Bearer <token>` 헤더로만 전달
  - OTP와 password reset token은 SHA-256 hex 값으로 인코딩 후 전송
  - SHA-256 처리를 위해 `crypto` 패키지 의존성 추가

- Backend 보안 설정
  - Spring Security session policy를 `STATELESS`로 설정
  - cache control, content type options, HSTS 보안 헤더 활성화
  - CORS exposed header에 `Authorization` 추가
  - AuthController에 HTTPS/bcrypt 및 SHA-256 encoded OTP/reset token 계약 주석 추가

#### 수정 파일

- `admin-web/src/apiClient.ts`
- `mobile/lib/api_client.dart`
- `mobile/pubspec.yaml`
- `backend/src/main/java/kr/kaist/buddies/config/SecurityConfig.java`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthController.java`
- `reports/development-log.md`

#### 검증

- `admin-web` TypeScript 타입 검증: `cmd /c npx tsc --noEmit` 성공
- `rg`로 SHA-256, HTTPS, no-store, Authorization, stateless/HSTS 적용 위치 확인
- 백엔드 Maven 및 Flutter SDK는 현재 환경에서 사용할 수 없어 컴파일/분석 검증은 수행하지 못했다.

#### 남은 작업

- 서버 password reset token 검증에서 client-provided SHA-256 값을 실제 DB hash와 비교하도록 구현
- 서버 비밀번호 저장/검증에 `BCryptPasswordEncoder` 적용
- JWT 발급/검증 필터 및 logout token invalidation 저장소 구현
- 모바일 JWT 저장소를 platform secure storage로 교체

## 2026-05-24

### 이메일 OTP 회원가입 및 JWT 로그인 서버 구현

#### 목적

`SDD/회원가입&로그인.md`에 정의된 이메일 OTP 기반 회원가입, pending signup 중복 처리, 이메일/비밀번호 로그인, JWT 기반 인증 흐름을 백엔드 서버에 실제 로직으로 연결했다. 기존 컨트롤러/API 경로와 DB 스키마 구조는 유지하고, `auth` 패키지 중심으로 서비스, JWT, 인증 필터, 공통 오류 응답 기능을 추가했다.

#### 주요 변경 사항

- 회원가입 요청 구현
  - `POST /api/auth/signup/request`가 실제 `AuthService`를 호출하도록 변경
  - 이메일 정규화, 이름/비밀번호 유효성 검사, users 이메일 중복 확인 추가
  - SRS `REQ-AUTH-1`에 따라 회원가입/OTP/로그인 이메일을 `@kaist.ac.kr` 도메인으로 제한
  - 이름은 영문, 한글, 숫자, 띄어쓰기만 허용하고 양 끝 공백을 거부
  - 비밀번호는 영문, 숫자, 특수문자만 허용하고 8자 이상 및 세 종류를 각각 1개 이상 포함하도록 검증
  - 6자리 OTP 생성
  - 비밀번호는 `BCryptPasswordEncoder`로 해시 저장
  - OTP는 원문을 SHA-256 hex로 변환한 뒤 `BCryptPasswordEncoder`로 해시 저장
  - 같은 이메일의 pending signup이 있으면 새 row를 만들지 않고 기존 row의 OTP, 만료 시간, 재전송 가능 시간, 이름, 비밀번호 해시를 갱신
  - OTP 재요청 제한 시간 전 재요청 시 `429 Too Many Requests` 반환

- OTP 검증 및 계정 생성 구현
  - `POST /api/auth/signup/verify`가 pending signup을 조회해 클라이언트가 보낸 SHA-256 OTP hex 값을 검증하도록 변경
  - OTP 만료, 최대 시도 횟수 3회, OTP 불일치 오류 처리 추가
  - OTP 불일치 시 `attempt_count` 증가
  - 계정 생성 직전 users 이메일 중복을 다시 확인
  - OTP 검증 성공 시 `users`에 실제 계정을 생성하고 pending signup을 삭제
  - 계정 생성과 pending signup 삭제를 transaction 안에서 처리

- OTP 재전송 구현
  - `POST /api/auth/signup/resend` 구현
  - 기존 pending signup이 없으면 `404 Not Found` 반환
  - 재전송 제한 시간이 지나면 새 OTP를 발급하고 `bcrypt(sha256_hex(OTP))`로 저장하여 기존 OTP를 무효화
  - 재전송 시 `attempt_count`를 초기화

- OTP SHA-256 전송 정책 정합화
  - 클라이언트가 OTP 원문 대신 SHA-256 hex 값을 전송하는 정책으로 통일
  - 서버는 OTP 발급 시 `bcrypt(sha256_hex(OTP))`를 저장
  - 서버는 OTP 검증 시 클라이언트가 보낸 SHA-256 hex 값을 저장된 bcrypt hash와 비교
  - 관련 SDD/API/DB/보안 정책 문서를 같은 정책으로 업데이트

- 로그인 및 내 정보 조회 구현
  - `POST /api/auth/login`에서 이메일/비밀번호 검증 후 JWT access token 발급
  - 이메일 없음과 비밀번호 불일치는 동일한 `401 Unauthorized` 메시지로 처리
  - 비활성 상태 계정은 `403 Forbidden`으로 거부
  - `GET /api/auth/me`가 JWT subject의 사용자 ID로 users 정보를 조회하도록 변경
  - `POST /api/auth/refresh`는 현재 access token 기반으로 새 access token을 발급하는 초기 구현으로 연결
  - `POST /api/auth/logout`은 SDD의 선택 API 응답 형식에 맞춰 메시지 반환

- JWT 발급/검증 기능 추가
  - HS256 기반 `JwtTokenProvider` 추가
  - JWT payload에 `sub`, `role`, `iat`, `exp` 포함
  - 기본 access token 유효 시간은 `3600`초로 설정하고 `buddies.jwt.expires-in-seconds`로 조정 가능하게 구성
  - JWT 서명 검증, 만료 검증, payload 파싱 구현

- Spring Security 인증/인가 적용
  - `JwtAuthenticationFilter` 추가
  - `Authorization: Bearer <token>` 헤더에서 JWT를 추출하고 인증 principal로 `AuthenticatedUser`를 저장
  - `@CurrentUser` annotation을 추가해 컨트롤러에서 인증 사용자 정보를 받을 수 있게 함
  - `/api/auth/me`, `/api/auth/refresh`, `/api/auth/logout` 인증 요구
  - `/api/lobbies/**`, `/api/reports`, `/api/users/me`, `/api/ratings`, `/api/support/tickets` 인증 요구
  - `/api/admin/**`는 `ADMIN` role 요구
  - 인증 실패와 권한 실패 응답을 `{ "error": "..." }` 형식으로 반환

- 공통 예외 처리 추가
  - `AuthException`으로 HTTP 상태 코드와 오류 메시지 전달
  - validation 오류는 `400 Bad Request`
  - email unique constraint 충돌은 `409 Conflict`
  - 인증/인가 오류는 SDD 메시지 형식에 맞춰 JSON으로 반환

- 개발용 OTP 발송 adapter 추가
  - `spring-boot-starter-mail` 의존성 추가
  - `EmailOtpSender`를 `JavaMailSender` 기반 실제 SMTP 발송 구현으로 변경
  - 이메일 발송 계정/비밀번호는 `backend/config/mail-secrets.yml`에서 읽도록 구성
  - Docker Compose 실행 시 `backend/config/mail-secrets.yml`이 컨테이너의 `/app/config/mail-secrets.yml`로 mount되도록 설정
  - 실제 비밀 설정 파일은 git에 포함하지 않도록 `.gitignore`에 추가
  - 커밋 가능한 예시 파일 `backend/config/mail-secrets.example.yml` 추가

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/auth/AuthController.java`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthService.java`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthException.java`
- `backend/src/main/java/kr/kaist/buddies/auth/ApiExceptionHandler.java`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthenticatedUser.java`
- `backend/src/main/java/kr/kaist/buddies/auth/CurrentUser.java`
- `backend/src/main/java/kr/kaist/buddies/auth/EmailOtpSender.java`
- `backend/src/main/java/kr/kaist/buddies/auth/JwtAuthenticationFilter.java`
- `backend/src/main/java/kr/kaist/buddies/auth/JwtTokenProvider.java`
- `backend/src/main/java/kr/kaist/buddies/config/SecurityConfig.java`
- `backend/pom.xml`
- `docker-compose.yml`
- `backend/src/main/resources/application.yml`
- `backend/config/mail-secrets.example.yml`
- `.gitignore`
- `buddies-doc/SDD/회원가입&로그인.md`
- `buddies-doc/SDD/API_목록_정리.md`
- `buddies-doc/SDD/DB_목록_정리.md`
- `buddies-doc/SDD/보안_정책_정리.md`
- `reports/development-log.md`

#### 검증

- `git diff --check` 성공
- `git status --short`로 변경 파일 범위 확인
- `rg`와 `sed`로 추가된 인증/JWT/보안 설정 위치 확인
- 현재 환경에는 `./mvnw`와 `mvn` 명령이 없어 Maven 빌드/테스트 검증은 수행하지 못했다.
- Java runtime은 감지되었으나 Maven 실행 도구가 없어 컴파일 검증까지 진행하지 못했다.

#### 남은 작업

- Maven wrapper 추가 또는 Maven 설치 후 백엔드 컴파일/테스트 실행
- 운영/테스트용 SMTP 계정 발급 및 `backend/config/mail-secrets.yml` 로컬 설정
- refresh token 저장소 및 logout invalidation 정책 구현
- 비밀번호 재설정 API 실제 서비스 로직 구현

## 2026-05-26

### API 경로 정합화 및 로그아웃 토큰 무효화 반영

#### 목적

`buddies-doc/SDD/7_API_목록_정리.md`의 최종 API 목록은 global version prefix 없이 endpoint를 표기한다. 이에 맞춰 백엔드 컨트롤러와 Spring Security matcher에서 기존 `/api` prefix를 제거했다. 또한 SRS `REQ-AUTH-7`에 대응하기 위해 로그아웃된 access token이 보호 API에서 재사용되지 않도록 JWT `jti` 기반 무효화 저장소를 추가했다.

비밀번호 재설정은 `buddies-doc/SDD/1_비밀번호재설정.md`에서 별도 설계 및 구현 대상으로 관리한다.

#### 주요 변경 사항

- API 경로 정합화
  - Auth API 경로를 `/api/auth/...`에서 `/auth/...`로 변경
  - Lobby API 경로를 `/api/lobbies/...`에서 `/lobbies/...`로 변경
  - Chat REST API 경로를 `/api/lobbies/{lobbyId}/chat/...`에서 `/lobbies/{lobbyId}/chat/...`로 변경
  - Profile/Rating/Help/Support/Admin/Report API에서 전역 `/api` prefix 제거
  - Spring Security `requestMatchers`도 SDD 최종 API 경로에 맞춰 갱신

- 로그아웃 토큰 무효화 구현
  - JWT payload에 `jti`를 추가해 access token 단위 식별자를 발급
  - `AuthenticatedUser` principal에 `tokenId`, `expiresAt`을 포함하도록 확장
  - `POST /auth/logout` 호출 시 현재 JWT의 `jti`와 만료 시각을 `revoked_tokens`에 저장
  - `JwtAuthenticationFilter`에서 요청 JWT의 `jti`가 `revoked_tokens`에 존재하면 `401 Unauthorized`로 차단
  - 중복 로그아웃 요청 시 같은 `token_id`를 중복 저장하지 않도록 repository 조회 후 저장

- DB 마이그레이션 추가
  - `V2__revoked_tokens.sql` 추가
  - `revoked_tokens.token_id`에 unique index 추가
  - 만료된 revoked token 정리 작업을 고려해 `expires_at` index 추가
  - `V1__initial_schema.sql`에 남아 있던 refresh/logout invalidation TODO 주석 제거

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/auth/AuthController.java`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthService.java`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthenticatedUser.java`
- `backend/src/main/java/kr/kaist/buddies/auth/JwtAuthenticationFilter.java`
- `backend/src/main/java/kr/kaist/buddies/auth/JwtTokenProvider.java`
- `backend/src/main/java/kr/kaist/buddies/auth/domain/RevokedToken.java`
- `backend/src/main/java/kr/kaist/buddies/auth/domain/RevokedTokenRepository.java`
- `backend/src/main/java/kr/kaist/buddies/config/SecurityConfig.java`
- `backend/src/main/java/kr/kaist/buddies/admin/AdminController.java`
- `backend/src/main/java/kr/kaist/buddies/chat/ChatController.java`
- `backend/src/main/java/kr/kaist/buddies/lobby/CartPaymentController.java`
- `backend/src/main/java/kr/kaist/buddies/lobby/LobbyController.java`
- `backend/src/main/java/kr/kaist/buddies/user/UserController.java`
- `backend/src/main/resources/db/migration/V1__initial_schema.sql`
- `backend/src/main/resources/db/migration/V2__revoked_tokens.sql`
- `reports/development-log.md`

#### 검증

- `rg`로 백엔드 `src/main/java`, `src/main/resources` 내 `/api` prefix 흔적이 제거되었는지 확인했다.
- `rg`로 `jti`, `revoked_tokens`, `RevokedTokenRepository`, `logout` 반영 위치를 확인했다.
- `git status --short`로 변경 파일 범위를 확인했다.
- 현재 환경에는 `mvn` 명령과 Maven wrapper가 없어 Maven 빌드/테스트 검증은 수행하지 못했다.

#### 남은 작업

- Maven wrapper 추가 또는 Maven 설치 후 백엔드 컴파일/테스트 실행
- 로그아웃 무효화 end-to-end 테스트 추가
  - 로그인 후 보호 API 접근 성공
  - 로그아웃 성공
  - 같은 access token으로 보호 API 접근 시 `401 Unauthorized`
- 만료된 `revoked_tokens` row 정리 정책 추가
- `/auth/refresh`가 access token 기반 임시 구현인지, refresh token 기반으로 확장할지 팀 결정
- `1_비밀번호재설정.md` 기준으로 비밀번호 재설정 API 실제 서비스 로직 구현

### 비밀번호 재설정 서버 로직 구현

#### 목적

`buddies-doc/SDD/1_비밀번호재설정.md`와 SRS `REQ-AUTH-6`에 맞춰 비밀번호 재설정 요청, 재설정 토큰 발급/메일 전송, 새 비밀번호 저장, 토큰 재사용 방지 로직을 백엔드 서버에 구현했다. 프론트엔드 화면은 이번 범위에서 제외하고 서버 API만 실제 서비스 로직으로 연결했다.

#### 주요 변경 사항

- 비밀번호 재설정 링크 요청 구현
  - `POST /auth/password-reset/request`가 `AuthService.requestPasswordReset()`을 호출하도록 변경
  - 이메일 입력값을 정규화하고 `@kaist.ac.kr` 도메인 여부를 검증
  - 사용자가 존재하지 않아도 계정 존재 여부를 노출하지 않고 동일한 성공 응답 반환
  - 사용자가 존재하면 secure random 기반 32-byte reset token 생성
  - reset token 원문은 이메일 링크에만 포함하고 DB에는 `sha256Hex(token)`만 저장
  - `expires_at`을 현재 시각 기준 30분 후로 설정
  - 같은 사용자의 기존 미사용 reset token은 `used_at`을 기록해 무효화
  - 비밀번호 재설정 링크를 이메일로 전송

- 비밀번호 재설정 완료 구현
  - `POST /auth/password-reset/confirm`이 `AuthService.confirmPasswordReset()`을 호출하도록 변경
  - 요청 token을 SHA-256 hash로 변환해 `password_reset_tokens.token_hash` 조회
  - token 없음, 만료, 이미 사용됨은 동일한 `400 Bad Request` 메시지로 처리
  - 새 비밀번호와 확인값 일치 여부 검증
  - 회원가입과 동일한 비밀번호 정책 검증
  - 새 비밀번호를 `BCryptPasswordEncoder`로 해시화해 `users.password_hash` 갱신
  - 비밀번호 갱신 성공 시 reset token의 `used_at`을 기록해 재사용 방지
  - 비밀번호 갱신과 토큰 무효화를 하나의 transaction 안에서 처리

- 메일 설정 보강
  - `EmailOtpSender`에 비밀번호 재설정 링크 발송 메서드 추가
  - `buddies.mail.password-reset-subject` 설정 추가
  - `buddies.password-reset.url-template` 설정 추가
  - `backend/config/mail-secrets.example.yml`에 비밀번호 재설정 메일 설정 예시 추가

- 도메인 보강
  - `PasswordResetTokenRepository`에 사용자별 미사용 reset token 조회 메서드 추가
  - `User` Entity에 비밀번호 해시 갱신 메서드 추가

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/auth/AuthController.java`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthService.java`
- `backend/src/main/java/kr/kaist/buddies/auth/EmailOtpSender.java`
- `backend/src/main/java/kr/kaist/buddies/auth/domain/PasswordResetTokenRepository.java`
- `backend/src/main/java/kr/kaist/buddies/user/domain/User.java`
- `backend/src/main/resources/application.yml`
- `backend/config/mail-secrets.example.yml`
- `reports/development-log.md`

#### SRS/SDD 충족 확인

- SRS 기능 1-3 비밀번호 찾기
  - KAIST 이메일을 통한 재설정 요청을 지원
  - 고유한 시간 제한 reset token을 생성해 이메일 링크로 전송
  - 새 비밀번호 제출 시 DB의 password hash를 갱신
  - 재설정 완료 후 token을 무효화

- `REQ-AUTH-6`
  - reset token 만료 시간을 `now + 30분`으로 저장
  - 만료된 token은 confirm 단계에서 거부

- SDD 핵심 원칙
  - 계정 존재 여부를 응답으로 노출하지 않음
  - reset token 평문 미저장
  - 사용 완료 token 재사용 방지
  - 비밀번호 갱신과 token 무효화를 transaction으로 처리

#### 검증

- `rg`로 `requestPasswordReset`, `confirmPasswordReset`, `PASSWORD_RESET_TTL`, `sendPasswordResetLink`, `updatePasswordHash` 반영 위치를 확인했다.
- `git diff`로 변경 범위와 SDD 요구사항 반영 내용을 확인했다.
- 서버 테스트는 담당자가 직접 진행하기로 하여 이번 작업에서는 실행하지 않았다.
- 현재 환경에는 `mvn` 명령과 Maven wrapper가 없어 Maven 빌드/테스트 검증은 수행하지 않았다.

#### 남은 작업

- 담당자 서버 테스트 수행
- 비밀번호 재설정 end-to-end 테스트 추가
  - 존재하는 KAIST 이메일로 reset link 발급
  - 존재하지 않는 KAIST 이메일도 동일 응답 반환
  - 만료 token 거부
  - 이미 사용한 token 재사용 거부
  - 재설정 후 새 비밀번호 로그인 성공 및 이전 비밀번호 로그인 실패
- 운영 환경에 맞춰 `BUDDIES_PASSWORD_RESET_URL_TEMPLATE` 설정
- reset token 요청 횟수 제한 정책이 필요하면 SDD와 구현에 추가

### 로컬 비밀번호 재설정 페이지 및 메일 timeout 보강

#### 목적

로컬 테스트 중 이메일 링크를 클릭했을 때 백엔드 서버에서 바로 비밀번호 변경 페이지를 확인할 수 있도록 단순 HTML 페이지를 추가했다. 또한 로컬 SMTP 연결 또는 전송이 지연될 때 서버 응답이 오래 대기하는 문제를 줄이기 위해 메일 timeout 기본값을 설정했다.

#### 주요 변경 사항

- 비밀번호 재설정 링크 대상 변경
  - 기본 `BUDDIES_PASSWORD_RESET_URL_TEMPLATE` 값을 `http://localhost:8080/password-reset?token=%s`로 변경
  - 이메일로 받은 reset link가 프론트 테스트 앱이 아니라 백엔드 서버의 `/password-reset` 페이지를 열도록 조정
  - `backend/config/mail-secrets.example.yml`의 예시 URL도 같은 값으로 변경

- 백엔드 비밀번호 변경 페이지 추가
  - `GET /password-reset` endpoint 추가
  - 쿼리 파라미터 `token` 값을 HTML form의 token input에 자동 채움
  - 새 비밀번호와 새 비밀번호 확인을 입력하면 `/auth/password-reset/confirm`으로 JSON 요청 전송
  - 꾸밈 없이 로컬 테스트용 최소 HTML/JavaScript만 포함
  - 기존 API 보안 설정상 `GET /password-reset`은 public endpoint로 접근 가능

- SMTP timeout 설정 추가
  - `spring.mail.properties.mail.smtp.connectiontimeout` 기본값을 5000ms로 설정
  - `spring.mail.properties.mail.smtp.timeout` 기본값을 5000ms로 설정
  - `spring.mail.properties.mail.smtp.writetimeout` 기본값을 5000ms로 설정
  - 환경변수 `BUDDIES_MAIL_CONNECTION_TIMEOUT_MS`, `BUDDIES_MAIL_TIMEOUT_MS`, `BUDDIES_MAIL_WRITE_TIMEOUT_MS`로 조정 가능
  - `mail-secrets.example.yml`에도 동일한 timeout 예시 추가

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/auth/PasswordResetPageController.java`
- `backend/src/main/resources/application.yml`
- `backend/config/mail-secrets.example.yml`
- `reports/development-log.md`

#### 검증

- `rg`로 `/password-reset`, `PasswordResetPageController`, `connectiontimeout`, `timeout`, `writetimeout`, `url-template` 반영 위치를 확인했다.
- 백엔드 서버 실행 및 브라우저 테스트는 담당자가 로컬 환경에서 진행하기로 하여 이번 작업에서는 실행하지 않았다.
- 현재 환경에는 `mvn` 명령과 Maven wrapper가 없어 Maven 빌드/테스트 검증은 수행하지 않았다.

#### 남은 작업

- 로컬 서버에서 이메일 링크 클릭 후 `/password-reset` 페이지 표시 확인
- 새 비밀번호 변경 성공 후 새 비밀번호 로그인 확인
- SMTP timeout 값이 실제 로컬 메일 서버/KAIST SMTP 환경에 적절한지 조정
- 추후 프론트엔드가 준비되면 `BUDDIES_PASSWORD_RESET_URL_TEMPLATE`을 실제 프론트 reset page URL로 전환

### 프로필, 주문 이력, 평가 및 도움말 서버 로직 구현

#### 목적

`buddies-doc/SDD/2_프로필&이력&평가&도움말.md`에 맞춰 기존 placeholder 응답을 실제 JWT 사용자와 DB 기반 로직으로 연결했다. 이번 범위는 백엔드 서버 API 구현이며, 프론트엔드 화면 구현은 제외했다.

#### 주요 변경 사항

- 프로필 조회 및 수정 구현
  - `GET /users/me`가 JWT principal의 userId로 `users` 테이블을 조회하도록 변경
  - `PATCH /users/me`가 이름과 프로필 이미지 URL만 수정하도록 제한
  - `email`, `id`, `role`, `trustScore`, `status` 변경 시도는 `403 Forbidden`으로 거부
  - 이름은 회원가입 정책과 동일하게 영문, 한글, 숫자, 띄어쓰기만 허용하고 양 끝 공백을 거부
  - `SUSPENDED`, `BANNED` 사용자는 주요 수정/등록 기능에서 제한

- 주문 이력 조회 구현
  - `GET /users/me/order-history`가 로그인 사용자의 lobby membership을 기준으로 닫힌 로비 이력을 조회
  - `DELIVERED`, `CLOSED` 상태 로비를 이력 대상으로 사용
  - 식당명, delivery location, Host 이름, 참여자 수, 총 결제 금액, 내 결제 금액, 평가 가능 여부를 반환
  - 현재 DB 스키마에 영수증 이미지 URL 필드가 없어 `receiptImageUrl`은 `null`로 반환

- 사용자 평가 구현
  - `POST /ratings`가 JWT 사용자 ID를 rater로 사용하도록 변경
  - 자기 자신 평가 금지
  - 닫힌 로비에서만 평가 허용
  - 평가자와 대상자가 같은 로비 멤버였는지 검증
  - `(lobby_id, rater_user_id, target_user_id)` 중복 평가를 사전 조회 및 DB unique constraint로 방지
  - 평가 저장 후 대상 사용자의 `trust_score`를 평균 평점 기준으로 재계산

- FAQ 및 Direct Contact 구현
  - `GET /help/faqs`가 OTP 만료, 딥링크 실패, 로비 참여 제한, 결제 지연, 신고 방법 FAQ를 반환
  - `POST /support/tickets`가 JWT 사용자 ID로 지원 티켓을 생성
  - 관련 `lobbyId`가 제공되면 로비 존재 여부를 검증

- 서비스 계층 추가
  - `UserService` 추가
  - 기존 스키마에 이미 존재하는 `lobbies`, `lobby_memberships`, `payment_records`, `ratings`, `support_tickets`는 `JdbcTemplate`으로 조회/삽입
  - `UserController`는 API 표면과 인증 사용자 추출만 담당하도록 정리

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/user/UserController.java`
- `backend/src/main/java/kr/kaist/buddies/user/UserService.java`
- `reports/development-log.md`

#### SRS/SDD 충족 확인

- `REQ-PROF-1`
  - 사용자 요청으로 검증된 KAIST 이메일을 변경할 수 없도록 차단

- `REQ-HIST-1`
  - 주문 이력 API에 `receiptImageUrl` 필드를 유지
  - 현재 DB에 영수증 이미지 저장 필드가 없어 사용 가능한 값이 없을 때 `null` 반환

- `REQ-RATE-1`
  - 같은 닫힌 로비의 멤버였던 사용자에게만 평가 허용

- `REQ-RATE-2`
  - 같은 lobbyId와 targetUserId 조합에 대해 rater당 1회만 평가 허용

- `REQ-HELP-1`
  - `POST /support/tickets`로 Admin 대시보드에서 처리 가능한 지원 티켓을 생성

#### 검증

- `rg`로 placeholder 응답 제거와 `UserService` 연결 위치를 확인했다.
- `rg`로 평가 성공 메시지, 문의 등록 메시지, 불변 프로필 필드 거부 메시지 반영 위치를 확인했다.
- 서버 테스트는 담당자가 직접 진행하기로 하여 이번 작업에서는 실행하지 않았다.
- 현재 환경에는 `mvn` 명령과 Maven wrapper가 없어 Maven 빌드/테스트 검증은 수행하지 않았다.

#### 남은 작업

- 담당자 서버 테스트 수행
- 주문 영수증 이미지 저장 필드/테이블이 확정되면 `receiptImageUrl` 연결
- 주문 이력의 닫힌 로비 기준을 `DELIVERED`, `CLOSED` 중 어느 상태까지 포함할지 팀 최종 확인
- 평가 가능 사용자 목록 API가 필요하면 별도 endpoint로 확장
- Trust Score 계산식을 단순 평균에서 SRS 최종 정책으로 확장
