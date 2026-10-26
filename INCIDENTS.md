# 장애 기록

이 포트폴리오 DB(Oracle 26ai Free)를 쓰면서 실제로 겪은 장애를 alert log 기준으로 적는다.

| 번호 | 증상 | 원인 | 상태 |
|---|---|---|---|
| 1 | 부팅 뒤 DB가 MOUNTED에서 멈춤 | X:를 꺼낸 채 부팅 | 원인 확정 · 재발 방지 미정 |
| 2 | 인스턴스가 꺼져 있음 (ORA-01034) | DB가 켜진 채 X:를 꺼냄 | 원인 확정 · 순서로 막음 |
| 3 | 전체 DB는 열렸는데 FREEPDB1만 MOUNTED | 정상 종료 뒤 X:를 꺼낸 채 재부팅 | 원인 확정 · 1번과 다른 이유는 추정 |
| 4 | 부팅 뒤 인스턴스가 STARTED에서 멈춤 · `STARTUP`은 ORA-01081 | 자동 시작 도중 Oracle 내부 오류 (ORA-00600) | 내부 오류의 원인은 확인 못 함 · 1번 발생 |

1~3번은 X: 꺼내기에서 시작한다. 꺼내고 재부팅하면 1번(정상 종료 뒤였으면 3번), DB가 켜진 채 꺼내면 2번이다. 4번은 3번과 같은 순서로 재부팅했지만, X:의 파일을 쓰기도 전인 시작 단계에서 Oracle 내부 오류로 멈췄다.

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

## 2. 인스턴스가 꺼져 있음 (ORA-01034)

### 증상
- `sqlplus / as sysdba`로 들어가 조회하면 `ORA-01034`(인스턴스를 사용할 수 없음)가 난다.
- 서비스는 RUNNING이고, 그 사이 재부팅은 없었다.

### 증거 1 (alert log)
시각 줄과 메시지 줄을 한 줄로 붙였다.

```
2026-10-18T16:18:43  ORA-27037: 파일 상태를 얻을 수 없습니다        (16:28 · 16:38에도 반복)
2026-10-18T16:44:11  ORA-01242: 데이터 파일이 메디아 실패를 받았습니다: 데이터베이스는 NOARCHIVELOG 모드입니다
                     ORA-01110: 17 데이터 파일: 'X:\ORADATA\HOSPITAL01.DBF'
2026-10-18T16:44:13  CKPT (ospid: 5952_8792): terminating the instance due to ORA error 1242
2026-10-18T16:44:33  Instance terminated by CKPT, PID = 5952_8792
```

| 단어 | 뜻 |
|---|---|
| ORA-27037 | 파일 상태를 얻을 수 없음 (X:가 없음) |
| ORA-01242 | 데이터 파일 고장(미디어 실패) |
| CKPT | 메모리 내용을 주기적으로 데이터 파일에 적는 Oracle 프로세스 |

### 증거 2 (Windows 가상 디스크 기록)
Windows 로그 `Microsoft-Windows-VHDMP-Operational`에 가상 디스크를 붙이고(ID 1) 꺼낸(ID 2) 시각이 남아 있다.

```powershell
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-VHDMP-Operational'; Id=1,2}
```

| X: 꺼낸 시각 (Windows) | 그 뒤 Oracle (alert log) | 장애 |
|---|---|---|
| 10/14 05:29 | 05:31 재부팅 → 05:32 자동 시작 → ORA-01157 | 1번 MOUNTED |
| 10/15 01:17 | 01:24부터 10분마다 ORA-27037 → 12:05 CKPT 종료 | 2번 꺼짐 |
| 10/17 11:39 | 12:37 CKPT 종료 | 2번 꺼짐 |
| 10/17 17:24 | 17:25 재부팅 → 17:26 자동 시작 → ORA-01157 | 1번 MOUNTED |
| 10/18 16:11 | 16:18부터 ORA-27037 → 16:44 CKPT 종료 | 2번 꺼짐 |

X:를 붙인 기록(10/17 08:11 · 10/18 08:23 · 10/19 18:20)은 몇 분 뒤 `STARTUP`이나 `ALTER DATABASE OPEN`을 한 시각과 짝이 맞는다.

### 원인
DB가 열린 채로 X:를 꺼냈다. 데이터 파일을 읽고 쓸 수 없게 되자 CKPT가 인스턴스를 종료했다. 재부팅을 하지 않아 서비스는 RUNNING인 채 인스턴스만 꺼져 있었고, 다음 접속 때 ORA-01034가 났다. alert log에는 9/26 이후 `SHUTDOWN` 기록이 한 번도 없다.

에러 메시지에 NOARCHIVELOG 모드가 함께 찍혀 있다. 이 모드와 인스턴스 종료의 관계는 [BACKUP.md](BACKUP.md) C에 정리했다.

### 복구
```sql
-- 먼저 X: 드라이브를 붙인다 (vhdx 열기 → BitLocker 비밀번호)
sqlplus / as sysdba
STARTUP
SHOW PDBS                        -- FREEPDB1 READ WRITE
```

### 재발 방지
| | 1단계 | 2단계 |
|---|---|---|
| 켤 때 | X: 붙이기 | `STARTUP` / `ALTER DATABASE OPEN` |
| 끌 때 | `SHUTDOWN IMMEDIATE` | X: 꺼내기 |

**배운 점:** 오라클이 켜져 있는 동안 X:는 항상 붙어 있어야 한다. 오라클을 실행하기 전에 반드시 X:를 붙이고 암호화를 해제한 다음 실행해야 마운트 상태에서 멈추지 않고 정상 작동한다. X:를 꺼내기 전에는 오라클 종료를 먼저 해야 한다.

## 3. 전체 DB는 열렸는데 FREEPDB1만 MOUNTED

### 증상
- `emr` 접속이 `ORA-01109`(데이터베이스가 개방되지 않음)로 실패한다.
- `SELECT status FROM v$instance;` → `OPEN` (1번과 다르다)
- `SELECT name, open_mode FROM v$pdbs;` → `FREEPDB1  MOUNTED`

### 증거 (alert log + Windows 기록)

| 시각 (10/20) | 일어난 일 | 근거 |
|---|---|---|
| 03:06:57 | `SHUTDOWN IMMEDIATE` 완료 | alert log `Instance shutdown complete` |
| 03:07:43 | X: 꺼냄 | `VHDMP-Operational` ID 2 |
| 05:24:07 | 시작 메뉴에서 다시 시작 | `System` ID 1074 (`다시 시작`) |
| 05:25:12 | 서비스가 인스턴스 자동 시작 | alert log `Starting ORACLE instance` |
| 05:25:29 | FREEPDB1을 열다가 ORA-01157 (`X:\ORADATA\HOSPITAL01.DBF`) → 전체 DB는 `Completed: alter database open` | alert log |
| 18:15:06 | X: 붙임 | `VHDMP-Operational` ID 1 |
| 18:22:16 | `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN` → READ WRITE | alert log |

### 원인
1번과 같다. X:가 없는 상태에서 재부팅되어 서비스가 인스턴스를 자동으로 시작했고, X:의 데이터 파일을 찾지 못했다. 끌 때 순서(`SHUTDOWN IMMEDIATE` → X: 꺼내기)는 지켰다.

### 1번과 결과가 다른 이유

9/26 ~ 10/20 alert log에서 자동 시작이 ORA-01157로 실패한 기록을, 그 직전에 DB가 어떻게 끝났는지와 나란히 놓았다.

| 자동 시작 직전 DB가 끝난 방식 | 결과 | 횟수 |
|---|---|---|
| 종료 기록 없음 · CKPT 강제 종료 | 전체 DB가 MOUNTED (`ORA-1157 signalled during: alter database open`) | 1번 장애 전부 |
| `SHUTDOWN IMMEDIATE` 정상 종료 | 전체 DB는 OPEN, FREEPDB1만 MOUNTED | 1번 (10/20) |

- **확정:** 정상 종료 뒤의 자동 시작은 10/20이 처음이고, 결과가 다른 것도 이때 한 번뿐이다.
- **추정 (사례 1번):** 비정상으로 끝난 DB는 다음에 열 때 모든 데이터 파일을 맞추는 복구를 먼저 하므로 X: 파일이 없으면 전체가 멈춘다. 정상 종료였으면 그 복구가 필요 없어 전체 DB는 열리고, X: 파일을 쓰는 FREEPDB1만 못 연다.

### 복구
```sql
-- 먼저 X: 드라이브를 붙인다 (vhdx 열기 → BitLocker 비밀번호)
sqlplus / as sysdba
SELECT status FROM v$instance;                  -- OPEN
SELECT name, open_mode FROM v$pdbs;             -- FREEPDB1 MOUNTED
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
SELECT name, open_mode FROM v$pdbs;             -- FREEPDB1 READ WRITE
```

### 재발 방지
1번과 같다(미정). 서비스가 자동 시작인 한, X:를 꺼낸 채 재부팅하면 다시 난다.

**배운 점:** 끌 때 순서(SHUTDOWN → X: 꺼내기)를 지켜도, X:를 꺼낸 채로 PC를 재부팅 하면 Oracle이 자동으로 켜지면서 FREEPDB1이 멈춘다. 그래서 `v$instance`가 OPEN이어도 `v$pdbs` 까지 확인해야 한다.

## 4. 부팅 뒤 인스턴스가 STARTED에서 멈춤 (ORA-00600)

### 증상
- `sqlplus / as sysdba`는 접속됐다. 2번 때와 달리 휴지 인스턴스가 아니라, 떠 있는 인스턴스에 접속됐다.
- `STARTUP` → `ORA-01081` (이미 떠 있는 인스턴스는 다시 시작할 수 없음)
- `SELECT status FROM v$instance;` → `STARTED`
- `SELECT open_mode FROM v$database;` → `ORA-01507` (데이터베이스가 마운트되지 않음)

인스턴스가 거치는 네 상태 중 STARTED는 이 기록에서 처음 나온 상태다.

| 상태 | 무엇까지 열렸나 | 이 기록에서 |
|---|---|---|
| 꺼짐 | 아무것도 없음 | 2번 (ORA-01034) |
| STARTED | 메모리와 프로세스만 떠 있음. 파일은 하나도 안 열림 | **4번** |
| MOUNTED | C:의 컨트롤 파일까지 | 1번 · 3번(FREEPDB1만) |
| OPEN | 데이터 파일까지 | 정상 |

### 증거 (alert log + Windows 기록)

| 시각 (10/26) | 일어난 일 | 근거 |
|---|---|---|
| 00:58:58 | `SHUTDOWN IMMEDIATE` 완료 | alert log `Instance shutdown complete` |
| 05:03:45 | X: 꺼냄 | `VHDMP-Operational` ID 2 |
| 05:03:57 | 시작 메뉴에서 다시 시작 | `System` ID 1074 |
| 05:04:57 | 서비스가 인스턴스 자동 시작 | alert log `Starting ORACLE instance` |
| 05:04:58 | 시작 도중 ORA-07445 · ORA-00600 → 그 뒤로 아무 기록 없음 | alert log |
| 19:41:10 | X: 붙임 | `VHDMP-Operational` ID 1 |
| 19:45:16 | `STARTUP` → ORA-01081 | alert log `Shared memory area is accessible …` |
| 20:07:23 | `SHUTDOWN ABORT` | alert log `Instance shutdown (abort) complete` |
| 20:07:41 | `STARTUP` → 마운트 → 열림 | alert log `FREEPDB1 opened read write` · `Completed: ALTER DATABASE OPEN` |

```
2026-10-26T05:04:57  Starting ORACLE instance (normal)
                     Using parameter settings in server-side spfile C:\APP\<사용자>\…\SPFILEFREE.ORA
2026-10-26T05:04:58  Exception [type: ACCESS_VIOLATION, UNABLE_TO_READ] […, kghalf()+2343]
                     ORA-07445: exception encountered: core dump [kghalf()+2343] [ACCESS_VIOLATION] …
                     ORA-00600: internal error code, arguments: [17114], …
2026-10-26T19:45:16  ERROR: Shared memory area is accessible to instance startup process
                     prior to instance startup operation.
```

| 번호 | 뜻 |
|---|---|
| ORA-00600 | Oracle 내부 오류. Oracle 코드 안에서 예상하지 못한 상황이 생겼다는 뜻 |
| ORA-07445 | Oracle 프로세스가 읽을 수 없는 메모리 주소를 읽으려다 멈춤 (ACCESS_VIOLATION) |
| ORA-01081 | 이미 떠 있는 인스턴스는 다시 시작할 수 없음 |
| ORA-01507 | 데이터베이스가 마운트되지 않음 |

### 원인
- **확정:** 자동 시작 1초 만에 Oracle 내부 오류가 나서 STARTED에서 멈췄다. 그 뒤에 `Database mounted` 줄이 없으므로 MOUNT 전 단계다.
- **확정:** alert log 전체(9/26~)에서 인스턴스 시작은 30번이고, ORA-00600은 이번 1번뿐이다.
- **추정:** X:와는 관계없다. MOUNT 전 단계에서는 C:의 파라미터 파일만 읽고, X:의 데이터 파일은 아직 쓰지 않는다. 3번과 같은 순서(정상 종료 → X: 꺼냄 → 시작 메뉴에서 재시작)였지만, 3번 때는 이 오류가 없었다.
- **확인 못 함:** ORA-00600이 왜 났는지. 내부 오류라 alert log만으로는 알 수 없다. 자세한 기록은 trace 파일 `free_ora_5572.trc`에 있다.

### 복구
```sql
-- X:는 미리 붙여 두었다 (19:41)
sqlplus / as sysdba
STARTUP                              -- ORA-01081 (이미 떠 있음)
SELECT status FROM v$instance;       -- STARTED
SELECT open_mode FROM v$database;    -- ORA-01507 (마운트 안 됨 = 열린 파일 없음)
SHUTDOWN ABORT
STARTUP                              -- 마운트 → 열림
SELECT status FROM v$instance;       -- OPEN
```

`SHUTDOWN IMMEDIATE`는 열린 파일을 정리하면서 끄는 명령이다. 이번에는 시작 도중에 멈춰 열린 파일이 없었으므로(ORA-01507), `SHUTDOWN ABORT`로 남은 메모리와 프로세스만 치웠다. 다시 켠 뒤 FREEPDB1도 함께 열렸고(alert log `opened read write`), 리두 로그는 00:58에 닫을 때와 같은 32번에서 다시 열렸다(`Thread 1 closed at log sequence 32` → `Thread 1 opened at log sequence 32`).

### 재발 방지
원인을 모르므로 막을 방법도 아직 없다. 한 번뿐이어서 지켜본다. 같은 일이 생기면 위 순서대로 복구하고, alert log에 ORA-00600이 또 찍혔는지 확인한다.

**배운 점:** `STARTUP`은 ORA-01081로 거부됐다. 이미 실행된 상태였기 때문이다. `v$instance`를 조회하니 STARTED 상태였고, `v$database`를 조회하니 열린 파일은 없었다. `SHUTDOWN ABORT`를 실행한 뒤 `STARTUP`을 하니 마운트되고 열렸다. 그래서 `STARTUP`이 ORA-01081로 거부되면 `v$instance`로 지금 상태를 보고, `SHUTDOWN ABORT`를 하기 전에는 `v$database`로 열린 파일이 있는지 확인한다.
