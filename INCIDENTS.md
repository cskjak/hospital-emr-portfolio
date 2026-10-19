# 장애 기록

이 포트폴리오 DB(Oracle 26ai Free)를 쓰면서 실제로 겪은 장애를 alert log 기준으로 적는다.

| 번호 | 증상 | 원인 | 상태 |
|---|---|---|---|
| 1 | 부팅 뒤 DB가 MOUNTED에서 멈춤 | 데이터 파일이 있는 X: 드라이브가 부팅 때 없음 | 원인 확정 · 재발 방지 미정 |
| 2 | 인스턴스가 꺼져 있음 (ORA-01034) | 확인 중 | 복구 방법만 확인 |

## 1. 부팅 뒤 MOUNTED에서 멈춤

### 환경
- 테이블스페이스 `HOSPITAL`의 데이터 파일 `X:\ORADATA\HOSPITAL01.DBF`는 X: 드라이브에 있다. 컨트롤 파일은 C:에 있다.
- X:는 BitLocker로 암호화한 가상 디스크(vhdx)다. 쓰지 않을 때는 꺼내 둔다.
- Oracle 서비스(`OracleServiceFREE`)는 자동 시작(`AUTO_START`)이다.

### 증상
- 서비스는 RUNNING인데 `emr` 계정 접속이 `ORA-12514`로 실패한다.
- `sqlplus / as sysdba`로 일반 조회를 하면 `ORA-01219`(DB가 열려 있지 않음)가 난다.
- `SELECT status FROM v$instance;` → `MOUNTED`

### 증거 (alert log)
`C:\app\<사용자>\product\26ai\diag\rdbms\free\free\trace\alert_free.log`

```
2026-10-17T17:26:13  Starting ORACLE instance (normal)
2026-10-17T17:26:20  Database mounted in Exclusive Mode
alter database open
ORA-01157: …
ORA-01110: … 'X:\ORADATA\HOSPITAL01.DBF'
O/S-Error: (OS 2) …
ORA-1157 signalled during: alter database open...
```
(한글 메시지는 로그에 깨진 채 저장돼 있어 번호만 남겼다.)

| 번호 | 뜻 |
|---|---|
| ORA-01157 | 데이터 파일 17번을 찾을 수 없음 |
| ORA-01110 | 17번 = `X:\ORADATA\HOSPITAL01.DBF` |
| OS 2 | Windows: 지정된 파일을 찾을 수 없음 |

9/26 ~ 10/19 alert log에서 인스턴스 시작은 23번, 그중 `ORA-1157`로 OPEN에 실패한 게 14번이다.

| 시각 (로그) | 일어난 일 | 결과 |
|---|---|---|
| 10/14 05:32 | 부팅 → 자동 시작 → ORA-01157 | MOUNTED |
| 10/14 20:13 | `ALTER DATABASE OPEN` | 열림 |
| 10/17 17:26 | 부팅 → 자동 시작 → ORA-01157 | MOUNTED |
| 10/18 08:34 | `ALTER DATABASE OPEN` | 열림 |

### 원인
X:는 암호화해서 평소에 꺼내 둔다. 부팅하면 X:가 없는 상태에서 서비스가 인스턴스를 자동으로 시작한다. MOUNT는 C:의 컨트롤 파일만 있으면 되므로 성공하지만, OPEN 단계에서 X:의 데이터 파일을 찾지 못해 멈춘다.

### 복구
```sql
-- 먼저 X: 드라이브를 붙인다 (vhdx 열기 → BitLocker 비밀번호)
sqlplus / as sysdba
SELECT status FROM v$instance;   -- MOUNTED
ALTER DATABASE OPEN;
SELECT status FROM v$instance;   -- OPEN
SHOW PDBS                        -- FREEPDB1 READ WRITE
```

### 재발 방지 (미정)
| 방법 | 장점 | 단점 |
|---|---|---|
| 지금처럼 두고, 쓸 때마다 `ALTER DATABASE OPEN` | 암호화 유지 | 매번 수동 |
| 서비스를 수동 시작으로 바꾸기 | 실패 기록이 안 쌓임 | 쓸 때마다 `STARTUP` |
| 데이터 파일을 C:로 옮기기 | 부팅하면 자동으로 열림 | 암호화 보호가 사라짐 |

데이터 보호와 자동으로 열리는 편의 중 하나를 골라야 하는 문제다.

**배운 점:** 겉으로는 정상 실행인 것처럼 보였지만, 실제 원인은 드라이브 암호화 및 꺼내기 동작이었고, 그 때문에 DB가 마운트 상태에서 멈춰 있었다.

## 2. 인스턴스가 꺼져 있음 (ORA-01034) — 원인 확인 중
- 증상: `sqlplus / as sysdba` 뒤 조회 → `ORA-01034`
- 복구: `STARTUP` → `SHOW PDBS`로 FREEPDB1 READ WRITE 확인
- 확인된 것: 10/17 08:16, 10/19 18:25의 수동 `STARTUP` 전에, 그날 자동 시작 기록이 alert log에 없다.
- 다음 확인: Windows 이벤트 로그에서 그날 Oracle 서비스가 시작됐는지
