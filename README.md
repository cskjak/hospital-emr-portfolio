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

## 11. 접수를 전부 취소한 환자 찾기 (GROUP BY + HAVING)

"취소한 적이 있는 환자"와 "접수가 전부 취소인 환자"는 다르다. 접수 한 줄씩 보면 앞의 것이 나오고, 환자별로 묶어야 뒤의 것이 나온다.

| 쿼리 | 결과 (환자 수) | 기준 |
|---|---:|---|
| A. `COUNT(DISTINCT r.patient_id)` + `WHERE t.treatment_id IS NULL` | 389 | 취소한 접수가 하나라도 있는 환자 |
| B. `GROUP BY r.patient_id` + `HAVING COUNT(t.treatment_id) = 0` | **108** | 접수가 전부 취소인 환자 ✅ |

| 환자 | 접수 | 취소 | A (389) | B (108) |
|---|---:|---:|:---:|:---:|
| 10000032 | 1건 | 1건 | O | O |
| 10000041 | 2건 | 1건 | O | X |

```sql
-- A. 389
SELECT COUNT(DISTINCT r.patient_id)
FROM reception r
LEFT JOIN treatment t ON r.reception_id = t.reception_id
WHERE t.treatment_id IS NULL;

-- B. 108
SELECT r.patient_id
FROM reception r
LEFT JOIN treatment t ON r.reception_id = t.reception_id
GROUP BY r.patient_id
HAVING COUNT(t.treatment_id) = 0;
```

**해석:** 환자 32번은 접수 1건이 전부 취소라서 389에도 108에도 들어가고 환자 41번은 접수 2건중 하나만 취소라서 389에만 포함돼. 108 을 구하려면 웨어절을 지우고 환자별 즉 patient_id 별로 묶은뒤 헤빙절 로 0 인 환자만 남겼어

## 12. 월별 접수 건수 (GROUP BY 기준 맞추기)

월별로 세려면 SELECT에 보이는 값과 GROUP BY로 묶는 값이 같아야 한다.

| 쿼리 | GROUP BY | 결과 행 수 | 기준 (1~6월) |
|---|---|---:|---|
| A | `reception_at` | 9,338 | ❌ |
| B | `TO_CHAR(reception_at, 'YYYY-MM')` | **6** | ✅ |

```sql
-- B. 6행
SELECT TO_CHAR(reception_at, 'YYYY-MM') AS 월, COUNT(*)
FROM reception
GROUP BY TO_CHAR(reception_at, 'YYYY-MM')
ORDER BY 월;
```

| 월 | 2026-01 | 2026-02 | 2026-03 | 2026-04 | 2026-05 | 2026-06 | 합계 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 건수 | 1,640 | 1,441 | 1,645 | 1,578 | 1,424 | 1,634 | **9,362** ✅ |

**해석:** A는 접수 시각별로 묶어서 그렇고 B는 월별로 묶어서 결과가 달라져

## 13. 월별 정상 / 취소 접수

12번 쿼리에 `WHERE status = ...` 한 줄을 더해 정상과 취소를 따로 셌다.

```sql
SELECT TO_CHAR(reception_at, 'YYYY-MM') AS 월, COUNT(*)
FROM reception
WHERE status = '정상'          -- 취소는 '취소'
GROUP BY TO_CHAR(reception_at, 'YYYY-MM')
ORDER BY 월;
```

| 월 | 전체 | 정상 | 취소 |
|---|---:|---:|---:|
| 2026-01 | 1,640 | 1,564 | 76 |
| 2026-02 | 1,441 | 1,394 | 47 |
| 2026-03 | 1,645 | 1,585 | 60 |
| 2026-04 | 1,578 | 1,490 | 88 |
| 2026-05 | 1,424 | 1,368 | 56 |
| 2026-06 | 1,634 | 1,559 | 75 |
| **합계** | **9,362** | **8,960** | **402** |

**해석:** 정상과 취소를 웨어절로 콕잡어서 그룹별로 묶었어

## 14. 취소가 많은 달 순서 (ORDER BY 기준)

`ORDER BY` 뒤에 적은 값이 줄 세우는 기준이 된다. 똑같이 `DESC`를 써도 무엇을 적었는지에 따라 맨 위 줄이 달라진다.

| 쿼리 | ORDER BY | 맨 위 줄 | 기준 (취소 최다 = 04월 88건) |
|---|---|---|---|
| A | `월 DESC` | 2026-06 · 75건 | ❌ |
| B | `COUNT(*) DESC` | **2026-04 · 88건** | ✅ |

```sql
-- B. 취소 많은 달부터
SELECT TO_CHAR(reception_at, 'YYYY-MM') AS 월, COUNT(*)
FROM reception
WHERE status = '취소'
GROUP BY TO_CHAR(reception_at, 'YYYY-MM')
ORDER BY COUNT(*) DESC;
```

| 순서 | 1 | 2 | 3 | 4 | 5 | 6 | 합계 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 월 | 04 | 01 | 06 | 03 | 05 | 02 | |
| 취소 | 88 | 76 | 75 | 60 | 56 | 47 | **402** ✅ |

**해석:** A는 월을 기준으로 큰 것부터 정렬해서 맨 위가 06월 75건이었고 B 는 카운트 취소건수가 많은걸 내림차순 정렬했고 그래서 결과 값의 차이가 둘에서 보였고

## 15. 위에서 1줄만 자르기 (FETCH FIRST와 ORDER BY)

`FETCH FIRST`는 결과를 위에서부터 자르기만 한다. 줄 순서를 정하는 건 `ORDER BY`뿐이라서, `ORDER BY` 없이 자르면 에러 없이 엉뚱한 줄이 남는다.

| 쿼리 | ORDER BY | 결과 | 기준 (취소 최다 = 04월 88건) |
|---|---|---|---|
| A | 없음 | 2026-01 · 76건 | ❌ |
| B | `COUNT(*) DESC` | **2026-04 · 88건** | ✅ |

```sql
-- B. 취소가 가장 많은 달 1개  (A는 ORDER BY 줄만 뺀 것)
SELECT TO_CHAR(reception_at, 'YYYY-MM') AS 월, COUNT(*)
FROM reception
WHERE status = '취소'
GROUP BY TO_CHAR(reception_at, 'YYYY-MM')
ORDER BY COUNT(*) DESC
FETCH FIRST 1 ROWS ONLY;
```

- A의 01월은 정해진 답이 아니다. 데이터나 실행 방식이 바뀌면 다른 달이 나올 수 있다.

**해석:** A 는 오더 절이 없어서 76건이 나왔어 데이터가 바뀌거나 DB 가 처리방식을 바꾸면 다른 달이 나오는 경우의 수가 있고 B는 오더절 있어서 결과 건수를 카운트한걸 정렬해 근데 FETCH 절로 1행만 나왔어

## 16. 순위 번호 붙이기 (RANK)

`RANK()`는 `OVER ( )` 괄호 안 기준으로 **순위 번호만** 붙인다. 줄을 옮기는 건 맨 아래 `ORDER BY`다.

```sql
SELECT TO_CHAR(reception_at, 'YYYY-MM') AS 월,
       COUNT(*),
       RANK() OVER (ORDER BY COUNT(*) DESC) AS 순위
FROM reception
WHERE status = '취소'
GROUP BY TO_CHAR(reception_at, 'YYYY-MM')
ORDER BY 순위;
```

| 위치 | 하는 일 |
|---|---|
| `OVER ( )` 안의 `ORDER BY` | 순위 번호를 매기는 기준 (건수가 크면 1) |
| 맨 아래 `ORDER BY` | 화면에 보이는 줄 순서 (순위 1 → 6) |

| 순위 | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---:|---:|---:|---:|---:|---:|
| 월 | 04 | 01 | 06 | 03 | 05 | 02 |
| 취소 | 88 | 76 | 75 | 60 | 56 | 47 |

- `OVER ( )` 괄호 안은 RANK에 주는 기준 칸이다. 서브쿼리는 괄호 안이 `SELECT`로 시작한다.
- 윈도우 함수는 `SELECT` 단계에서 만들어지므로 `SELECT`와 `ORDER BY`에서만 쓸 수 있다.

**해석:** RANK는 카운트 기준으로 순위 붙였고 ORDER BY는 순위순으로 줄 세웠어

## 17. 동점일 때 순위 (RANK · DENSE_RANK · ROW_NUMBER)

진료과별 취소 건수에는 동점이 두 군데 있다(68·68, 38·38). 같은 기준으로 순위를 매겨도 함수마다 동점을 다르게 처리한다.

```sql
SELECT dept_id,
       COUNT(*),
       RANK()       OVER (ORDER BY COUNT(*) DESC)          AS 랭크,
       DENSE_RANK() OVER (ORDER BY COUNT(*) DESC)          AS 덴스랭크,
       ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, dept_id) AS 로우넘버
FROM reception
WHERE status = '취소'
GROUP BY dept_id
ORDER BY COUNT(*) DESC;
```

| dept_id | 진료과 | 취소 | RANK | DENSE_RANK | ROW_NUMBER |
|---:|---|---:|---:|---:|---:|
| 1 | 소화기내과 | 75 | 1 | 1 | 1 |
| 2 | 순환기내과 | 68 | 2 | 2 | 2 |
| 4 | 정형외과 | 68 | 2 | 2 | 3 |
| 3 | 내분비내과 | 42 | **4** | **3** | 4 |
| 7 | 피부과 | 40 | 5 | 4 | 5 |
| 6 | 소아청소년과 | 38 | 6 | 5 | 6 |
| 8 | 안과 | 38 | 6 | 5 | 7 |
| 5 | 신경과 | 33 | **8** | **6** | 8 |

| 함수 | 동점 처리 |
|---|---|
| `RANK` | 같은 번호를 주고, 다음 번호는 건너뜀 (3·7 없음) |
| `DENSE_RANK` | 같은 번호를 주고, 건너뛰지 않음 |
| `ROW_NUMBER` | 동점이어도 1부터 차례로 고유 번호를 줌 |

- `ROW_NUMBER`는 동점 줄의 순서를 정할 기준이 없으면 Oracle이 처리한 순서대로 번호를 붙인다(첫 실행 때는 4번 과가 2, 2번 과가 3). `, dept_id`를 더해서 동점이면 과 번호가 작은 쪽이 먼저 오도록 고정했다.
- 화면 줄 순서까지 고정하려면 맨 아래 `ORDER BY`에도 `, dept_id`가 필요하다.

**해석:** 랭크는 동점 다음번호를 등수 순위로 매기고 댄스랭크는 같은 등수를 같은 매기고 건너뛰지 않고 등수를 매겨 로우넘버는 고유한 순서로 번호를 매기고 동점일 때 누가 먼저인지는 dept_id 작은 순으로 정했어

## 18. 값 바꿔 보여주기 (DECODE)

`DECODE(컬럼, 값1, 결과1, 값2, 결과2, …, 나머지)` — 컬럼 뒤를 앞에서부터 둘씩 묶어 짝으로 읽고, 혼자 남는 것이 나머지다. 어느 짝에도 맞지 않는데 나머지도 없으면 **에러 없이 NULL**이 나온다.

환자 10000041(접수 2건 · 취소 1건, 11번 표)로 확인했다.

| 쿼리 | DECODE | 3921 (정상) | 5332 (취소) |
|---|---|:---:|:---:|
| A | `DECODE(status, '정상','O', '취소','X')` | O | X |
| B | `DECODE(status, '정상','O')` | O | **(빈칸 = NULL)** |
| C | `DECODE(status, '정상','O', 'X')` | O | X ← 나머지 |

```sql
-- C. 정상이 아니면 전부 X
SELECT reception_id, status,
       DECODE(status, '정상', 'O', 'X') AS 표시
FROM reception
WHERE patient_id = 10000041;
```

**해석:** a는 짝이 2개 딱 맞아서 정상이면 o 취소면 x 가 나오고 b는 정상은 o 취소는 짝도 나머지도 없어서 빈칸이 나와 c는 짝이 1개이고, 혼자 남은 X가 나머지라서 취소 줄에 X가 나와

## 19. 월별 정상/취소를 쿼리 하나로 (SUM + DECODE)

13번은 `WHERE`를 바꿔 가며 쿼리를 두 번 돌렸다. `DECODE`로 줄마다 1/0을 적고 `SUM`으로 더하면 쿼리 하나로 같은 표가 나온다.

| 줄 | status | `DECODE(status,'정상',1,0)` | `DECODE(status,'취소',1,0)` |
|---|---|:---:|:---:|
| 3921 | 정상 | 1 | 0 |
| 5332 | 취소 | 0 | 1 |

```sql
SELECT TO_CHAR(reception_at, 'YYYY-MM') AS 월,
       COUNT(*) AS 전체,
       SUM(DECODE(status, '정상', 1, 0)) AS 정상,
       SUM(DECODE(status, '취소', 1, 0)) AS 취소
FROM reception
GROUP BY TO_CHAR(reception_at, 'YYYY-MM')
ORDER BY 월;
```

결과는 13번 표와 6줄 모두 같다. 줄마다 정상 + 취소 = 전체가 맞는다.

**해석:** DECODE 로 줄마다 정상이면 1 아니면 0 을 적고 SUM 으로 더해서 월별 정상 건수가 됐어 취소칸은 취소면 1 아니면 0 을적고 SUM 으로 더해서 월별 취소 건수가 됐어

## 20. 빈칸에 이름 붙이기 (COALESCE)

`COALESCE(칸, 값)` — 칸이 NULL이면 값을 보여주고, 칸에 값이 있으면 그 값을 그대로 보여준다. 줄마다 한 번씩 적용되며, 바뀌는 건 화면에 나오는 결과뿐이고 표에 저장된 값은 그대로다.

10번처럼 `reception LEFT JOIN payment`를 하면 수납이 없는 접수는 `p.method`가 NULL이다.

| reception_id | status | p.method | `COALESCE(p.method, '미수납')` |
|---:|---|---|---|
| 2 | 정상 | (NULL) | 미수납 |
| 3921 | 정상 | 카드 | 카드 |
| 5332 | 취소 | (NULL) | 미수납 |

이걸로 수납방법별 건수를 세면, `WHERE` 없이는 미수납이 575로 나온다. 10번 ③과 같은 숫자로, 취소 402건이 섞여 있다.

| 수납방법 | A. `WHERE` 없음 | B. `WHERE r.status = '정상'` |
|---|---:|---:|
| 카드 | 6,807 | 6,807 |
| 간편결제 | 1,349 | 1,349 |
| 현금 | 631 | 631 |
| 미수납 | 575 ❌ | **173** ✅ |
| 합계 | 9,362 | 8,960 |

```sql
-- B. 정상 접수만 남기고 수납방법별로 세기  (A는 WHERE 줄만 뺀 것)
SELECT COALESCE(p.method, '미수납') AS 수납방법, COUNT(*)
FROM reception r
LEFT JOIN payment p ON r.reception_id = p.reception_id
WHERE r.status = '정상'
GROUP BY COALESCE(p.method, '미수납')
ORDER BY COUNT(*) DESC;
```

- `COALESCE`가 보는 칸은 `p.method` 하나뿐이다. 취소 접수는 수납이 없어서(6번 검산) `p.method`가 NULL이므로, 정상 미수납 173건과 함께 `미수납`으로 묶인다.
- B의 합계 8,960은 13번 표의 정상 접수 합계와 같다.

**해석:** 콜레쓰는 빈칸을 지정한 값 즉 미수납으로 채우고 빈칸인지만 판단해서 취소 402건도 미수납으로 됐어 콜레스 때문에. 웨어를 넣어서 미수납만 173건으로 집어 냈고

## 21. 빈칸이 있는 칸 세기와 평균 (COUNT · AVG · COALESCE)

정상 접수 8,960건 중 수납이 없는 173건은 `p.total_amount`가 NULL이다. 같은 칸으로 세고 평균을 내도 함수에 따라 분모가 달라진다.

```sql
SELECT COUNT(*), COUNT(p.total_amount), SUM(p.total_amount),
       AVG(p.total_amount), AVG(COALESCE(p.total_amount,0))
FROM reception r
LEFT JOIN payment p ON r.reception_id = p.reception_id
WHERE r.status = '정상';
```

| 칸 | 결과 | 세는 줄 |
|---|---:|---|
| `COUNT(*)` | 8,960 | 모든 줄 |
| `COUNT(p.total_amount)` | 8,787 | 금액이 있는 줄 |
| `SUM(p.total_amount)` | 669,606,690 | 금액이 있는 줄 |
| 평균A `AVG(p.total_amount)` | 76,204.24 | 669,606,690 ÷ **8,787** |
| 평균B `AVG(COALESCE(p.total_amount,0))` | 74,732.89 | 669,606,690 ÷ **8,960** |

합계는 같고 분모만 다르다. `COALESCE`로 173줄에 0이 들어가면 그 줄도 센다.

**진료 1건당 평균 진료비는 A**

B는 173건 자리에 0을 넣는다. 수납된 8,787건에는 진료비 0원인 건이 없다.

```sql
SELECT MIN(total_amount) FROM payment;                 -- 18000
SELECT COUNT(*) FROM payment WHERE total_amount = 0;   -- 0
```

| 구하는 것 | 173건 자리 | 쓸 평균 |
|---|---|:---:|
| 진료 1건당 평균 진료비 | 진료비가 기록되지 않음 → 계산에서 뺌 | A |
| 접수 1건당 실제로 들어온 돈의 평균 | 들어온 돈 0원 | B |

**해석:** 184번줄에서 확인 했듯이 빈칸이야 원래는 0원은 단지 내가 조회햇을때 0 원으로 만들고 조회 한거라서 결과가 다른 거고 진료비 평균에는 왜 a 를 쓰냐면 실제론 빈칸을 제외하고 조회 하기 때문이야 실제로 기록된 진료비로만 평균을 내서

## 22. 진료에 걸린 시간 (날짜 빼기)

`start_at`, `end_at`은 `DATE` 형식이다. 날짜끼리 빼면 결과는 **일(day) 단위** 소수로 나온다. `* 24 * 60`을 하면 분이 된다.

```sql
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';  -- 화면에 시:분:초까지 보이게 (저장값은 그대로)

SELECT treatment_id, start_at, end_at, end_at - start_at, (end_at - start_at) * 24 * 60
FROM treatment
FETCH FIRST 3 ROWS ONLY;
```

| treatment_id | start_at | end_at | `end_at - start_at` (일) | `* 24 * 60` (분) |
|---:|---|---|---:|---:|
| 258 | 2026-01-06 14:41:57 | 2026-01-06 14:44:58 | .002094907 | 3.02 |
| 259 | 2026-01-06 14:09:34 | 2026-01-06 14:24:13 | .010173611 | 14.65 |
| 260 | 2026-01-06 14:37:30 | 2026-01-06 14:48:02 | .007314815 | 10.53 |

258은 3분 1초다. 하루는 1,440분이므로 3분 1초 ÷ 1,440분 = 0.002094907.

**진료과별 평균 진료 시간**

```sql
SELECT d.dept_name, COUNT(*), ROUND(AVG((t.end_at - t.start_at) * 24 * 60), 1) AS 평균분
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
JOIN department d ON r.dept_id = d.dept_id
GROUP BY d.dept_name
ORDER BY 평균분 DESC;
```

| 진료과 | 건수 | 평균(분) |
|---|---:|---:|
| 피부과 | 1,016 | 8.4 |
| 신경과 | 877 | 8.4 |
| 안과 | 880 | 8.3 |
| 내분비내과 | 1,091 | 8.2 |
| 정형외과 | 1,485 | 8.2 |
| 소아청소년과 | 811 | 8.1 |
| 순환기내과 | 1,210 | 8.0 |
| 소화기내과 | 1,590 | 8.0 |
| 합계 | 8,960 | |

과마다 8.0~8.4분으로 거의 같다.

**초진 / 재진별 평균 진료 시간** (위 쿼리에서 `d.dept_name` 두 곳을 `r.visit_type`으로 바꿈)

| visit_type | 건수 | 평균(분) |
|---|---:|---:|
| 초진 | 4,052 | 11.5 |
| 재진 | 4,908 | 5.5 |
| 합계 | 8,960 | |

진료 시간은 진료과보다 초진/재진에 따라 크게 달라진다. 생성 스크립트도 초진 8~15분, 재진 3~8분으로 만들었다.

**해석:** 소수가 나온이유는 일단위라서 24 * 60 은 시간 시간 분을 말하는건데 이걸 이용해서 곱한거고 분으로 그리고 방문 유형(초진 재진)별로 시간 평균을 계산해서 라운드 함수로 반올림 하고 그 건수를 카운트로 세

## 23. 접수부터 진료 시작까지 대기 시간

두 시각이 서로 다른 테이블에 있다. 접수 시각은 `reception.reception_at`, 진료 시작 시각은 `treatment.start_at`이다. **나중 시각 − 먼저 시각** 순서로 뺀다.

```sql
SELECT t.treatment_id, r.reception_at, t.start_at, (t.start_at - r.reception_at) * 24 * 60 AS 대기분
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
FETCH FIRST 3 ROWS ONLY;
```

| treatment_id | reception_at | start_at | 대기분 |
|---:|---|---|---:|
| 258 | 2026-01-06 13:49:00 | 2026-01-06 14:41:57 | 52.95 |
| 259 | 2026-01-06 13:49:50 | 2026-01-06 14:09:34 | 19.73 |
| 260 | 2026-01-06 13:54:55 | 2026-01-06 14:37:30 | 42.58 |

**진료과별 평균 대기 시간** (22번 진료과별 쿼리에서 계산식만 바꿈)

```sql
SELECT d.dept_name, COUNT(*), ROUND(AVG((t.start_at - r.reception_at) * 24 * 60), 1) AS 평균대기분
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
JOIN department d ON r.dept_id = d.dept_id
GROUP BY d.dept_name
ORDER BY 평균대기분 DESC;
```

| 진료과 | 건수 | 평균 대기(분) | 평균 진료(분, 22번) |
|---|---:|---:|---:|
| 소화기내과 | 1,590 | 43.1 | 8.0 |
| 정형외과 | 1,485 | 42.5 | 8.2 |
| 순환기내과 | 1,210 | 31.3 | 8.0 |
| 피부과 | 1,016 | 31.0 | 8.4 |
| 내분비내과 | 1,091 | 28.3 | 8.2 |
| 소아청소년과 | 811 | 27.0 | 8.1 |
| 안과 | 880 | 22.6 | 8.3 |
| 신경과 | 877 | 22.4 | 8.4 |

진료 시간은 과마다 거의 같지만 대기 시간은 두 배 가까이 차이 난다. 과마다 의사는 3명으로 같고, 건수가 많은 과일수록 대기가 길다.

**접수한 시각(시)별 평균 대기 시간**

```sql
SELECT TO_CHAR(r.reception_at, 'HH24') AS 접수시, COUNT(*), ROUND(AVG((t.start_at - r.reception_at) * 24 * 60), 1) AS 평균대기분
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
GROUP BY TO_CHAR(r.reception_at, 'HH24')
ORDER BY 접수시;
```

| | 접수시 | 건수 | 평균 대기(분) |
|---|---|---:|---:|
| 오전 | 08 | 1,700 | 38.6 |
| | 09 | 1,743 | 31.6 |
| | 10 | 801 | 20.0 |
| | 11 | 65 | 10.3 |
| 오후 | 12 | 486 | 40.8 |
| | 13 | 2,512 | 37.6 |
| | 14 | 1,312 | 27.5 |
| | 15 | 341 | 16.0 |

오전·오후 모두 일찍 접수할수록 오래 기다린다. 접수는 08:20·12:50부터 받지만 진료는 09:00·13:30에 시작한다(4번 표).

**해석:** 1. 진료 시작 시각 빼기 접수 시각을 분으로 계산해서 3줄만 보여줬어 2.진료과별 평균 대기시간을 계산했는데 진료과별 평균 대기시간을 디파트먼트 네임 즉 진료과 이름 별로 평균 대기시간을 계산했고 그걸 내림차순 한거고 3.조인 절로 테이블이 다르니 이너조인으로 매칭하고 셀렉트절에서 시간을 문자열로 반환 하하고 시간으로 그리고 접수시별로 묶어서 평균 대기시간을 계산하고 오더바이절로 접수시 즉 시간별로 정렬했어
