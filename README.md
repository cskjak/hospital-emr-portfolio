# 🏥 가상 병원 외래 DB — Oracle DBA 포트폴리오

의료기관 전산 운영 업무를 하면서 DB 쪽에 관심이 생겨, 가상 병원 외래 DB를 직접 설계해 Oracle에 올렸습니다. 이 DB를 쓰면서 실제로 겪은 장애 4건과, 백업·복구 · 세션·락 · 느린 SQL · 공간 · 권한을 직접 해 보며 확인한 기록입니다.

**환경** Oracle AI Database 26ai Free · Windows · SQL\*Plus · RMAN · Data Pump · SQL\*Loader · PowerShell

> ⚠️ **모든 데이터는 무작위로 만든 가상 데이터입니다.** 실제 병원·환자·의료진과 무관합니다.

## 실제로 겪은 장애 — [INCIDENTS.md](INCIDENTS.md)

테이블스페이스 `HOSPITAL`의 데이터 파일(`X:\ORADATA\HOSPITAL01.DBF`)은 BitLocker로 암호화한 가상 디스크 X:에 두고, 쓰지 않을 때는 꺼내 둔다. 1~3번은 X:를 꺼내는 데서 시작했고, 재발 방지는 X:를 안 쓸 때 HOSPITAL을 OFFLINE으로 두는 것으로 정해 시험했다.

| 증상 | 확인한 것 | 조치 | 원인 |
|---|---|---|---|
| 1. 부팅 뒤 접속 실패 (ORA-12514) | `v$instance` MOUNTED · alert log ORA-01157 | X: 붙이기 → `ALTER DATABASE OPEN` | X:를 꺼낸 채 부팅 → 서비스가 인스턴스를 자동 시작 |
| 2. 인스턴스 꺼짐 (ORA-01034) | alert log ORA-01242 → CKPT가 인스턴스 종료 | X: 붙이기 → `STARTUP` | DB가 켜진 채 X:를 꺼냄 |
| 3. FREEPDB1만 MOUNTED (ORA-01109) | `v$instance` OPEN · `v$pdbs` MOUNTED | `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN` | 정상 종료 뒤 X:를 꺼낸 채 재부팅 |
| 4. `STARTUP` 거부 (ORA-01081) | `v$instance` STARTED · `v$database` ORA-01507 | `SHUTDOWN ABORT` → `STARTUP` | 자동 시작 중 Oracle 내부 오류(ORA-00600) · 내부 오류의 원인은 확인 못 함 |

원인은 alert log와 Windows 이벤트 로그(가상 디스크를 붙이고 꺼낸 시각)를 맞춰 보며 찾았고, 확정한 것 · 추정한 것 · 확인 못 한 것을 나눠 적었다.

장애를 겪고 정한 순서:

- X:를 안 쓸 때는 HOSPITAL 테이블스페이스를 OFFLINE으로 둔다. X: 없이 재부팅해도 DB와 FREEPDB1이 저절로 열린다 (11/06 시험 · 비정상 종료 뒤에도 열림)
- 쓸 때는 X: 붙이기 → `ALTER TABLESPACE hospital ONLINE`, 다 쓰면 `OFFLINE` → X: 꺼내기
- `v$instance`가 OPEN이어도 `v$pdbs`까지 확인한다
- `STARTUP`이 ORA-01081로 거부되면 `v$instance`로 상태를 보고, `v$database`로 열린 파일이 없는지 확인한 뒤 `SHUTDOWN ABORT`

## 직접 해 본 실습

| 상황 | 해 보고 확인한 것 |
|---|---|
| 데이터 손실<br>[BACKUP.md](BACKUP.md) | 휴지통 · Data Pump · RMAN 백업 · ARCHIVELOG 전환 · 데이터 파일을 지운 뒤 `RESTORE` → `RECOVER`로 백업 뒤에 넣은 줄까지 되살림 |
| 화면 응답 없음<br>[LOCKS.md](LOCKS.md) | `v$session`의 `BLOCKING_SESSION`으로 막은 세션 찾기 · 데드락(ORA-00060)을 alert log → trace 파일까지 따라감 |
| DB 느림<br>[SLOW_SQL.md](SLOW_SQL.md) | `v$session`과 `v$sql`을 SQL_ID로 이어 오래 도는 SQL 찾기 → `ALTER SYSTEM CANCEL SQL`로 세션은 두고 그 SQL만 취소 |
| 디스크 부족<br>[SPACE.md](SPACE.md) | 사용률(%)의 분모 찾기 · 아카이브가 92MB 생겨도 사용률은 1.1% 그대로인데 분모(C: 남은 공간)는 92MB 줄어듦 · 같은 디스크에 백업하면 아카이브를 지워도 공간이 거의 안 돌아옴 |
| 읽기 전용 계정<br>[PRIVILEGES.md](PRIVILEGES.md) | 계정 · ROLE · `GRANT` / `REVOKE` · 조회 권한이 없으면 테이블이 "존재하지 않는다"(ORA-00942)고 나옴 |
| 잘못된 값 입력<br>[SQL.md](SQL.md) 44번 | 이미 데이터가 있는 테이블에 CHECK 제약 추가 · 규칙을 어기는 줄은 ORA-02290으로 거부 · 빈칸(NULL)은 CHECK가 막지 않아 NOT NULL이 따로 필요 |

## SQL 실습 — [SQL.md](SQL.md)

외래 데이터(접수 9,362건)로 SQL 실습 36개(9~44번)를 했다. 쿼리마다 기준 숫자를 먼저 정하고, 틀린 쿼리와 맞는 쿼리를 나란히 놓고 비교했다. 예: 접수를 `dept_id`로 의사와 이으면 9,362건이 28,086줄(3배)이 된다(9번).

| 번호 | 내용 |
|---|---|
| 1~8 | 테이블 구조 · 컬럼 설명 · 데이터 규칙 · 검산 · Oracle에 넣는 방법 |
| 9~29 | JOIN 키 검증 · LEFT JOIN으로 없는 행 찾기 · GROUP BY / HAVING · 윈도우 함수 · DECODE · CASE · 날짜 계산(대기 시간) |
| 30~40 | 권한 테이블(역할 · 메뉴) — 셀프 조인 · 테이블 4개 JOIN · `ON`과 `WHERE`의 차이 |
| 41~42 | 실행계획 — 인덱스 전후 비교(FULL Cost 17 → INDEX RANGE SCAN Cost 3) · 인덱스가 있어도 FULL을 고르는 경우 |
| 43 | 인라인 뷰 (묶은 결과를 다시 묶기) |
| 44 | CHECK 제약 — 규칙을 DB가 지키게 하기 (ORA-02290 · 빈칸은 CHECK를 통과) |

25번에서 한 실수(조인 조건 양쪽에 같은 별칭 → 약 8,200만 줄)는 [SLOW_SQL.md](SLOW_SQL.md)에서 일부러 느린 SQL로 다시 썼다.

## DB 구성

| 항목 | 내용 |
|---|---|
| DB | Oracle AI Database 26ai Free · 문자셋 AL32UTF8 |
| 구성 | 인스턴스 `FREE` · PDB `FREEPDB1` · 스키마 `emr` |
| 데이터 파일 | 테이블스페이스 `HOSPITAL` → `X:\ORADATA\HOSPITAL01.DBF` (최대 500MB) · 안 쓸 때는 OFFLINE |
| 컨트롤 파일 | C: — X:가 없어도 MOUNT까지는 된다 (장애 1번) |
| 로그 모드 | ARCHIVELOG ([BACKUP.md](BACKUP.md) D에서 전환) |
| 리두 · 아카이브 | 리두 로그 3개 × 200MB · 아카이브 `C:\oracle_archive` |
| 백업 | RMAN → `C:\oracle_backup` · Data Pump → `DATA_PUMP_DIR` |
| 서비스 | `OracleServiceFREE` 자동 시작 |

테이블 11개(진료 7 + 권한 4) · 환자 4,853명 · 접수 9,362건 · 진료 8,960건 · 수납 8,787건 · 기간 2026-01-02 ~ 2026-06-30 (6개월)

진료 테이블 7개

```
department ──< doctor ──< doctor_schedule
     │            │
     └────< reception >──── patient
                 │
         ┌───────┴───────┐
     treatment        payment
     (0 또는 1건)      (0 또는 1건)
```

권한 테이블 4개

```
role ──< staff ───── doctor      (의사만 이어짐)
  │        └──────── department  (의사·간호사만 이어짐)
  │
  └──< role_menu >── menu ──< menu  (상위 메뉴 → 하위 메뉴)
```

`──<` 는 "하나 → 여러 개"다. 예: 진료과 1개에 의사 여러 명.

데이터는 `scripts/`의 PowerShell 생성기로 만들었다(시드 고정 → 다시 돌려도 같은 값). 컬럼 설명과 데이터 규칙은 [SQL.md](SQL.md) 1~7번에 있다.

## 직접 만들어 보기

Windows · Oracle 26ai Free 기준이다. 테이블을 만들 권한이 있는 `emr` 계정이 미리 있어야 하고, 모든 명령은 **저장소 맨 위 폴더에서** 실행한다.

1. SQL\*Plus로 접속한다

   ```
   sqlplus emr@//localhost:1521/FREEPDB1
   ```

   비밀번호를 넣고 `SQL>` 프롬프트가 나오면 한 줄씩 친다.

   ```
   @sql/01_create_tables.sql
   @sql/02_create_auth_tables.sql
   exit
   ```

2. CSV 11개를 적재한다

   ```
   powershell -ExecutionPolicy Bypass -File scripts\load_data.ps1
   ```

`load_data.ps1`은 비밀번호를 한 번만 묻고, CSV 11개를 부모 테이블부터 차례로 넣는다. `-ExecutionPolicy Bypass`는 이번 실행에만 스크립트를 허용하고 PC의 실행 정책은 바꾸지 않는다. 하나씩 넣는 방법은 [SQL.md](SQL.md) 8번, 넣은 뒤 맞춰 볼 행 수는 2번 표에 있다.

## 폴더 구성

```
├── INCIDENTS.md     장애 기록 1~4
├── BACKUP.md        백업·복구 A~F
├── LOCKS.md         세션·락 A~B
├── SLOW_SQL.md      느린 SQL
├── SPACE.md         공간 A~C
├── PRIVILEGES.md    DB 권한
├── SQL.md           데이터 구조 1~8 · SQL 실습 9~44
├── data/            CSV 11개 (가상 데이터)
├── sql/             테이블 생성 SQL 2개 · CHECK 제약 추가 1개 · load/에 SQL*Loader 설정 11개
└── scripts/         CSV 적재 스크립트 1개 · 가상 데이터 생성기 2개 (PowerShell · 시드 고정)
```
