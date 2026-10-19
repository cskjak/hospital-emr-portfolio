# 장애 기록

이 포트폴리오 DB(Oracle 26ai Free)를 쓰면서 실제로 겪은 장애를 alert log 기준으로 적는다.

| 번호 | 증상 | 원인 | 상태 |
|---|---|---|---|
| 1 | 부팅 뒤 DB가 MOUNTED에서 멈춤 | X:를 꺼낸 채 부팅 | 원인 확정 · 재발 방지 미정 |
| 2 | 인스턴스가 꺼져 있음 (ORA-01034) | DB가 켜진 채 X:를 꺼냄 | 원인 확정 · 순서로 막음 |

두 장애 모두 X: 꺼내기에서 시작한다. 꺼내고 재부팅하면 1번, DB가 켜진 채 꺼내면 2번이다.

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
