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
