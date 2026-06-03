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
  - 기본 `BUDDIES_PASSWORD_RESET_URL_TEMPLATE` 값을 `https://localhost:8443/password-reset?token=%s`로 변경
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

### 비밀번호 재설정 HTTPS 연결 및 테스트 도구 포트 갱신

#### 목적

비밀번호 재설정 링크와 서버 간 통신이 평문 HTTP가 아니라 HTTPS로 이루어지도록 로컬 개발 서버의 SSL 설정을 추가했다. 서버 포트가 `8080`에서 HTTPS `8443`으로 변경되었으므로, `buddies-doc/tools/signup-test-app`의 테스트 프록시도 새 서버 주소를 바라보도록 갱신했다.

#### 주요 변경 사항

- 백엔드 HTTPS 기본 설정
  - Spring Boot server port 기본값을 `8443`으로 변경
  - `server.ssl.enabled=true` 기본 설정 추가
  - 로컬 개발용 PKCS12 keystore `backend/config/dev-ssl.p12` 생성
  - `server.ssl.key-store`, `key-store-type`, `key-store-password`, `key-alias` 설정 추가
  - Dockerfile `EXPOSE` 포트를 `8443`으로 변경
  - Docker Compose backend port mapping을 `8443:8443`으로 변경
  - Docker Compose에서 `dev-ssl.p12`를 컨테이너 `/app/config/dev-ssl.p12`로 mount

- 비밀번호 재설정 링크 HTTPS 전환
  - 기본 `BUDDIES_PASSWORD_RESET_URL_TEMPLATE`을 `https://localhost:8443/password-reset?token=%s`로 변경
  - `backend/config/mail-secrets.example.yml`의 reset URL 예시도 HTTPS 8443 기준으로 변경
  - 비밀번호 재설정 페이지 응답에 `Cache-Control: no-store`, `Pragma: no-cache`, `Referrer-Policy: no-referrer` 헤더 추가

- 테스트 도구 갱신
  - `buddies-doc/tools/signup-test-app/server.js`의 backend proxy target을 `https://127.0.0.1:8443`으로 변경
  - self-signed 개발 인증서를 사용하는 로컬 HTTPS 백엔드에 연결할 수 있도록 test proxy에서 `rejectUnauthorized: false` 적용
  - `BUDDIES_TEST_BACKEND` 환경변수로 테스트 백엔드 URL을 바꿀 수 있게 변경
  - 테스트 페이지 상단에 기본 proxy 대상이 HTTPS 8443임을 표시

- 문서 및 보안 처리
  - `backend/README.md`에 로컬 HTTPS 기본 URL과 self-signed 인증서 경고 추가
  - `keytool` 기반 `dev-ssl.p12` 재생성 명령 추가
  - `backend/config/dev-ssl.p12`를 `.gitignore`에 추가해 개발용 keystore가 커밋되지 않도록 처리

#### 수정 파일

- `.gitignore`
- `backend/Dockerfile`
- `backend/README.md`
- `backend/config/mail-secrets.example.yml`
- `backend/src/main/resources/application.yml`
- `backend/src/main/java/kr/kaist/buddies/auth/PasswordResetPageController.java`
- `docker-compose.yml`
- `buddies-doc/tools/signup-test-app/server.js`
- `buddies-doc/tools/signup-test-app/index.html`
- `reports/development-log.md`

#### 검증

- `keytool`로 로컬 개발용 `backend/config/dev-ssl.p12` 생성
- `node --check buddies-doc/tools/signup-test-app/server.js` 성공
- `rg`로 `8443`, `ssl`, `dev-ssl`, `password-reset`, `rejectUnauthorized`, `Referrer-Policy`, `no-store` 반영 위치 확인
- 백엔드 서버 실행 및 브라우저 HTTPS 접속 테스트는 담당자가 로컬 환경에서 진행하기로 하여 이번 작업에서는 실행하지 않았다.
- 현재 환경에는 `mvn` 명령과 Maven wrapper가 없어 Maven 빌드/테스트 검증은 수행하지 않았다.

#### 남은 작업

- 로컬 브라우저에서 `https://localhost:8443/password-reset?token=...` 접속 확인
- self-signed 인증서 경고를 허용한 뒤 비밀번호 변경 요청이 정상 처리되는지 확인
- 운영 환경에서는 개발용 `dev-ssl.p12` 대신 실제 인증서 또는 배포 환경 TLS termination 적용
- 모바일/웹 클라이언트의 API base URL도 HTTPS 8443 또는 운영 HTTPS URL로 맞춰 테스트

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

## 2026-05-27

### 회원가입 OTP SMTP 발송 실패 진단 및 HTTPS 전환 후속 수정

#### 목적

회원가입 시 OTP 이메일 발송이 실패하는 문제를 점검했다. 서버와 클라이언트 통신을 HTTP에서 HTTPS로 변경한 이후 관련 설정이 일부 이전 값과 섞여 있었고, SMTP 발송 실패 시 실제 원인이 서버 로그에 남지 않아 문제 원인 파악이 어려운 상태였다. HTTPS 8443 기준으로 클라이언트/문서를 정리하고, SMTP 발송 실패의 상세 예외를 로그에 남기도록 개선했다.

#### 원인 분석

- HTTPS 전환 자체는 SMTP 서버 연결과 직접적으로 연결되지 않는다.
- Docker 백엔드는 `https://localhost:8443`에서 정상 기동 중임을 확인했다.
- `backend/config/mail-secrets.yml`의 `buddies.mail.from` 값이 예시값 `your-email@example.com`으로 남아 있어, Gmail SMTP 사용 시 인증 계정과 다른 From 주소로 인해 발신자 거부가 발생할 가능성이 컸다.
- `EmailOtpSender`가 `MailException`을 사용자용 공통 오류 메시지로 감싸면서 실제 SMTP 원인을 로그에 남기지 않아, Gmail 인증 실패, From 거부, STARTTLS 오류, timeout 등을 구분하기 어려웠다.
- 백업 모바일 인증 클라이언트의 기본 API URL이 여전히 `http://10.0.2.2:8080/api`로 남아 있어 HTTPS 8443 백엔드에 도달하지 못할 수 있었다.
- `admin-web/README.md`에도 Vite proxy 대상이 예전 `http://localhost:8080`으로 안내되어 있었다.

#### 주요 변경 사항

- SMTP 실패 원인 로깅 추가
  - `EmailOtpSender`에 SLF4J logger 추가
  - 회원가입 OTP 발송 실패 시 대상 이메일과 `MailException` stack trace를 warn 로그로 기록
  - 비밀번호 재설정 메일 발송 실패도 동일하게 실제 예외를 로그로 기록
  - 클라이언트 응답 메시지는 기존 사용자 친화적 오류 문구를 유지

- 로컬 SMTP 설정 보정
  - `backend/config/mail-secrets.yml`의 `buddies.mail.from`을 `${spring.mail.username}`으로 변경
  - SMTP 인증 계정과 From 주소가 일치하도록 하여 Gmail SMTP의 발신자 거부 가능성을 줄임
  - 비밀번호 재설정 URL template을 `https://localhost:8443/password-reset?token=%s`로 수정

- HTTPS 8443 클라이언트 설정 정리
  - `mobile_test_backup_auth/mobile/lib/api_client.dart`의 기본 `API_BASE_URL`을 `https://10.0.2.2:8443/api`로 변경
  - Android emulator/localhost 개발 환경에서 self-signed HTTPS 인증서를 허용하는 로컬 개발용 `badCertificateCallback` 추가
  - non-local API는 기존처럼 HTTPS를 요구하도록 유지

- 문서 정리
  - `admin-web/README.md`의 Vite proxy 안내를 `https://localhost:8443` 기준으로 수정

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/auth/EmailOtpSender.java`
- `backend/config/mail-secrets.yml`
- `mobile_test_backup_auth/mobile/lib/api_client.dart`
- `admin-web/README.md`
- `reports/development-log.md`

#### 검증

- `docker compose ps`로 `buddies-backend`와 `buddies-postgres` 컨테이너가 실행 중임을 확인했다.
- Docker 컨테이너 내부에서 `https://localhost:8443/actuator/health`가 `{"status":"UP"}`로 응답함을 확인했다.
- `docker compose build backend`로 수정된 Spring Boot backend가 컴파일 및 패키징되는 것을 확인했다.
- `docker compose up -d backend`로 수정된 backend 이미지를 재기동했다.
- 재기동 후 backend 로그에서 Tomcat이 HTTPS 8443으로 정상 시작됨을 확인했다.
- 로컬 환경에는 `mvn` 명령이 없어 Maven 직접 실행은 수행하지 못했다.

#### 남은 작업

- 실제 회원가입 OTP 요청을 다시 수행하고 `docker compose logs -f backend`에서 SMTP 상세 로그 확인
- Gmail 사용 시 계정의 app password/SMTP 허용 정책 확인
- `backend/config/dev-ssl.p12`가 로컬 파일이 아니라 디렉터리로 존재하므로, Docker가 아닌 로컬 `mvn spring-boot:run` 실행 전에는 기존 디렉터리를 정리하고 개발용 keystore 파일을 재생성

### 관리자 신고 관리 및 채팅 아카이브 검토 기능 구현

#### 목적

`buddies-doc/SDD/5_관리자_신고&채팅검토.md`에 정의된 관리자 신고 검토 기능을 실제 백엔드 서비스와 관리자 웹 화면에 연결했다. API 경로와 응답 구조는 `buddies-doc/SDD/7_API_목록_정리.md`의 최종 API 목록을 따르고, DB 접근은 `buddies-doc/SDD/8_DB_목록_정리.md`의 `reports`, `chat_messages`, `chat_archives`, `admin_audit_logs`, `moderation_actions` 테이블 구조를 기준으로 구현했다.

#### 주요 변경 사항

- 신고 생성 API 구현
  - `POST /reports`가 placeholder 응답 대신 `AdminService.createReport()`를 호출하도록 변경
  - `reporterUserId`는 request body에서 받지 않고 JWT principal의 현재 사용자 ID를 사용
  - 신고자와 피신고자가 같은 lobby의 active member인지 검증
  - `reportedMessageId`가 제공된 경우 해당 메시지가 같은 `lobbyId`에 속하는지 검증
  - 검증 통과 시 `reports` 테이블에 `OPEN` 상태 신고 저장
  - 성공 응답은 SDD 기준에 맞춰 `201 Created`와 message 객체를 반환

- 관리자 신고 목록 및 상세 조회 구현
  - `GET /admin/reports?status=OPEN&page=1&size=20` 구현
  - 응답을 SDD의 `{ items, page, size, totalCount }` 형태로 정리
  - `OPEN`, `IN_REVIEW`, `RESOLVED` 상태 필터와 pagination 적용
  - `GET /admin/reports/{reportId}` 구현
  - reporter/reportedUser의 id, name과 신고 사유, 설명, 신고 메시지 ID, 상태를 반환
  - 신고 상세 조회 시 `admin_audit_logs`에 `VIEW_REPORT` 기록

- 신고 해결 처리 구현
  - `PATCH /admin/reports/{reportId}/resolve` 구현
  - `reports.status`를 `RESOLVED`로 변경
  - `resolution_note`, `resolved_by_admin_id`, `resolved_at` 기록
  - 해결 처리 시 `admin_audit_logs`에 `RESOLVE_REPORT` 기록

- 관리자 채팅 아카이브 조회 구현
  - `GET /admin/lobbies/{lobbyId}/chat-archive` 구현
  - `chat_messages`와 `users`를 결합해 message id, sender user id, sender name, message type, content, media URL, createdAt 반환
  - 같은 lobby의 신고된 `reported_message_id` 목록을 조회해 각 메시지에 `reported: true` 표시
  - 채팅 아카이브 조회 시 `admin_audit_logs`에 `VIEW_CHAT_ARCHIVE` 기록

- 관리자 보조 조회 기능 연결
  - `GET /admin/system/overview`를 실제 DB count와 최근 lobby 목록 기반으로 구현
  - `GET /admin/users`, `GET /admin/users/{userId}`를 실제 users 테이블 기반으로 구현
  - 사용자 상세 조회 시 `VIEW_USER_DETAIL` 감사 로그 기록
  - `POST /admin/users/{userId}/moderation-actions`에서 self-moderation 방지, 사용자 status 갱신, `moderation_actions` 및 `admin_audit_logs` 기록
  - `GET /admin/lobbies/{lobbyId}`, `GET /admin/lobbies/{lobbyId}/payment-records`를 실제 DB 조회 기반으로 연결

- Repository 및 서비스 계층 정리
  - `AdminService` 신규 추가
  - 기존 `AdminController`의 placeholder 로직을 service 호출로 대체
  - `ReportRepository`에 pagination 및 reporter/reportedUser fetch를 위한 `EntityGraph` query 추가

- Admin Web 구현
  - 관리자 access token 입력 및 localStorage 저장 기능 추가
  - overview 화면을 실제 `/admin/system/overview` 응답에 연결
  - 신고 목록 화면 추가
  - 신고 상태 필터 `OPEN`, `IN_REVIEW`, `RESOLVED` 추가
  - 신고 상세 화면 추가
  - 신고 상세에서 관련 lobby의 chat archive를 함께 조회
  - 신고된 메시지는 별도 스타일로 강조 표시
  - lobby id 직접 입력으로 chat archive를 조회할 수 있는 화면 추가
  - `ApiClient`에 `getReports`, `getReport`, `resolveReport`, `getChatArchive` 추가
  - Vite dev proxy에서 `/api` prefix를 백엔드의 non-versioned API 경로로 rewrite하도록 수정

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/admin/AdminController.java`
- `backend/src/main/java/kr/kaist/buddies/admin/AdminService.java`
- `backend/src/main/java/kr/kaist/buddies/admin/domain/ReportRepository.java`
- `admin-web/src/apiClient.ts`
- `admin-web/src/main.tsx`
- `admin-web/src/styles.css`
- `admin-web/vite.config.ts`
- `reports/development-log.md`

#### SRS/SDD 충족 확인

- `REQ-ADMIN-1`
  - Admin이 제출된 신고 목록을 조회할 수 있도록 `GET /admin/reports` 구현

- `REQ-ADMIN-2`
  - 신고 목록 및 상세 응답에 신고자, 피신고자, 사유, lobby ID 포함

- `REQ-ADMIN-3`
  - Admin 전용 chat archive endpoint 구현
  - Spring Security의 `/admin/**` ADMIN role matcher 위에서 동작

- `REQ-ADMIN-4`
  - chat archive 응답에서 신고된 메시지를 `reported: true`로 표시
  - admin-web에서 reported message를 강조 표시

- `REQ-ADMIN-5`
  - archive message 응답에 user ID, timestamp, content, media URL 포함

- `REQ-CHAT-7`
  - archive 조회는 `/admin/lobbies/{lobbyId}/chat-archive` 경로로만 제공
  - 일반 사용자 chat messages API와 분리

#### 검증

- 사용자가 테스트를 직접 수행하기로 하여 이번 작업에서는 backend/frontend 테스트를 실행하지 않았다.
- 작업 중 `mvn test`는 로컬 환경에 `mvn` 명령이 없어 실행할 수 없음을 확인했다.
- 작업 중 `npm run build`는 PowerShell 실행 정책과 미설치 dependency 문제로 실행되지 않았고, dependency 설치 승인 요청은 사용자가 거절했다.
- 불완전하게 생성된 `admin-web/node_modules`와 `admin-web/.npm-cache`는 작업 부산물이므로 정리했다.
- `git status --short`로 변경 파일 범위를 확인했다.
- `rg`로 기존 관리자 placeholder DTO 이름과 TODO 흔적이 남아 있지 않은지 확인했다.

#### 남은 작업

- 사용자가 로컬 환경에서 backend test/build 실행
- 사용자가 로컬 환경에서 admin-web dependency 설치 후 TypeScript/Vite build 실행
- 실제 ADMIN 계정 JWT로 관리자 화면 end-to-end 확인
- 신고 생성 테스트 데이터 구성
  - 같은 lobby active member 간 신고 성공
  - lobby에 속하지 않은 사용자 신고 거절
  - 다른 lobby의 reportedMessageId 신고 거절
- chat archive에서 reported message 강조 표시 확인
  - `reported: true` 메시지 스타일 확인
  - `sender_user_id = null`인 SYSTEM message 표시 확인

### Admin Web 로그인 화면 및 초기 관리자 계정 생성 구현

#### 목적

기존 Admin Web은 관리자가 access token을 직접 입력해야 하는 내부 도구 형태였다. 관리자 사용 흐름을 실제 운영 화면에 가깝게 만들기 위해 이메일/비밀번호 로그인 UI를 추가하고, 서버 초기화 시 ADMIN 계정이 없으면 기본 관리자 계정을 자동 생성하도록 했다.

#### 주요 변경 사항

- Admin Web 로그인 화면 추가
  - access token 직접 입력 UI를 제거하고 이메일/비밀번호 로그인 폼을 추가
  - `POST /auth/login`으로 access token을 발급받은 뒤 `/auth/me`로 현재 사용자의 role 확인
  - role이 `ADMIN`이 아니면 Admin 화면 진입을 차단
  - 로그인 성공 시 access token을 `localStorage`의 `buddies.admin.accessToken`에 저장
  - 저장된 token이 있으면 페이지 진입 시 session 검증 후 Admin 화면 로드
  - 상단에 로그인한 관리자 이름/이메일과 Logout 버튼 표시

- Admin Web 로그인 UI 스타일 추가
  - 로그인 전용 full-screen 화면과 로그인 패널 스타일 추가
  - 로그인 오류 메시지와 disabled 버튼 상태 스타일 추가
  - 기존 대시보드 상단 token input 영역을 session 정보 영역으로 교체

- 초기 관리자 계정 생성 로직 추가
  - `AdminAccountInitializer` 추가
  - 서버 시작 시 `ADMIN` role 사용자가 하나도 없으면 기본 관리자 계정을 생성
  - 기본값은 `admin@kaist.ac.kr` / `Admin123!`
  - 동일 이메일 사용자가 이미 존재하지만 ADMIN 계정이 없는 경우 해당 사용자를 ADMIN으로 승격
  - 환경변수로 초기 관리자 설정 변경 가능
    - `BUDDIES_ADMIN_BOOTSTRAP_ENABLED`
    - `BUDDIES_ADMIN_BOOTSTRAP_EMAIL`
    - `BUDDIES_ADMIN_BOOTSTRAP_NAME`
    - `BUDDIES_ADMIN_BOOTSTRAP_PASSWORD`

- User 도메인 보강
  - `User`에 role 지정 생성자 추가
  - 초기 관리자 승격을 위한 `updateRole()` 추가
  - `UserRepository.existsByRole()` 추가

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/config/AdminAccountInitializer.java`
- `backend/src/main/java/kr/kaist/buddies/user/domain/User.java`
- `backend/src/main/java/kr/kaist/buddies/user/domain/UserRepository.java`
- `backend/src/main/resources/application.yml`
- `admin-web/src/apiClient.ts`
- `admin-web/src/main.tsx`
- `admin-web/src/styles.css`
- `reports/development-log.md`

#### 검증

- `admin-web`에서 `npm run build`가 성공했다.
- Vite dev server로 Admin Web을 실행하고 브라우저에서 로그인 화면 렌더링을 확인했다.
- 로컬 환경에는 `mvn` 명령이 없어 Maven build/test는 수행하지 못했다.

#### 남은 작업

- 실제 backend와 DB를 함께 띄운 뒤 기본 관리자 계정으로 로그인 end-to-end 확인
- 운영/시연 환경에서는 기본 관리자 비밀번호를 환경변수로 반드시 변경
- 기본 관리자 계정 생성 정책을 production에서도 허용할지 팀 결정

### 관리자 사용자 조정, 계정 관리 및 시스템 모니터링 기능 보강

#### 목적

`buddies-doc/SDD/6_관리자_사용자조정&계정관리&모니터링.md`에 정의된 사용자 계정 조회, 사용자 정지/차단, 신고 해결, 시스템 모니터링 기능 중 기존 구현에 부족했던 사용자 관리 응답 구조와 Admin Web 사용자 조정 화면을 보강했다.

#### 주요 변경 사항

- 관리자 사용자 목록 API 보강
  - `GET /admin/users?status=ACTIVE&page=1&size=20` 응답을 `{ items, page, size, totalCount }` 형태로 변경
  - 사용자 목록 item에 `id`, `email`, `name`, `role`, `status`, `trustScore`, `createdAt` 포함
  - `ACTIVE`, `SUSPENDED`, `BANNED` 상태 필터 검증 추가
  - pagination과 total count 반환 추가

- 관리자 사용자 상세 API 보강
  - `GET /admin/users/{userId}` 응답을 SDD의 사용자 상세 목적에 맞게 확장
  - 사용자 기본 정보와 함께 다음 통계 반환
    - `reportedCount`
    - `reporterCount`
    - `closedLobbyCount`
  - 대상 사용자의 `moderation_actions` 이력을 최신순으로 반환
  - 사용자 상세 조회 시 기존처럼 `VIEW_USER_DETAIL` 감사 로그 기록

- 사용자 조정 조치 로직 보강
  - `POST /admin/users/{userId}/moderation-actions`에서 `SUSPEND` 조치의 `endsAt` 필수/미래 시각 검증 추가
  - `WARNING`은 사용자 상태를 변경하지 않고 조정 이력만 기록하도록 수정
  - `UNSUSPEND`는 사용자 상태를 `ACTIVE`로 변경
  - `BAN`은 사용자 상태를 `BANNED`로 변경
  - ISO instant 및 offset datetime 입력을 모두 처리할 수 있도록 datetime parser 보강
  - self-moderation 방지와 `admin_audit_logs` 기록은 유지

- Admin Web 사용자 관리 화면 추가
  - sidebar에 `Users` 탭 추가
  - 사용자 상태 필터 `ACTIVE`, `SUSPENDED`, `BANNED` 추가
  - 사용자 목록과 선택된 사용자 상세 패널 추가
  - 상세 패널에 신고 받은 수, 신고한 수, 닫힌 로비 수, Trust Score 표시
  - 사용자 조정 폼 추가
    - `WARNING`
    - `SUSPEND`
    - `BAN`
    - `UNSUSPEND`
  - `SUSPEND` 선택 시 정지 종료 시각 입력 필드 표시
  - 관련 report ID 선택 입력 지원
  - 조정 이력 목록 표시
  - 조정 성공 후 사용자 목록과 overview 통계 재조회

- Admin Web API client 확장
  - `getUsers()`
  - `getUser()`
  - `moderateUser()`
  - 사용자 목록/상세/조정 이력 TypeScript 타입 추가

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/admin/AdminController.java`
- `backend/src/main/java/kr/kaist/buddies/admin/AdminService.java`
- `admin-web/src/apiClient.ts`
- `admin-web/src/main.tsx`
- `admin-web/src/styles.css`
- `reports/development-log.md`

#### SRS/SDD 충족 확인

- `REQ-ADMIN-6`
  - Admin Web에서 사용자에게 `WARNING`, `SUSPEND`, `BAN`, `UNSUSPEND` 조치를 적용할 수 있도록 연결
  - Backend에서 조정 조치를 `moderation_actions`에 기록

- `REQ-ADMIN-7`
  - 조정 조치에 따라 `users.status`를 `ACTIVE`, `SUSPENDED`, `BANNED`로 갱신
  - 구체적인 보호 API별 접근 제한 정책은 기존 인증/권한 계층에서 추가 보강 필요

- `REQ-ADMIN-8`
  - 기존 `PATCH /admin/reports/{reportId}/resolve`와 Admin Web 신고 해결 버튼을 유지

- `REQ-ADMIN-9`
  - 해결된 신고는 삭제하지 않고 `reports`에 `resolution_note`, `resolved_by_admin_id`, `resolved_at`을 기록하는 기존 구현 유지

- Admin 사용자 계정 상세 조회
  - 사용자 기본 정보, 신고 관련 count, 닫힌 로비 count, 조정 이력을 Admin 화면에서 확인 가능

- Admin 시스템 모니터링
  - 기존 `/admin/system/overview` 기반 overview 화면을 유지
  - 사용자 조정 후 overview 통계를 재조회하도록 Admin Web 흐름 보강

#### 검증

- `admin-web`에서 `npm run build`가 성공했다.
- Vite dev server로 로그인 화면 렌더링을 확인했다.
- 브라우저의 현재 Admin Web 화면에서 로그인 페이지가 정상 표시됨을 확인했다.
- 로컬 환경에는 `mvn` 명령이 없어 Maven build/test는 수행하지 못했다.

#### 남은 작업

- 실제 backend와 DB를 함께 띄운 상태에서 ADMIN 계정으로 Users 탭 end-to-end 확인
- `SUSPENDED` 사용자의 로비 생성, 로비 참여, 채팅, 결제 확인, 신고 제출 제한을 API middleware/service 단에서 일관되게 적용
- `BANNED` 사용자의 로그인 또는 보호 API 접근 차단 범위 최종 확정 및 구현
- 사용자 상세의 최근 활동 시각과 참여 로비 이력 상세 응답이 필요하면 API 확장
- 영구 차단 해제(`BANNED → ACTIVE`)에 별도 확인 절차를 둘지 팀 결정

## 2026-05-30

### Host 계좌 정보 등록 및 로비 상세 응답 연동

#### 목적

`buddies-doc/SDD/추가.md`와 갱신된 SDD 정책에 따라 Host의 계좌 정보 등록/수정/조회 책임을 Auth 모듈에 두고, 로비 생성 및 Cart Lock 전에 Host 계좌 정보 등록 여부를 확인하며, Cart Lock 이후 로비 상세 조회에서 active Lobby member에게 Host 계좌 정보를 함께 제공하도록 백엔드와 테스트 도구를 보강했다.

#### 주요 변경 사항

- Auth 계좌 정보 API 추가
  - `GET /users/me/payment-info` 추가
  - `PATCH /users/me/payment-info` 추가
  - 계좌 정보는 JWT의 현재 사용자 ID를 기준으로만 조회/수정
  - 은행명, 계좌번호, 예금주명 필수값 검증 추가
  - 계좌번호는 숫자, 공백, 하이픈으로 구성된 최소 형식만 허용

- 계좌 정보 도메인 및 DB 추가
  - `host_payment_infos` 테이블 추가
  - 사용자별 계좌 정보 1개만 허용하는 unique index 추가
  - `HostPaymentInfo` JPA Entity 추가
  - `HostPaymentInfoRepository` 추가
  - Flyway migration `V3__host_payment_infos.sql` 추가

- Spring Security 경로 보강
  - `/auth/me/**`를 인증 필요 경로로 확장
  - 계좌 정보 API가 기존 Auth JWT 보호 범위 안에서 동작하도록 설정

- Lobby API 연동
  - `POST /lobbies`에서 현재 사용자의 계좌 정보가 없으면 `409 Conflict` 반환
  - `GET /lobbies/{lobbyId}` 응답에 다음 field 추가
    - `hostBankName`
    - `hostAccountNumber`
    - `hostAccountHolderName`
  - 로비가 `WAITING`, `CANCELED`, `CLOSED`가 아닌 상태일 때 Host 계좌 정보를 응답에 포함
  - 로비 상세 조회 시 active Lobby member 여부 확인 추가
  - `POST /lobbies/{lobbyId}/cart/lock`에서 현재 Host 계좌 정보가 없으면 `409 Conflict` 반환

- 로컬 테스트 도구 보강
  - `buddies-doc/tools/signup-test-app`에 계좌 정보 등록/조회 카드 추가
  - 로그인 후 발급받은 JWT로 `PATCH /users/me/payment-info`, `GET /users/me/payment-info`를 직접 호출 가능
  - 테스트 도구 제목을 회원가입/로그인/비밀번호 재설정/계좌 등록 흐름을 포함하도록 수정

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/auth/AuthController.java`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthService.java`
- `backend/src/main/java/kr/kaist/buddies/auth/domain/HostPaymentInfo.java`
- `backend/src/main/java/kr/kaist/buddies/auth/domain/HostPaymentInfoRepository.java`
- `backend/src/main/java/kr/kaist/buddies/config/SecurityConfig.java`
- `backend/src/main/java/kr/kaist/buddies/lobby/LobbyController.java`
- `backend/src/main/java/kr/kaist/buddies/lobby/LobbyService.java`
- `backend/src/main/resources/db/migration/V3__host_payment_infos.sql`
- `buddies-doc/tools/signup-test-app/index.html`
- `buddies-doc/tools/signup-test-app/app.js`
- `reports/development-log.md`

#### 검증

- `git diff --check` 성공
- `rg`로 `payment-info`, `host_payment_infos`, `hostBankName` 적용 위치 확인
- 현재 환경에는 `mvnw`와 `mvn` 명령이 없어 Maven build/test는 수행하지 못했다.
- 계좌 등록 테스트 도구는 정적 HTML/JS 수정이므로 별도 빌드 없이 기존 `server.js`로 실행 가능하다.

#### 남은 작업

- Maven wrapper 추가 또는 Maven 설치 후 backend compile/test 실행
- 실제 DB migration 적용 후 계좌 정보 저장/조회 end-to-end 확인
- Lobby 모듈의 placeholder 로직을 실제 service/repository 기반 구현으로 확장
- Cart Locking 시 요청자가 실제 Host인지 검증하는 기존 Lobby 권한 로직과 계좌 정보 검증을 통합
- Mobile app에 계좌 정보 등록 화면과 Lobby detail 결제 섹션 UI 연결

## 2026-06-02

### Direct Contact 지원 문의 관리자 처리 기능 추가 및 SDD 반영

#### 목적

기존 사용자 API `POST /support/tickets`로 FAQ에서 해결되지 않은 문의를 생성할 수 있었지만, Admin Web에는 해당 문의를 조회하고 처리할 수 있는 화면과 Admin API가 없어 운영 대응이 불가능했다. 이에 support ticket 관리자 목록/상세/상태 갱신 API와 Admin Web Tickets 화면을 추가하고, 관련 SDD 문서를 최신 구현에 맞게 갱신했다.

#### 주요 변경 사항

- Admin 지원 문의 API 추가
  - `GET /admin/support-tickets?status=OPEN&page=1&size=20` 추가
  - `GET /admin/support-tickets/{ticketId}` 추가
  - `PATCH /admin/support-tickets/{ticketId}` 추가
  - `OPEN`, `IN_PROGRESS`, `RESOLVED` 상태 필터와 pagination 적용
  - 문의 상세 조회 시 제출 사용자, 관련 lobby ID, category, title, body, status, 처리 메모, 처리 Admin, 처리 시각 반환
  - `RESOLVED`로 변경할 때 `resolutionNote`를 필수로 검증
  - 상세 조회와 상태 갱신 시 `admin_audit_logs`에 `VIEW_SUPPORT_TICKET`, `UPDATE_SUPPORT_TICKET` 기록

- support_tickets 처리 컬럼 및 인덱스 추가
  - Flyway migration `V7__support_ticket_admin_resolution.sql` 추가
  - `support_tickets.resolution_note` 추가
  - `support_tickets.resolved_by_admin_id` 추가
  - `support_tickets.resolved_at` 추가
  - Admin 목록 필터링을 위한 `idx_support_tickets_status_created_at` 인덱스 추가

- Admin overview 통계 보강
  - `/admin/system/overview` 응답에 `openSupportTicketCount` 추가
  - `OPEN`, `IN_PROGRESS` 상태 문의를 미처리 문의로 집계
  - Admin Web Overview에 `Open Tickets` metric 표시

- Admin Web Tickets 화면 추가
  - sidebar에 `Tickets` 탭 추가
  - 문의 상태 필터 `OPEN`, `IN_PROGRESS`, `RESOLVED` 추가
  - 문의 목록과 선택된 문의 상세 패널 추가
  - 상세 패널에 제출 사용자, 관련 lobby ID, category, title, body, 처리 Admin 표시
  - 처리 상태와 처리 메모를 입력해 문의 상태를 갱신하는 폼 추가
  - 처리 성공 후 문의 목록과 overview 통계 재조회

- Admin Web API client 확장
  - `SupportTicketPage`, `SupportTicketSummary`, `SupportTicketDetail` TypeScript 타입 추가
  - `getSupportTickets()`, `getSupportTicket()`, `updateSupportTicket()` 추가

- SDD 문서 갱신
  - `6_관리자_사용자조정&계정관리&모니터링.md`에 Direct Contact 지원 문의 처리 시스템, API, DB, 감사 로그, 시퀀스 추가
  - `7_API_목록_정리.md`에 Admin support ticket API 3개 추가
  - `8_DB_목록_정리.md`와 `2_프로필&이력&평가&도움말.md`의 `support_tickets` 컬럼 설명 갱신

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/admin/AdminController.java`
- `backend/src/main/java/kr/kaist/buddies/admin/AdminService.java`
- `backend/src/main/resources/db/migration/V7__support_ticket_admin_resolution.sql`
- `admin-web/src/apiClient.ts`
- `admin-web/src/main.tsx`
- `admin-web/src/styles.css`
- `buddies-doc/SDD/2_프로필&이력&평가&도움말.md`
- `buddies-doc/SDD/6_관리자_사용자조정&계정관리&모니터링.md`
- `buddies-doc/SDD/7_API_목록_정리.md`
- `buddies-doc/SDD/8_DB_목록_정리.md`
- `reports/development-log.md`

#### SRS/SDD 충족 확인

- Direct Contact 문의 운영 대응
  - 사용자가 생성한 `support_tickets`를 Admin이 조회하고 상태를 갱신할 수 있도록 Admin API와 화면을 연결
  - 문의를 삭제하지 않고 처리 메모, 처리자, 처리 시각을 보관

- Admin 시스템 모니터링
  - Admin overview에서 미처리 support ticket 수를 확인할 수 있도록 `openSupportTicketCount` 추가

- Admin 감사 로그
  - 지원 문의 상세 조회와 상태 갱신 작업을 `admin_audit_logs`에 기록

#### 검증

- `admin-web`에서 `npm.cmd install` 실행 후 dependency 설치 성공
- `admin-web`에서 `npm.cmd run build` 성공
- 최초 `npm run build`는 PowerShell 실행 정책과 Vite/esbuild sandbox 읽기 제한으로 실패했으나, `npm.cmd`와 승인된 빌드 실행으로 검증 완료
- 현재 환경에는 `mvnw`와 `mvn` 명령이 없어 Maven build/test는 수행하지 못했다.
- `rg`로 Admin support ticket API, `openSupportTicketCount`, `resolution_note`, SDD support ticket 문서 반영 위치를 확인했다.

#### 남은 작업

- Maven wrapper 추가 또는 Maven 설치 후 backend compile/test 실행
- 실제 DB migration 적용 후 support ticket 목록/상세/상태 갱신 end-to-end 확인
- 실제 ADMIN 계정 JWT로 Admin Web Tickets 탭에서 문의 처리 흐름 확인
- 사용자 앱에서 처리 완료된 문의 상태 또는 답변을 사용자에게 다시 보여줄지 정책 결정

## 2026-06-03

### Payment Info API User 모듈 이동

#### 목적

Host 계좌 정보 등록/수정/조회 API의 책임을 Auth 모듈에서 User 모듈로 이동해, 인증/토큰 발급은 Auth가 담당하고 로그인한 사용자의 프로필성 정보 관리는 User가 담당하도록 경계를 정리했다.

#### 주요 변경 사항

- 계좌 정보 API 경로를 `/auth/me/payment-info`에서 `/users/me/payment-info`로 변경
  - `GET /users/me/payment-info`
  - `PATCH /users/me/payment-info`
- `AuthController`와 `AuthService`에서 payment info API/서비스 책임 제거
- `UserController`와 `UserService`가 현재 사용자 JWT 문맥으로 `host_payment_infos`를 조회/저장하도록 정리
- `HostPaymentInfo`와 `HostPaymentInfoRepository`를 `kr.kaist.buddies.user.domain` 패키지로 배치
- `SecurityConfig`에서 `/users/me/**` 인증 보호 범위 안에 payment info API가 포함되도록 확인
- `LobbyService`의 로비 생성 및 cart lock 전 Host 계좌 정보 등록 여부 검사는 유지
- 로비 상세 응답에서 LOCKED 이후 active member에게 Host 계좌 정보를 제한 노출하는 정책은 유지

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/auth/AuthController.java`
- `backend/src/main/java/kr/kaist/buddies/auth/AuthService.java`
- `backend/src/main/java/kr/kaist/buddies/config/SecurityConfig.java`
- `backend/src/main/java/kr/kaist/buddies/lobby/LobbyService.java`
- `backend/src/main/java/kr/kaist/buddies/user/UserController.java`
- `backend/src/main/java/kr/kaist/buddies/user/UserService.java`
- `backend/src/main/java/kr/kaist/buddies/user/domain/HostPaymentInfo.java`
- `backend/src/main/java/kr/kaist/buddies/user/domain/HostPaymentInfoRepository.java`
- `buddies-doc/SDD/2_프로필&이력&평가&도움말.md`
- `reports/development-log.md`

#### 검토 및 보정

- `HostPaymentInfo`의 package 선언이 파일 경로와 달라 컴파일 시 import/entity scan 문제가 발생할 수 있어 `kr.kaist.buddies.user.domain`으로 수정했다.
- `UserService` 생성자에 `HostPaymentInfoRepository` 주입 파라미터가 빠져 있어 컴파일 오류가 발생할 수 있어 생성자 주입을 보정했다.
- 모바일 프로필 계좌 설정 화면과 user service 주석의 API 경로를 `/users/me/payment-info`로 정정했다.
- SDD 문서의 남은 `/auth/me/payment-info` 참조를 `/users/me/payment-info`로 정리했다.

#### 검증

- `rg`로 `/auth/me/payment-info`, `/users/me/payment-info`, `HostPaymentInfo` 참조 위치를 확인했다.
- backend Maven 테스트/컴파일을 실행해 Spring component scan과 생성자 주입 오류 여부를 확인했다.
### 프로필 이미지 업로드 URL 발급 API 추가

#### 목적

채팅 이미지 업로드와 같은 흐름을 프로필 이미지에도 적용하기 위해, 사용자가 직접 이미지 URL을 입력하지 않고 Flutter에서 사진첩 이미지를 선택한 뒤 업로드 URL을 발급받아 업로드하고, 최종 `mediaUrl`만 `PATCH /users/me`의 `profileImageUrl`로 저장할 수 있도록 백엔드 API와 SDD를 보강했다.

#### 주요 변경 사항

- User API에 `POST /users/me/profile-image/upload-url` 추가
  - 요청 body는 `filename`, `contentType`
  - 응답 body는 `uploadUrl`, `mediaUrl`
  - JWT 현재 사용자를 조회하고 `ACTIVE` 상태인지 확인
  - 지원 이미지 형식은 `image/jpeg`, `image/png`, `image/gif`, `image/webp`
  - 현재 구현은 채팅 이미지 업로드 URL과 같은 더미 URL 발급 구조이며, 실제 object storage presigned URL 발급은 추후 storage provider 연동 시 교체 예정

- 프로필 수정 흐름 정리
  - 이미지 바이너리는 `PATCH /users/me`로 보내지 않음
  - 클라이언트가 업로드 완료 후 받은 `mediaUrl`을 `profileImageUrl`로 전달
  - `users.profile_image_url`에는 이미지 파일이 아니라 URL만 저장

- SDD 업데이트
  - `buddies-doc/SDD/2_프로필&이력&평가&도움말.md`에 프로필 이미지 업로드 URL 발급 정책, Flutter 연결 흐름, API 스펙, 시퀀스 반영

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/user/UserController.java`
- `backend/src/main/java/kr/kaist/buddies/user/UserService.java`
- `buddies-doc/SDD/2_프로필&이력&평가&도움말.md`
- `reports/development-log.md`

#### 검증

- `rg`로 새 endpoint, DTO, 서비스 메서드, 문서 반영 위치를 확인했다.
- `git diff --check` 성공
- 현재 환경에는 `mvn` 명령이 없어 Maven build/test는 수행하지 못했다.

#### 남은 작업

- 실제 storage provider를 선택한 뒤 `uploadUrl`을 presigned URL로 교체
- 업로드 객체 key 정책, 캐시 무효화 정책, 기존 프로필 이미지 삭제 정책 확정
### Direct Contact 지원 문의 관리자 처리 기능 추가 및 SDD 반영

#### 목적

기존 사용자 API `POST /support/tickets`로 FAQ에서 해결되지 않은 문의를 생성할 수 있었지만, Admin Web에는 해당 문의를 조회하고 처리할 수 있는 화면과 Admin API가 없어 운영 대응이 불가능했다. 이에 support ticket 관리자 목록/상세/상태 갱신 API와 Admin Web Tickets 화면을 추가하고, 관련 SDD 문서를 최신 구현에 맞게 갱신했다.

#### 주요 변경 사항

- Admin 지원 문의 API 추가
  - `GET /admin/support-tickets?status=OPEN&page=1&size=20` 추가
  - `GET /admin/support-tickets/{ticketId}` 추가
  - `PATCH /admin/support-tickets/{ticketId}` 추가
  - `OPEN`, `IN_PROGRESS`, `RESOLVED` 상태 필터와 pagination 적용
  - 문의 상세 조회 시 제출 사용자, 관련 lobby ID, category, title, body, status, 처리 메모, 처리 Admin, 처리 시각 반환
  - `RESOLVED`로 변경할 때 `resolutionNote`를 필수로 검증
  - 상세 조회와 상태 갱신 시 `admin_audit_logs`에 `VIEW_SUPPORT_TICKET`, `UPDATE_SUPPORT_TICKET` 기록

- support_tickets 처리 컬럼 및 인덱스 추가
  - Flyway migration `V7__support_ticket_admin_resolution.sql` 추가
  - `support_tickets.resolution_note` 추가
  - `support_tickets.resolved_by_admin_id` 추가
  - `support_tickets.resolved_at` 추가
  - Admin 목록 필터링을 위한 `idx_support_tickets_status_created_at` 인덱스 추가

- Admin overview 통계 보강
  - `/admin/system/overview` 응답에 `openSupportTicketCount` 추가
  - `OPEN`, `IN_PROGRESS` 상태 문의를 미처리 문의로 집계
  - Admin Web Overview에 `Open Tickets` metric 표시

- Admin Web Tickets 화면 추가
  - sidebar에 `Tickets` 탭 추가
  - 문의 상태 필터 `OPEN`, `IN_PROGRESS`, `RESOLVED` 추가
  - 문의 목록과 선택된 문의 상세 패널 추가
  - 상세 패널에 제출 사용자, 관련 lobby ID, category, title, body, 처리 Admin 표시
  - 처리 상태와 처리 메모를 입력해 문의 상태를 갱신하는 폼 추가
  - 처리 성공 후 문의 목록과 overview 통계 재조회

- Admin Web API client 확장
  - `SupportTicketPage`, `SupportTicketSummary`, `SupportTicketDetail` TypeScript 타입 추가
  - `getSupportTickets()`, `getSupportTicket()`, `updateSupportTicket()` 추가

- SDD 문서 갱신
  - `6_관리자_사용자조정&계정관리&모니터링.md`에 Direct Contact 지원 문의 처리 시스템, API, DB, 감사 로그, 시퀀스 추가
  - `7_API_목록_정리.md`에 Admin support ticket API 3개 추가
  - `8_DB_목록_정리.md`와 `2_프로필&이력&평가&도움말.md`의 `support_tickets` 컬럼 설명 갱신

#### 수정 파일

- `backend/src/main/java/kr/kaist/buddies/admin/AdminController.java`
- `backend/src/main/java/kr/kaist/buddies/admin/AdminService.java`
- `backend/src/main/resources/db/migration/V7__support_ticket_admin_resolution.sql`
- `admin-web/src/apiClient.ts`
- `admin-web/src/main.tsx`
- `admin-web/src/styles.css`
- `buddies-doc/SDD/2_프로필&이력&평가&도움말.md`
- `buddies-doc/SDD/6_관리자_사용자조정&계정관리&모니터링.md`
- `buddies-doc/SDD/7_API_목록_정리.md`
- `buddies-doc/SDD/8_DB_목록_정리.md`
- `reports/development-log.md`

#### SRS/SDD 충족 확인

- Direct Contact 문의 운영 대응
  - 사용자가 생성한 `support_tickets`를 Admin이 조회하고 상태를 갱신할 수 있도록 Admin API와 화면을 연결
  - 문의를 삭제하지 않고 처리 메모, 처리자, 처리 시각을 보관

- Admin 시스템 모니터링
  - Admin overview에서 미처리 support ticket 수를 확인할 수 있도록 `openSupportTicketCount` 추가

- Admin 감사 로그
  - 지원 문의 상세 조회와 상태 갱신 작업을 `admin_audit_logs`에 기록

#### 검증

- `admin-web`에서 `npm.cmd install` 실행 후 dependency 설치 성공
- `admin-web`에서 `npm.cmd run build` 성공
- 최초 `npm run build`는 PowerShell 실행 정책과 Vite/esbuild sandbox 읽기 제한으로 실패했으나, `npm.cmd`와 승인된 빌드 실행으로 검증 완료
- 현재 환경에는 `mvnw`와 `mvn` 명령이 없어 Maven build/test는 수행하지 못했다.
- `rg`로 Admin support ticket API, `openSupportTicketCount`, `resolution_note`, SDD support ticket 문서 반영 위치를 확인했다.

#### 남은 작업

- Maven wrapper 추가 또는 Maven 설치 후 backend compile/test 실행
- 실제 DB migration 적용 후 support ticket 목록/상세/상태 갱신 end-to-end 확인
- 실제 ADMIN 계정 JWT로 Admin Web Tickets 탭에서 문의 처리 흐름 확인
- 사용자 앱에서 처리 완료된 문의 상태 또는 답변을 사용자에게 다시 보여줄지 정책 결정
