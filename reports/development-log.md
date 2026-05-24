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

- 서버 `AuthService`에서 client-provided SHA-256 OTP/reset token 값을 실제 DB hash와 비교하도록 구현
- 서버 비밀번호 저장/검증에 `BCryptPasswordEncoder` 적용
- JWT 발급/검증 필터 및 logout token invalidation 저장소 구현
- 모바일 JWT 저장소를 platform secure storage로 교체
