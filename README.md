# 🏥 가상 병원 외래 데이터 — SQL 포트폴리오

> ⚠️ **모든 데이터는 무작위로 만든 가상 데이터입니다.** 실제 병원·환자·의료진과 무관합니다.
> 기간: **2026-01-02 ~ 2026-06-30 (6개월)** · 생성: `scripts/generate_data.ps1` (시드 고정 → 다시 돌려도 같은 값)

---

## 1. 전체 구조

```
department ──< doctor ──< doctor_schedule
     │            │
     └────< reception >──── patient
                 │
         ┌───────┴───────┐
     treatment        payment
     (0 또는 1건)      (0 또는 1건)
```

`──<` 는 "하나 → 여러 개" 입니다. 예: 진료과 1개에 의사 여러 명.

## 2. 테이블 요약

| 파일 | 행 수 | 한 행의 의미 |
|---|---:|---|
| `department.csv` | 8 | 진료과 하나 |
| `doctor.csv` | 24 | 의사 한 명 (과마다 3명) |
| `doctor_schedule.csv` | 48 | 의사의 외래 한 칸 (예: 목요일 오후) |
| `patient.csv` | 4,853 | 환자 한 명 |
| `reception.csv` | 9,362 | 접수 한 건 (취소 402건 포함) |
| `treatment.csv` | 8,960 | 진료 한 건 (취소 안 된 접수마다 1건) |
| `payment.csv` | 8,787 | 수납 한 건 (미수납 173건은 행이 없음) |

## 3. 컬럼 설명

### department — 진료과
| 컬럼 | 형식 | 설명 |
|---|---|---|
| dept_id | 정수 | 기본키 (1~8) |
| dept_code | 문자 2자리 | GI, CV, EN, OS, NR, PD, DM, OP |
| dept_name | 문자 | 소화기내과, 순환기내과, 내분비내과, 정형외과, 신경과, 소아청소년과, 피부과, 안과 |
| floor | 정수 | 외래 층 |

### doctor — 의사
| 컬럼 | 형식 | 설명 |
|---|---|---|
| doctor_id | 정수 | 기본키 (1001~1024) |
| doctor_name | 문자 | 가상 이름 |
| dept_id | 정수 | → department.dept_id |
| position | 문자 | 교수 / 부교수 / 조교수 |
| hire_date | 날짜 | 임용일 (3월 1일 또는 9월 1일) |

### doctor_schedule — 외래 일정
| 컬럼 | 형식 | 설명 |
|---|---|---|
| doctor_id | 정수 | → doctor.doctor_id |
| weekday | 문자 | 월 / 화 / 수 / 목 / 금 |
| session_type | 문자 | AM (오전) / PM (오후) |

- 기본키는 **세 컬럼을 합친 것** (doctor_id + weekday + session_type)
- `session`은 Oracle 예약어라 `session_type`으로 이름 붙임
- 의사 1명당 주 2칸. 같은 과 의사끼리는 칸이 겹치지 않음

### patient — 환자
| 컬럼 | 형식 | 설명 |
|---|---|---|
| patient_id | 정수 8자리 | 기본키 · 차트번호 (등록 순서대로 10000001부터) |
| patient_name | 문자 | 가상 이름 (동명이인 있음) |
| gender | 문자 1자리 | M / F |
| birth_date | 날짜 | 생년월일 |
| phone | 문자 | `010-****-1234` 형식으로 가려진 번호 |
| registered_at | 일시 | 병원에 처음 등록한 일시 (2026년 이전도 있음) |

### reception — 접수
| 컬럼 | 형식 | 설명 |
|---|---|---|
| reception_id | 정수 | 기본키 (접수 시각 순서) |
| patient_id | 정수 | → patient.patient_id |
| dept_id | 정수 | → department.dept_id |
| doctor_id | 정수 | → doctor.doctor_id |
| reception_at | 일시 | 접수 일시 |
| visit_type | 문자 | 초진 / 재진 |
| status | 문자 | 정상 / 취소 |

### treatment — 진료
| 컬럼 | 형식 | 설명 |
|---|---|---|
| treatment_id | 정수 | 기본키 |
| reception_id | 정수 | → reception.reception_id (접수 1건당 최대 1건) |
| start_at | 일시 | 진료 시작 |
| end_at | 일시 | 진료 종료 |

### payment — 수납
| 컬럼 | 형식 | 설명 |
|---|---|---|
| payment_id | 정수 | 기본키 (수납 시각 순서) |
| reception_id | 정수 | → reception.reception_id (접수 1건당 최대 1건) |
| paid_at | 일시 | 수납 일시 |
| total_amount | 정수(원) | 총 진료비 |
| insurance_amount | 정수(원) | 공단 부담금 |
| patient_amount | 정수(원) | 본인 부담금 |
| method | 문자 | 카드 / 간편결제 / 현금 |

- 항상 `total_amount = insurance_amount + patient_amount`

## 4. 데이터에 넣은 규칙

| 규칙 | 내용 |
|---|---|
| 외래 요일 | 의사는 `doctor_schedule`에 있는 요일·세션에만 진료 |
| 공휴일 | 1/1, 2/16~18(설), 3/2, 5/5, 5/25, 6/3 은 외래 없음 · **주말 진료 없음** |
| 세션 시간 | 오전 09:00~, 오후 13:30~ · 접수는 오전 08:20~, 오후 12:50~ |
| 세션 정원 | 의사 1명이 한 세션에 최대 18명 |
| 대기시간 | 의사별로 도착 순서대로 줄을 세워 계산 → 이른 시간일수록 붐빔 |
| 진료 시간 | 초진 8~15분, 재진 3~8분 |
| 초진/재진 | 그 과에서 **완료된 진료가 전에 없으면 초진**. 2025년부터 다니던 환자는 기간 안에서 재진만 보임 |
| 재진 간격 | 2~8주 |
| 연령대 | 소아청소년과 1~17세, 순환기·신경·안과는 고령층 등 과마다 다름 |
| 여러 과 | 환자 약 20%는 두 번째 과에도 다님 |
| 취소 | 접수의 약 4% · 취소된 접수는 진료·수납 없음 |
| 미수납 | 진료의 약 2% · `payment` 행이 없음 |
| 진료비 | 초진 2.8~4.5만 원, 재진 1.8~3만 원, 35%는 검사비 추가 |
| 본인부담 | 총액의 60%, 100원 미만 버림 (단순화한 가정) |

## 5. 알아두면 좋은 점 (문제 거리)

- 설 연휴가 있는 **2월**, 공휴일이 이틀인 **5월**은 접수가 적음
- **접수만 하고 전부 취소한 환자**가 108명 있음 → 진료 기록이 없는 환자
- 미수납은 `payment`에 행이 **없는 것**으로 표현됨 → `payment`만 보면 안 보임
- `reception`에 `dept_id`와 `doctor_id`가 둘 다 있음 (의사를 보면 과를 알 수 있지만, 실제 EMR처럼 접수 과를 따로 저장)

## 6. 검산 기록 (생성 직후 확인, 전부 0건)

| 검사 | 결과 |
|---|---:|
| 접수한 과 ≠ 의사의 과 | 0 |
| 없는 환자를 참조하는 접수 | 0 |
| 등록일시가 접수일시보다 늦음 | 0 |
| 취소 접수에 진료나 수납이 있음 | 0 |
| 진료 시작이 접수보다 빠름 | 0 |
| 총액 ≠ 공단 + 본인 | 0 |
| 같은 접수에 수납 2건 | 0 |
| 세션 시간을 넘긴 진료 | 0 |

## 7. 파일 형식

- UTF-8 (BOM 없음) · 첫 줄은 컬럼명 · 구분자 쉼표 · 줄바꿈 LF
- 날짜 `YYYY-MM-DD` · 일시 `YYYY-MM-DD HH24:MI:SS`
- ⚠️ 엑셀로 바로 열면 한글이 깨질 수 있음 → **데이터 → 텍스트/CSV에서 가져오기**로 열 것

## 8. Oracle에 넣는 방법

환경: Oracle AI Database 26ai Free · 문자셋 AL32UTF8

```
sql/01_create_tables.sql   테이블 7개 생성 (PK · FK · CHECK 포함)
sql/load/*.ctl             SQL*Loader 설정 (CSV → 테이블)
scripts/generate_data.ps1  가상 데이터 생성기 (시드 고정)
```

1. SQL*Plus에서 `@sql/01_create_tables.sql`
2. 부모 테이블부터 적재: department → doctor → doctor_schedule → patient → reception → treatment → payment
   ```
   sqlldr userid=<계정>@//localhost:1521/FREEPDB1 control=sql/load/department.ctl
   ```
3. 적재 후 행 수가 2번 표와 같은지 확인

## 9. JOIN 키 검증

`reception`과 `doctor`에는 `doctor_id`, `dept_id`가 둘 다 있다. 어느 쪽으로 잇는지에 따라 결과가 달라진다.

| 연결 컬럼 | 결과 행 수 | 기준 (접수 9,362건) |
|---|---:|---|
| `doctor_id` | 9,362 | 일치 ✅ |
| `dept_id` | 28,086 | 3배 ❌ |

```sql
-- A. doctor_id로 연결
SELECT COUNT(*)
FROM reception r
JOIN doctor doc ON r.doctor_id = doc.doctor_id;   -- 9362

-- B. dept_id로 연결
SELECT COUNT(*)
FROM reception r
JOIN doctor doc ON r.dept_id = doc.dept_id;       -- 28086
```

**해석:** 접수를 진료과로 연결하면 접수 1건에 그 과 3명이 전부 붙어 3줄이 돼 그래서 결과 접수건수 3배인 28086건이 되고 doctor 표의 기본키인 의사 번호로 조인해야 정상적으로 확인이 가능해

## 10. 미수납 찾기 (LEFT JOIN)

미수납은 `payment`에 행이 **없는 것**으로 표현된다. 없는 행을 찾으려면 `LEFT JOIN`으로 접수를 전부 남긴 뒤, 짝이 없는 행을 골라낸다.

| 단계 | 쿼리 | 결과 |
|---|---|---:|
| ① | `JOIN` | 8,787 |
| ② | `LEFT JOIN` | 9,362 |
| ③ | ② + `WHERE p.payment_id IS NULL` | 575 |
| ④ | ③ + `AND r.status = '정상'` | **173** |

```sql
SELECT COUNT(*)
FROM reception r
LEFT JOIN payment p ON r.reception_id = p.reception_id
WHERE p.payment_id IS NULL
  AND r.status = '정상';                          -- 173
```

**해석:** IS NULL은 말그대로 없는 칸 즉 값이 없는 null만 잡아내는거고, 575건에는 접수 취소 402건이 섞여 있었어. 접수 취소가 안된거 173건을 정상이라는 단어를 찾아서 골라냈어
