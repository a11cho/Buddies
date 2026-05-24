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
  - 6자리 OTP 생성
  - 비밀번호는 `BCryptPasswordEncoder`로 해시 저장
  - OTP는 원문을 SHA-256 hex로 변환한 뒤 `BCryptPasswordEncoder`로 해시 저장
  - 같은 이메일의 pending signup이 있으면 새 row를 만들지 않고 기존 row의 OTP, 만료 시간, 재전송 가능 시간, 이름, 비밀번호 해시를 갱신
  - OTP 재요청 제한 시간 전 재요청 시 `429 Too Many Requests` 반환

- OTP 검증 및 계정 생성 구현
  - `POST /api/auth/signup/verify`가 pending signup을 조회해 클라이언트가 보낸 SHA-256 OTP hex 값을 검증하도록 변경
  - OTP 만료, 최대 시도 횟수, OTP 불일치 오류 처리 추가
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
  - 실제 이메일 provider는 아직 연결하지 않고 `EmailOtpSender`에서 OTP를 서버 로그에 남기는 개발용 구현으로 추가

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
- `backend/src/main/resources/application.yml`
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
- 실제 이메일 발송 provider 연동
- 현재 개발용 `EmailOtpSender`의 OTP 로그 출력 제거 또는 개발 profile 전용으로 제한
- refresh token 저장소 및 logout invalidation 정책 구현
- 비밀번호 재설정 API 실제 서비스 로직 구현
