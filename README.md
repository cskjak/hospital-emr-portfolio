# 🏥 가상 병원 외래 데이터 — SQL 포트폴리오

의료기관 전산 운영 업무를 하면서 DB 쪽에 관심이 생겨 외래 진료 흐름을 가상 데이터로 설계하고 SQL로 분석한 포트폴리오입니다.

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

**권한 테이블** (2단계, 30번부터 사용)

```
role ──< staff ───── doctor      (의사만 이어짐)
  │        └──────── department  (의사·간호사만 이어짐)
  │
  └──< role_menu >── menu ──< menu  (상위 메뉴 → 하위 메뉴)
```

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
| `role.csv` | 5 | 역할 하나 (의사 · 간호사 · 원무 · 약제 · 전산) |
| `staff.csv` | 57 | 직원 한 명 (의사 24명은 `doctor`와 같은 사람 · 퇴사 3명 포함) |
| `menu.csv` | 21 | 메뉴 하나 (상위 메뉴 5개 + 하위 메뉴 16개) |
| `role_menu.csv` | 27 | 역할 하나가 메뉴 하나를 볼 수 있다는 권한 한 칸 |

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

### role — 역할
| 컬럼 | 형식 | 설명 |
|---|---|---|
| role_id | 정수 | 기본키 (1~5) |
| role_code | 문자 | DOC, NUR, ADM, PHA, ITS |
| role_name | 문자 | 의사, 간호사, 원무, 약제, 전산 |

### staff — 직원
| 컬럼 | 형식 | 설명 |
|---|---|---|
| staff_id | 정수 | 기본키 (20001~20057) |
| staff_name | 문자 | 가상 이름 (의사는 `doctor.doctor_name`과 같음) |
| role_id | 정수 | → role.role_id |
| dept_id | 정수 | → department.dept_id (의사·간호사만, 나머지는 빈칸) |
| doctor_id | 정수 | → doctor.doctor_id (의사만, 나머지는 빈칸) |
| hire_date | 날짜 | 입사일 |
| status | 문자 | 재직 / 퇴사 |

### menu — 메뉴
| 컬럼 | 형식 | 설명 |
|---|---|---|
| menu_id | 정수 | 기본키 (상위 100·200·…·500, 하위 101·102·…) |
| menu_name | 문자 | 접수, 진료기록, 수납 등 일반적인 업무 이름 |
| parent_id | 정수 | → menu.menu_id (상위 메뉴 · 맨 위 메뉴는 빈칸) |
| sort_order | 정수 | 같은 상위 메뉴 안에서의 순서 |

### role_menu — 역할-메뉴 권한
| 컬럼 | 형식 | 설명 |
|---|---|---|
| role_id | 정수 | → role.role_id |
| menu_id | 정수 | → menu.menu_id |
| can_write | 문자 1자리 | Y (고치기 가능) / N (보기만) |

- 기본키는 **두 컬럼을 합친 것** (role_id + menu_id)
- 행이 **있으면** 그 메뉴를 볼 수 있음 · 권한은 하위 메뉴에만 줌

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
- `reception`에 `dept_id`와 `doctor_id`가 둘 다 있음 (의사를 보면 과를 알 수 있지만, 접수할 때의 과를 따로 남김)

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
sql/01_create_tables.sql       테이블 7개 생성 (PK · FK · CHECK 포함)
sql/02_create_auth_tables.sql  권한 테이블 4개 생성 (01번 다음에 실행)
sql/load/*.ctl                 SQL*Loader 설정 (CSV → 테이블)
scripts/generate_data.ps1      가상 데이터 생성기 (시드 고정)
scripts/generate_auth.ps1      권한 테이블 데이터 생성기 (시드 고정)
```

1. SQL*Plus에서 `@sql/01_create_tables.sql` → `@sql/02_create_auth_tables.sql`
2. 부모 테이블부터 적재: department → doctor → doctor_schedule → patient → reception → treatment → payment → role → menu → staff → role_menu
   ```
   sqlldr userid=<계정>@//localhost:1521/FREEPDB1 control=sql/load/department.ctl
   ```
   SQL*Plus 안에서 실행할 때는 앞에 `HOST`를 붙인다.
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

**해석:** 접수를 진료과로 연결하면 접수 1건에 그 과 3명이 전부 붙어 3줄이 된다. 그래서 결과 접수건수 3배인 28086건이 되고 doctor 표의 기본키인 의사 번호로 조인해야 정상적으로 확인이 가능하다.

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

**해석:** IS NULL은 말그대로 없는 칸 즉 값이 없는 null만 잡아내는거고, 575건에는 접수 취소 402건이 섞여 있었다. 접수 취소가 안된거 173건을 정상이라는 단어를 찾아서 골라냈다.

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

**해석:** 환자 32번은 접수 1건이 전부 취소라서 389에도 108에도 들어가고 환자 41번은 접수 2건중 하나만 취소라서 389에만 포함된다. 108 을 구하려면 웨어절을 지우고 환자별 즉 patient_id 별로 묶은뒤 헤빙절 로 0 인 환자만 남겼다.

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

**해석:** A는 접수 시각별로 묶어서 그렇고 B는 월별로 묶어서 결과가 달라진다.

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

**해석:** 정상과 취소를 웨어절로 콕 집어서 그룹별로 묶었다.

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

**해석:** A는 월을 기준으로 큰 것부터 정렬해서 맨 위가 06월 75건이었고 B 는 카운트 취소건수가 많은걸 내림차순 정렬했다. 그래서 결과 값의 차이가 둘에서 보였다.

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

**해석:** A 는 오더 절이 없어서 76건이 나왔다. 데이터가 바뀌거나 DB 가 처리방식을 바꾸면 다른 달이 나오는 경우의 수가 있고 B는 오더절 있어서 결과 건수를 카운트한걸 정렬한다. 그런데 FETCH 절로 1행만 나왔다.

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

**해석:** RANK는 카운트 기준으로 순위 붙였고 ORDER BY는 순위순으로 줄 세웠다.

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

**해석:** 랭크는 동점 다음번호를 등수 순위로 매기고 덴스랭크는 같은 등수를 같은 번호로 매기고 건너뛰지 않고 등수를 매긴다. 로우넘버는 고유한 순서로 번호를 매기고 동점일 때 누가 먼저인지는 dept_id 작은 순으로 정했다.

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

**해석:** a는 짝이 2개 딱 맞아서 정상이면 o 취소면 x 가 나오고 b는 정상은 o 취소는 짝도 나머지도 없어서 빈칸이 나온다. c는 짝이 1개이고, 혼자 남은 X가 나머지라서 취소 줄에 X가 나온다.

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

**해석:** DECODE 로 줄마다 정상이면 1 아니면 0 을 적고 SUM 으로 더해서 월별 정상 건수가 됐다. 취소칸은 취소면 1 아니면 0 을적고 SUM 으로 더해서 월별 취소 건수가 됐다.

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

**해석:** COALESCE는 빈칸을 지정한 값 즉 미수납으로 채우고 빈칸인지만 판단해서 취소 402건도 미수납으로 됐다. COALESCE 때문이다. 웨어를 넣어서 미수납만 173건으로 집어 냈다.

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

**해석:** 2번 접수에서 확인했듯이 원래는 빈칸이다. 0원은 단지 내가 조회했을때 0 원으로 만들고 조회 한거라서 결과가 다른 거고 진료비 평균에는 왜 a 를 쓰냐면 실제론 빈칸을 제외하고 조회 하기 때문이다. 실제로 기록된 진료비로만 평균을 낸다.

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

**해석:** 소수가 나온이유는 일단위라서다. 24 * 60 은 24시간 × 60분을 말하는건데 이걸 이용해서 곱해 분으로 바꿨다. 그리고 방문 유형(초진 재진)별로 시간 평균을 계산해서 라운드 함수로 반올림 하고 그 건수를 카운트로 센다.

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

진료 시간은 과마다 거의 같지만 대기 시간은 두 배 가까이 차이 난다. 과마다 의사는 3명으로 같고, 건수가 많은 과일수록 대체로 대기가 길다. 다만 내분비내과(1,091건 · 28.3분)와 피부과(1,016건 · 31.0분), 소아청소년과(811건 · 27.0분)와 안과(880건 · 22.6분)는 순서가 반대다.

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

**해석:** 1. 진료 시작 시각 빼기 접수 시각을 분으로 계산해서 3줄만 보여줬다. 2. 진료과별 평균 대기시간을 계산했는데 진료과별 평균 대기시간을 디파트먼트 네임 즉 진료과 이름 별로 평균 대기시간을 계산했고 그걸 내림차순 했다. 3. 조인 절로 테이블이 다르니 이너조인으로 매칭하고 셀렉트절에서 시간을 문자열로 반환하고 시간으로 그리고 접수시별로 묶어서 평균 대기시간을 계산하고 오더바이절로 접수시 즉 시간별로 정렬했다.

## 24. 대기 시간을 구간으로 나누기 (CASE WHEN)

`DECODE`(18번)는 **같은 글자인가**만 판정한다. `CASE WHEN`은 `< 30` 같은 **크기 비교**도 할 수 있다.

**① 줄마다 구간 이름 붙이기**

```sql
SELECT t.treatment_id, (t.start_at - r.reception_at) * 24 * 60 AS 대기분,
       CASE
         WHEN (t.start_at - r.reception_at) * 24 * 60 < 30 THEN '30분 미만'
         WHEN (t.start_at - r.reception_at) * 24 * 60 < 50 THEN '30~50분'
         ELSE '50분 이상'
       END AS 구간
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
FETCH FIRST 3 ROWS ONLY;
```

줄마다 위의 `WHEN`부터 차례로 검사하고, **처음 맞는 곳에서 멈춘다.**

| 줄 | 대기분 | `< 30` | `< 50` | ELSE | 구간 |
|---|---:|---|---|---|---|
| 259 | 19.73 | ✅ 멈춤 | (검사 안 함) | | 30분 미만 |
| 260 | 42.58 | ❌ | ✅ 멈춤 | | 30~50분 |
| 258 | 52.95 | ❌ | ❌ | ✅ | 50분 이상 |

259는 `< 50`에도 맞지만 첫 `WHEN`에서 멈췄으므로 30~50분이 되지 않는다.

**② 구간별 건수**

```sql
SELECT CASE
         WHEN (t.start_at - r.reception_at) * 24 * 60 < 30 THEN '30분 미만'
         WHEN (t.start_at - r.reception_at) * 24 * 60 < 50 THEN '30~50분'
         ELSE '50분 이상'
       END AS 구간, COUNT(*)
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
GROUP BY CASE
         WHEN (t.start_at - r.reception_at) * 24 * 60 < 30 THEN '30분 미만'
         WHEN (t.start_at - r.reception_at) * 24 * 60 < 50 THEN '30~50분'
         ELSE '50분 이상'
       END
ORDER BY MIN((t.start_at - r.reception_at) * 24 * 60);
```

| 구간 | 건수 |
|---|---:|
| 30분 미만 | 4,260 |
| 30~50분 | 2,868 |
| 50분 이상 | 1,832 |
| 합계 | 8,960 |

`ORDER BY 구간`으로 정렬하면 **글자 순서**라서 `30~50분`이 `30분 미만`보다 먼저 나온다(`~`가 `분`보다 앞). 구간마다 가장 작은 대기분(`MIN`)으로 정렬하면 크기 순서가 된다.

**③ 진료과별 × 구간** (19번 `SUM(DECODE(...))`와 같은 방식)

```sql
SELECT d.dept_name, COUNT(*) AS 전체,
       SUM(CASE WHEN (t.start_at - r.reception_at) * 24 * 60 < 30 THEN 1 ELSE 0 END) AS 짧음,
       SUM(CASE WHEN (t.start_at - r.reception_at) * 24 * 60 >= 30
                 AND (t.start_at - r.reception_at) * 24 * 60 < 50 THEN 1 ELSE 0 END) AS 중간,
       SUM(CASE WHEN (t.start_at - r.reception_at) * 24 * 60 >= 50 THEN 1 ELSE 0 END) AS 김
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
JOIN department d ON r.dept_id = d.dept_id
GROUP BY d.dept_name
ORDER BY 김 DESC;
```

여기서는 `CASE`가 칸마다 따로라서 "처음 맞는 곳에서 멈춤"이 칸끼리 이어지지 않는다. 그래서 `중간`에는 `>= 30 AND < 50` 두 조건을 다 쓴다.

| 진료과 | 전체 | 짧음 (30분 미만) | 중간 (30~50분) | 김 (50분 이상) |
|---|---:|---:|---:|---:|
| 소화기내과 | 1,590 | 443 | 566 | 581 |
| 정형외과 | 1,485 | 476 | 477 | 532 |
| 순환기내과 | 1,210 | 564 | 453 | 193 |
| 피부과 | 1,016 | 501 | 348 | 167 |
| 내분비내과 | 1,091 | 595 | 358 | 138 |
| 소아청소년과 | 811 | 478 | 229 | 104 |
| 안과 | 880 | 598 | 216 | 66 |
| 신경과 | 877 | 605 | 221 | 51 |
| 합계 | 8,960 | 4,260 | 2,868 | 1,832 |

세로 합계는 ②와 같고, 가로 합계(짧음 + 중간 + 김)는 전체와 같다. 평균 대기 시간(23번)은 2배 차이지만 50분 이상 기다린 건수는 소화기내과 581, 신경과 51로 10배 넘게 차이 난다.

**해석:** 1. 두시각을 뺀 값 즉 대기분을 구간으로 나눴다(30~50분 기준). 2. 일정 분 마다 구간별로 건수를 계산했다. 3. 진료과는 줄로 묶고 구간별 칸은 SUM으로 합산했다.

## 25. 진료 끝나고 수납까지 걸린 시간

진료 끝 시각은 `treatment.end_at`, 수납 시각은 `payment.paid_at`이다. 두 테이블 모두 `reception_id`가 있어서 접수 테이블을 거치지 않고 바로 잇는다.

**① 3줄 보기**

```sql
SELECT t.treatment_id, t.end_at, p.paid_at, (p.paid_at - t.end_at) * 24 * 60 AS 수납까지분
FROM treatment t
JOIN payment p ON t.reception_id = p.reception_id
FETCH FIRST 3 ROWS ONLY;
```

| treatment_id | end_at | paid_at | 수납까지분 |
|---:|---|---|---:|
| 172 | 2026-01-05 16:14:37 | 2026-01-05 16:31:26 | 16.82 |
| 183 | 2026-01-06 09:05:50 | 2026-01-06 09:12:57 | 7.12 |
| 193 | 2026-01-06 09:09:13 | 2026-01-06 09:15:16 | 6.05 |

172는 16분 49초다. `ORDER BY` 없이 잘랐으므로 22·23번과 다른 줄이 나왔다(15번).

**② 이어진 줄 수**

```sql
SELECT COUNT(*)
FROM treatment t
JOIN payment p ON t.reception_id = p.reception_id;
```

결과는 **8,787**이다. 진료 8,960건(22번) 중 미수납 173건(10번)은 수납 줄이 없어서 JOIN에서 빠진다. 8,960 − 173 = 8,787.

**③ 진료과별 평균** (23번 진료과별 쿼리에서 계산식과 `payment` JOIN만 바뀜)

```sql
SELECT d.dept_name, COUNT(*), ROUND(AVG((p.paid_at - t.end_at) * 24 * 60), 1) AS 평균수납분
FROM treatment t
JOIN payment p ON t.reception_id = p.reception_id
JOIN reception r ON t.reception_id = r.reception_id
JOIN department d ON r.dept_id = d.dept_id
GROUP BY d.dept_name
ORDER BY 평균수납분 DESC;
```

| 진료과 | 건수 | 평균 수납까지(분) |
|---|---:|---:|
| 소아청소년과 | 799 | 13.7 |
| 피부과 | 998 | 13.6 |
| 순환기내과 | 1,189 | 13.5 |
| 내분비내과 | 1,074 | 13.5 |
| 소화기내과 | 1,561 | 13.5 |
| 신경과 | 864 | 13.4 |
| 안과 | 854 | 13.3 |
| 정형외과 | 1,448 | 13.3 |
| 합계 | 8,787 | |

| 번호 | 무엇 | 과별 범위 | 차이 |
|---|---|---|---:|
| 22 | 진료 시간 | 8.0 ~ 8.4 | 0.4분 |
| 23 | 대기 시간 | 22.4 ~ 43.1 | 20.7분 |
| 25 | 수납까지 | 13.3 ~ 13.7 | 0.4분 |

과마다 거의 같다. 22번(진료 시간)과 같은 모양이고 23번(대기 시간)과는 다르다.

> JOIN 줄을 `ON r.reception_id = r.reception_id`처럼 **양쪽 다 `r.`**로 쓰면 에러 없이 실행되지만, 모든 줄에서 참이라 8,787 × 9,362 = 약 8,200만 줄이 만들어져 끝나지 않는다. `=` 양쪽 별칭이 서로 다른 테이블인지 확인할 것.

**④ 가장 짧은 / 가장 긴 수납까지 시간**

```sql
SELECT MIN((p.paid_at - t.end_at) * 24 * 60), MAX((p.paid_at - t.end_at) * 24 * 60)
FROM treatment t
JOIN payment p ON t.reception_id = p.reception_id;
```

| MIN | MAX |
|---:|---:|
| 2 | 25 |

생성 스크립트는 수납 시각을 **진료 끝 시각 + 2~25분 무작위**로 만들었다. 진료과를 보지 않으므로 과마다 평균이 (2 + 25) ÷ 2 = 13.5 근처로 모인다.

**해석:** 1. 진료 테이블에서 수납테이블로 접수칸 별로 맞아떨어지는걸 FETCH FIRST 3 ROWS ONLY 로 3행만 출력하는데 수납 시각 과 끝날 시간을 빼서 수납까지 걸린 시간분을 나타냈다. 2. 진료 테이블을 T 로 지칭하고 수납 항목에서 접수 아이디로 다른 테이블의 접수아이디로 조인을하고 그걸 카운트로 집계 했다. 미수납 173건이 빠져서 8787이 나왔다. 3. 진료과별 평균은 0.4 차이로 22번이랑 닮았다. 4. 수납시각에서 끝난시점을 시간으로 계산하고 최소시간 최대시간을 나타냈다.

## 26. 요일별 대기 시간 (TO_CHAR 'DY' · 'D')

`reception_at`은 년·월·일·시·분·초가 한 덩어리다. 덩어리째로 묶으면 값이 거의 다 달라서 묶이지 않는다(12번, 9,338줄). `TO_CHAR(..., 'DY')`로 **요일 조각만 꺼내면** 같은 요일끼리 같은 글자가 되어 5줄로 묶인다. 대기 시간 계산식은 23번과 같다.

| 접수 | `reception_at` (덩어리) | `'HH24'` (23번) | `'DY'` |
|---|---|---|---|
| 1 | 2026-01-02 08:29:21 | 08 | 금 |
| 2 | 2026-01-02 08:39:23 | 08 | 금 |

**① 3줄 보기**

```sql
SELECT t.treatment_id, r.reception_at, TO_CHAR(r.reception_at, 'DY') AS 요일
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
FETCH FIRST 3 ROWS ONLY;
```

| treatment_id | reception_at | 요일 |
|---:|---|---|
| 258 | 2026-01-06 13:49:00 | 화 |
| 259 | 2026-01-06 13:49:50 | 화 |
| 260 | 2026-01-06 13:54:55 | 화 |

**② 요일별 평균 대기**

```sql
SELECT TO_CHAR(r.reception_at, 'DY') AS 요일, COUNT(*), ROUND(AVG((t.start_at - r.reception_at) * 24 * 60), 1) AS 평균대기분
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
GROUP BY TO_CHAR(r.reception_at, 'DY')
ORDER BY 요일;
```

| 요일 | 건수 | 평균 대기(분) |
|---|---:|---:|
| 금 | 1,114 | 23.5 |
| 목 | 2,063 | 34.9 |
| 수 | 1,072 | 27.6 |
| 월 | 2,388 | 40.0 |
| 화 | 2,323 | 30.1 |

요일은 글자라서 **가나다 순서**(금 ㄱ · 목 ㅁ · 수 ㅅ · 월 ㅇ · 화 ㅎ)로 정렬된다. 24번 `ORDER BY 구간`과 같은 함정이다.

**③ 요일 번호로 정렬**

```sql
SELECT TO_CHAR(r.reception_at, 'DY') AS 요일, MIN(TO_CHAR(r.reception_at, 'D')) AS 번호, COUNT(*), ROUND(AVG((t.start_at - r.reception_at) * 24 * 60), 1) AS 평균대기분
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
GROUP BY TO_CHAR(r.reception_at, 'DY')
ORDER BY 번호;
```

| 요일 | 번호 | 건수 | 평균 대기(분) |
|---|---:|---:|---:|
| 월 | 2 | 2,388 | 40.0 |
| 화 | 3 | 2,323 | 30.1 |
| 수 | 4 | 1,072 | 27.6 |
| 목 | 5 | 2,063 | 34.9 |
| 금 | 6 | 1,114 | 23.5 |
| 합계 | | 8,960 | |

`'D'`는 요일 번호다. 한국 설정은 일요일이 1이라 월요일이 2부터 시작한다. `GROUP BY`에 `'D'`가 없으므로 그대로 쓰면 맨몸 컬럼이 되어 `MIN`으로 감쌌다. 같은 요일 묶음 안에서는 번호가 모두 같아서 `MIN`은 그 번호를 그대로 꺼낸다.

**④ 요일마다 대기가 다른 이유: 요일별로 열리는 진료 수**

```sql
SELECT weekday, COUNT(*) AS 세션수
FROM doctor_schedule
GROUP BY weekday;
```

`doctor_schedule`의 한 줄은 의사 한 명이 그 요일 오전(AM) 또는 오후(PM)에 외래를 한 번 여는 것이다(세션). 의사 24명 × 주 2번 = 48줄.

| 요일 | 접수 건수 (③) | 열리는 진료 수 (④) | 진료 하나당 건수 (③ ÷ ④) | 평균 대기(분) (③) |
|---|---:|---:|---:|---:|
| 월 | 2,388 | 10 | 238.8 | 40.0 |
| 목 | 2,063 | 10 | 206.3 | 34.9 |
| 화 | 2,323 | 13 | 178.7 | 30.1 |
| 수 | 1,072 | 7 | 153.1 | 27.6 |
| 금 | 1,114 | 8 | 139.3 | 23.5 |

6개월을 합친 숫자라 크게 보이지만 크기 비교만 보면 된다. **진료 하나당 건수 순서와 평균 대기 순서가 같다.** 화요일은 목요일보다 접수가 많지만(2,323 > 2,063) 진료가 13번 열려 환자가 나눠 서므로 대기가 짧다.

23번에서 건수가 많은 과일수록 대체로 대기가 길었던 것은 과마다 진료 수가 6번(의사 3명 × 2번)으로 같았기 때문이다. 요일은 진료 수가 7~13으로 달라서 건수를 진료 수로 나눠 봐야 순서가 맞는다.

**해석:** 1. 진료 테이블에서 접수 건 별로 조인으로 매칭해서 요일별로 꺼냈다. 2. 진료 테이블에서 접수 건 별로 조인하고 그룹 절 요일별로 묶고 셀렉트절에서 접수 요일별로 문자열변환하고  시작시간과 접수 시각 을 뺀 평균 대기분과 요일  을 보여주려고 셀렉트절에서 정의 하고 오더바이절에서 요일을 오름차순으로 정렬했다. 즉 요일별 평균 대기다. 3. 진료 테이블에서 접수 테이블을 조인해서 그룹 절로 요일별로 묶고 셀렉트절에서 요일.번호.평균대기분으로 보여주고 번호별로 오더바이절에서 오름차순 정렬 즉 요일 번호로 정렬했다. 4. 의사 스케줄 테이블에서 주마다 요일별로 열리는 진료수를 나타냈다. 화요일은 목요일보다 열리는 진료수가 많은데 평균대기시간은 화요일이 더 짧다.

## 27. 의사별 대기 시간

의사 이름은 `doctor` 테이블에 있다. 접수(`reception`)와 의사(`doctor`) 둘 다 `doctor_id`가 있어서 같은 이름 칸끼리 잇는다. 대기 시간 계산식은 23번과 같다.

```sql
SELECT dr.doctor_name, d.dept_name, COUNT(*), ROUND(AVG((t.start_at - r.reception_at) * 24 * 60), 1) AS 평균대기분
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
JOIN doctor dr ON r.doctor_id = dr.doctor_id
JOIN department d ON r.dept_id = d.dept_id
GROUP BY dr.doctor_name, d.dept_name
ORDER BY 평균대기분 DESC;
```

SELECT의 맨몸 컬럼이 `dr.doctor_name`, `d.dept_name` 두 개라서 `GROUP BY`에도 둘 다 쓴다.

| 의사 | 진료과 | 건수 | 평균 대기(분) |
|---|---|---:|---:|
| 이준민 | 정형외과 | 495 | 49.2 |
| 김재민 | 소화기내과 | 529 | 43.5 |
| 윤상성 | 소화기내과 | 511 | 42.9 |
| 류지태 | 소화기내과 | 550 | 42.9 |
| 임유우 | 정형외과 | 492 | 39.4 |
| 이은서 | 정형외과 | 498 | 38.8 |
| 홍진채 | 순환기내과 | 423 | 38.4 |
| 이서소 | 내분비내과 | 363 | 37.6 |
| 서유경 | 피부과 | 379 | 35.5 |
| 임정태 | 피부과 | 344 | 34.0 |
| 이우은 | 소아청소년과 | 278 | 30.0 |
| 박현민 | 순환기내과 | 373 | 29.0 |
| 오소태 | 안과 | 340 | 28.4 |
| 신희민 | 소아청소년과 | 285 | 26.4 |
| 김도미 | 순환기내과 | 414 | 26.0 |
| 장은현 | 내분비내과 | 360 | 24.5 |
| 김수영 | 소아청소년과 | 248 | 24.2 |
| 한상영 | 내분비내과 | 368 | 22.9 |
| 김소정 | 신경과 | 254 | 22.8 |
| 박성동 | 신경과 | 335 | 22.7 |
| 김경유 | 신경과 | 288 | 21.8 |
| 이우희 | 피부과 | 293 | 21.4 |
| 이동혜 | 안과 | 272 | 19.8 |
| 이호성 | 안과 | 268 | 18.2 |
| 합계 | | 8,960 | |

**위 2줄 vs 아래 2줄**

| 위치 | 의사 | 건수 | 평균 대기(분) |
|---|---|---:|---:|
| 위 1째 | 이준민 | 495 | 49.2 |
| 위 2째 | 김재민 | 529 | 43.5 |
| 아래 23째 | 이동혜 | 272 | 19.8 |
| 아래 24째 | 이호성 | 268 | 18.2 |

대기가 긴 의사는 건수가 거의 두 배다. 의사마다 외래가 주 2번으로 같아서(26번 ④, 의사 24명 × 2 = 48줄) 건수만 봐도 순서가 대체로 맞는다. 23번(과별)과 같은 모양이다.

같은 순환기내과의 홍진채(423건 · 38.4분)와 김도미(414건 · 26.0분)처럼 건수가 비슷한데 대기가 12분 넘게 차이 나는 경우도 있다. 건수가 대기를 전부 정하지는 않는다.

**해석:** 1. 프롬절 진료 테이블 에서 접수건별로 다른테이블에 조인하고 의사 테이블 에서 다른 테이블에 있는 의사 번호 별로 조인하고 진료과 테이블에서 진료과 번호 별로 조인을한후 그룹절에서 의사 이름 진료과 이름 별로 그룹을 묶고 셀렉트절에서 카운트로 행마다 세고 시작 시간 과 접수시간을 빼서 평균 대기분으로 계산하고 오더바이절에서 평균대기분 을 내림차순 정렬했다. 2. 위 2줄의 건수가 아래 2줄보다 많다.

## 28. 건수가 비슷한데 대기가 다른 이유 (COUNT DISTINCT · HAVING)

27번에서 같은 순환기내과의 홍진채(423건 · 38.4분)와 김도미(414건 · 26.0분)는 건수가 비슷한데 대기가 12분 넘게 달랐다. 두 단계로 확인한다.

### ① 진료를 몇 번 열었나

`TO_CHAR(reception_at, 'YYYY-MM-DD AM')`은 날짜와 오전/오후를 같이 꺼낸다 (예: `2026-01-02 08:29:21` → `2026-01-02 오전`). 같은 의사의 같은 날 오전 환자는 이름표가 같으므로, `DISTINCT`로 이름표를 한 번씩만 세면 진료를 연 횟수가 된다.

```sql
SELECT dr.doctor_name, COUNT(*) AS 건수,
       COUNT(DISTINCT TO_CHAR(r.reception_at, 'YYYY-MM-DD AM')) AS 진료수
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
JOIN doctor dr ON r.doctor_id = dr.doctor_id
WHERE dr.doctor_name IN ('홍진채', '김도미')
GROUP BY dr.doctor_name;
```

| 의사 | 건수 | 진료수 | 진료 한 번당 인원 (건수 ÷ 진료수) |
|---|---:|---:|---:|
| 홍진채 | 423 | 45 | 9.4 |
| 김도미 | 414 | 50 | 8.3 |

홍진채가 진료 한 번에 평균 1명쯤 더 봤다. 평균만으로는 붐빈 진료가 몰려 있었는지 알 수 없다.

### ② 15명 이상 붐빈 진료 (세션 정원 18명)

```sql
SELECT dr.doctor_name, TO_CHAR(r.reception_at, 'YYYY-MM-DD AM') AS 진료, COUNT(*) AS 인원
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
JOIN doctor dr ON r.doctor_id = dr.doctor_id
WHERE dr.doctor_name IN ('홍진채', '김도미')
GROUP BY dr.doctor_name, TO_CHAR(r.reception_at, 'YYYY-MM-DD AM')
HAVING COUNT(*) >= 15
ORDER BY dr.doctor_name, 인원 DESC;
```

`GROUP BY` 둘째 칸은 SELECT의 `TO_CHAR(...)`를 글자 그대로 복사한 것이다(맨몸 컬럼 규칙). 그래서 한 줄 = 의사 1명의 진료 한 번이 되고, `HAVING`이 묶은 뒤에 15명 이상인 줄만 남긴다.

| 의사 | 진료 | 인원 |
|---|---|---:|
| 김도미 | 2026-01-08 오후 | 17 |
| 김도미 | 2026-06-04 오후 | 16 |
| 김도미 | 2026-02-05 오후 | 15 |
| 김도미 | 2026-01-08 오전 | 15 |
| 홍진채 | 2026-05-18 오전 | 18 |
| 홍진채 | 2026-03-03 오후 | 18 |
| 홍진채 | 2026-02-23 오전 | 17 |
| 홍진채 | 2026-01-19 오전 | 17 |
| 홍진채 | 2026-02-09 오전 | 17 |
| 홍진채 | 2026-02-24 오후 | 17 |
| 홍진채 | 2026-05-11 오전 | 16 |
| 홍진채 | 2026-05-26 오후 | 16 |
| 홍진채 | 2026-03-09 오전 | 15 |
| 홍진채 | 2026-04-20 오전 | 15 |
| 홍진채 | 2026-02-02 오전 | 15 |
| 홍진채 | 2026-06-01 오전 | 15 |
| 홍진채 | 2026-03-30 오전 | 15 |
| 홍진채 | 2026-01-26 오전 | 15 |
| 홍진채 | 2026-01-12 오전 | 15 |

| 의사 | 15명 이상 진료 (줄 수) | 평균 대기(분, 27번) |
|---|---:|---:|
| 홍진채 | 15 | 38.4 |
| 김도미 | 4 | 26.0 |

**해석:** 건수는 홍진채 423 vs 김도미 414로 비슷하지만, 15명 이상 붐빈 진료는 홍진채 15번 vs 김도미 4번이다. 그래서 붐빈 진료가 적은 김도미의 평균 대기가 더 짧다.

## 29. 초진 / 재진별 대기 시간

22번에서 진료 시간은 초진 11.5분, 재진 5.5분으로 두 배 차이였다. 대기 시간도 차이가 날까? 계산식은 23번과 같고 묶는 기준만 `visit_type`(방문 유형: 초진·재진)으로 바꾼다.

```sql
SELECT r.visit_type, COUNT(*) AS 건수,
       ROUND(AVG((t.start_at - r.reception_at) * 24 * 60), 1) AS 평균대기분
FROM treatment t
JOIN reception r ON t.reception_id = r.reception_id
GROUP BY r.visit_type;
```

| 방문 유형 | 건수 | 평균 대기(분) | 진료 시간(분, 22번) |
|---|---:|---:|---:|
| 재진 | 4,908 | 32.7 | 5.5 |
| 초진 | 4,052 | 32.8 | 11.5 |

**근거 — 실제 두 줄** (임정태 2026-01-14 오전)

| 접수번호 | 유형 | 접수 | 진료 시작 | 진료 끝 | 대기(분) | 진료(분) |
|---|---|---|---|---|---:|---:|
| 722 | 초진 | 09:25:40 | 09:33:40 | 09:46:11 | 8.0 | 12.5 |
| 723 | 재진 | 09:26:46 | 09:47:01 | 09:54:19 | 20.3 | 7.3 |

723번은 722번보다 1분 늦게 접수해서, 722번 진료가 끝난(09:46) 뒤에야 시작했다(09:47). 초진 722번의 긴 진료 12.5분은 뒷사람 723번의 대기에 들어갔다.

**해석:** 진료 시간은 초진 11.5 vs 재진 5.5로 두 배 차이지만, 대기 시간은 초진 32.8 vs 재진 32.7로 비슷하다. 대기는 앞사람의 진료 시간으로 정해지기 때문이다.

## 30. 역할별 직원 수 (권한 테이블 첫 조회)

권한 테이블 4개(`role` · `staff` · `menu` · `role_menu`)를 추가했다 → 1·2·3·8번 참고. 직원(`staff`)과 역할(`role`) 둘 다 `role_id`가 있어서 같은 이름 칸끼리 잇는다. 27번에서 `doctor_id`로 이은 것과 같은 모양이다. 접수 별칭 `r`과 겹치지 않게 역할은 `ro`로 쓴다.

### ① 전체 직원

```sql
SELECT ro.role_name, COUNT(*) AS 직원수
FROM staff s
JOIN role ro ON s.role_id = ro.role_id
GROUP BY ro.role_name
ORDER BY 직원수 DESC;
```

### ② 재직 직원만

`staff`의 `status`는 재직 / 퇴사다. `reception`에도 `status`(정상 / 취소)가 있지만 테이블이 다르면 다른 칸이라 `s.`을 붙인다. ①과 다른 곳은 `WHERE` 한 줄뿐이다.

```sql
SELECT ro.role_name, COUNT(*) AS 직원수
FROM staff s
JOIN role ro ON s.role_id = ro.role_id
WHERE s.status = '재직'
GROUP BY ro.role_name
ORDER BY 직원수 DESC;
```

| 역할 | ① 전체 | ② 재직만 |
|---|---:|---:|
| 의사 | 24 | 24 |
| 간호사 | 16 | 14 |
| 원무 | 8 | 8 |
| 약제 | 5 | 5 |
| 전산 | 4 | 3 |
| 합계 | 57 | 54 |

**해석:** 전체 57명 중 재직만 세면 54명이다. 퇴사자가 있는 역할은 간호사와 전산이다.

## 31. 역할별로 볼 수 있는 메뉴 (role_menu)

`role_menu`는 "이 역할이 이 메뉴를 볼 수 있다"를 한 줄씩 적은 표다. 줄이 **있으면** 볼 수 있고, `can_write`가 `Y`면 고치기도 가능, `N`이면 보기만 가능하다.

| 경우 | 예 | `role_menu`에 줄 | `can_write` | 뜻 |
|---|---|---|---|---|
| ① | 간호사 + 수납(201) | 없음 | — | 메뉴가 안 보임 |
| ② | 간호사 + 접수(101) | 있음 | N | 보기만 가능 |
| ③ | 의사 + 진료기록(102) | 있음 | Y | 보기 + 고치기 가능 |

### ① 역할별 메뉴 수

30번과 같은 모양이고 `FROM` 뒤 테이블만 `staff s` → `role_menu rm`으로 바뀌었다. 한 줄 = 메뉴 하나라서 `COUNT(*)`가 메뉴 수다.

```sql
SELECT ro.role_name, COUNT(*) AS 메뉴수
FROM role_menu rm
JOIN role ro ON rm.role_id = ro.role_id
GROUP BY ro.role_name
ORDER BY 메뉴수 DESC;
```

| 역할 | 메뉴 수 |
|---|---:|
| 의사 | 7 |
| 원무 | 7 |
| 전산 | 6 |
| 간호사 | 4 |
| 약제 | 3 |
| 합계 | 27 |

### ② 간호사가 볼 수 있는 메뉴

메뉴 이름은 `menu`에 있어서 `menu_id`로 잇는다. `WHERE rm.role_id = 2`의 2는 `role` 테이블에서 간호사의 번호다. 결과 줄 수는 ①의 간호사 `메뉴수`(4)와 같아야 한다 → 실행 전 예상 4줄, 결과 4줄.

```sql
SELECT m.menu_id, m.menu_name, rm.can_write
FROM role_menu rm
JOIN menu m ON rm.menu_id = m.menu_id
WHERE rm.role_id = 2
ORDER BY m.menu_id;
```

| 메뉴 번호 | 메뉴 이름 | can_write |
|---:|---|---|
| 101 | 접수 | N |
| 102 | 진료기록 | N |
| 104 | 외래 일정 | N |
| 403 | 대기 시간 통계 | N |

**해석:** 1. 역할별로 의사, 원무가 메뉴 권한 7개로 가장 많고 그다음으로 전산,간호사,약제 순으로 메뉴 권한수가 나열된다. 2. 간호사 메뉴권한은 4개이지만 보기만 할 수 있다.

## 32. 아무 역할도 못 보는 메뉴 (LEFT JOIN + IS NULL)

10번 미수납과 같은 모양이다. 왼쪽 표의 줄은 짝이 없어도 전부 남기고, 짝이 없는 줄은 오른쪽 칸이 빈칸이 된다.

| | 10번 미수납 | 32번 |
|---|---|---|
| 왼쪽 (전부 남김) | `reception r` | `menu m` |
| 오른쪽 (짝이 없을 수도 있음) | `payment p` | `role_menu rm` |
| 짝 없는 줄 찾기 | `p.payment_id IS NULL` | `rm.role_id IS NULL` |

`LEFT JOIN`은 메뉴 한 줄마다 `menu_id`가 같은 권한 줄을 전부 붙인다 (예: 101 접수는 의사·간호사·원무 → 3줄). 짝이 없는 메뉴는 1줄로 남고 `rm` 칸이 빈칸이다.

### ① 권한 줄이 없는 메뉴

```sql
SELECT m.menu_id, m.menu_name, m.parent_id
FROM menu m
LEFT JOIN role_menu rm ON m.menu_id = rm.menu_id
WHERE rm.role_id IS NULL
ORDER BY m.menu_id;
```

| menu_id | menu_name | parent_id |
|---:|---|---:|
| 100 | 외래 | |
| 200 | 원무 | |
| 300 | 약제 | |
| 400 | 통계 | |
| 500 | 시스템 관리 | |
| 504 | 공지사항 관리 | 500 |

6줄 중 5줄은 `parent_id`가 빈칸인 **맨 위 메뉴**다. 맨 위 메뉴는 아래 메뉴를 모아 둔 제목이고, 이 데이터는 권한을 아래 메뉴에만 준다(31번). 그래서 권한 줄이 없는 게 원래 그렇다.

### ② 아래 메뉴만 남기기

```sql
SELECT m.menu_id, m.menu_name, m.parent_id
FROM menu m
LEFT JOIN role_menu rm ON m.menu_id = rm.menu_id
WHERE rm.role_id IS NULL
  AND m.parent_id IS NOT NULL
ORDER BY m.menu_id;
```

| menu_id | menu_name | parent_id |
|---:|---|---:|
| 504 | 공지사항 관리 | 500 |

`WHERE`의 두 줄은 서로 다른 테이블의 칸을 본다.

| 조건 | 테이블 | 504의 값 | 뜻 |
|---|---|---|---|
| `rm.role_id IS NULL` | role_menu (권한) | 빈칸 | 권한 줄이 없다 → 못 봄 |
| `m.parent_id IS NOT NULL` | menu (메뉴) | 500 | 위에 메뉴가 있다 → 아래 메뉴 |

```
500 시스템 관리
 ├ 501 사용자 관리       ← 전산
 ├ 502 메뉴 권한 관리    ← 전산
 ├ 503 SMS 발송내역      ← 전산
 └ 504 공지사항 관리     ← 아무도 없음
```

**검산:** `SELECT * FROM role_menu WHERE menu_id = 504;` → `선택된 레코드가 없습니다` (0줄)

**해석:** 아무 역할도 못 보는 메뉴는 공지사항 관리이다. role_menu 테이블에 504 줄이 없기 때문이다.

## 33. 직원 1명이 볼 수 있는 메뉴 (테이블 3개 JOIN · 퇴사 제외)

직원에서 메뉴 이름까지 가려면 테이블 3개를 거친다. 테이블 사이는 같은 이름 칸으로 잇는다.

```
staff s ──role_id── role_menu rm ──menu_id── menu m
(직원)              (역할-메뉴 권한)          (메뉴 이름)
```

### ① 재직 간호사 20025

```sql
SELECT s.staff_name, m.menu_id, m.menu_name, rm.can_write
FROM staff s
JOIN role_menu rm ON s.role_id = rm.role_id
JOIN menu m       ON rm.menu_id = m.menu_id
WHERE s.staff_id = 20025
  AND s.status = '재직'
ORDER BY m.menu_id;
```

| staff_name | menu_id | menu_name | can_write |
|---|---:|---|---|
| 김윤유 | 101 | 접수 | N |
| 김윤유 | 102 | 진료기록 | N |
| 김윤유 | 104 | 외래 일정 | N |
| 김윤유 | 403 | 대기 시간 통계 | N |

31번 ② 간호사 메뉴 4줄과 같다.

### ② 퇴사 간호사 20033

①에서 `20025`만 `20033`으로 바꿨다. → `선택된 레코드가 없습니다` (0줄)

### ③ 검산: `status` 조건을 빼면

②에서 `AND s.status = '재직'` 줄만 지웠다. → 4줄 (101 · 102 · 104 · 403, ①과 같은 메뉴)

| 직원 | role_id | status | `s.status = '재직'` 있음 | 없음 |
|---|---:|---|---:|---:|
| 20025 김윤유 | 2 | 재직 | 4줄 | 4줄 |
| 20033 최채도 | 2 | 퇴사 | **0줄** | 4줄 |

`role_menu`는 역할(`role_id`)만 보고 메뉴를 준다. 퇴사 여부는 `staff.status`에만 있어서, 퇴사자를 빼는 건 `WHERE`의 `status` 조건 한 줄이다.

**해석:** 같은 간호사 role id 2 인데 20025는 4줄 20033은 0줄이다. 20033은 재직상태가 아니라서 그렇고 웨어절로 재직상태를 지우고 조회하면 조회가 가능하다.

## 34. 메뉴 옆에 상위 메뉴 이름 붙이기 (셀프 조인)

`parent_id`(parent = 부모)는 **그 메뉴가 들어 있는 위 메뉴의 번호**다. 위 메뉴의 이름도 같은 `menu` 테이블에 있으므로, `menu`를 두 번 꺼내 별칭을 다르게 붙여 잇는다. 수납 `p`와 겹치지 않게 위 메뉴 쪽 별칭은 `up`으로 쓴다.

```
menu m  (아래 메뉴) ──m.parent_id = up.menu_id── menu up  (위 메뉴)
```

| 순서 | 보는 곳 | 값 |
|---|---|---|
| 1 | `m` 쪽 102 진료기록 줄의 `parent_id` | 100 |
| 2 | `up` 쪽에서 `menu_id`가 100인 줄 | 100 외래 |
| 3 | 두 줄을 옆으로 붙임 | `102 진료기록 \| 100 외래` |

```sql
SELECT m.menu_id, m.menu_name, up.menu_id AS 상위번호, up.menu_name AS 상위메뉴
FROM menu m
JOIN menu up ON m.parent_id = up.menu_id
ORDER BY m.menu_id;
```

| menu_id | menu_name | 상위번호 | 상위메뉴 |
|---:|---|---:|---|
| 101 | 접수 | 100 | 외래 |
| 102 | 진료기록 | 100 | 외래 |
| 103 | 처방 | 100 | 외래 |
| 104 | 외래 일정 | 100 | 외래 |
| 201 | 수납 | 200 | 원무 |
| 202 | 미수납 관리 | 200 | 원무 |
| 203 | 환자 등록 | 200 | 원무 |
| 301 | 처방 확인 | 300 | 약제 |
| 302 | 조제 내역 | 300 | 약제 |
| 401 | 접수 통계 | 400 | 통계 |
| 402 | 수납 통계 | 400 | 통계 |
| 403 | 대기 시간 통계 | 400 | 통계 |
| 501 | 사용자 관리 | 500 | 시스템 관리 |
| 502 | 메뉴 권한 관리 | 500 | 시스템 관리 |
| 503 | SMS 발송내역 | 500 | 시스템 관리 |
| 504 | 공지사항 관리 | 500 | 시스템 관리 |

16줄 = 2번 표의 하위 메뉴 16개. 맨 위 메뉴 5개는 `parent_id`가 빈칸이라 짝이 없어서 `JOIN`에서 빠진다(10번과 같음).

**ON 줄을 다르게 쓰면** — 셋 다 에러 없이 실행된다.

| ON 줄 | 줄 수 | 첫 줄 | 판정 |
|---|---:|---|---|
| `m.parent_id = up.parent_id` | 54 | `101 접수 \| 101 접수` | ❌ 위 메뉴가 같은 것끼리 짝지음 (4×4 + 3×3 + 2×2 + 3×3 + 4×4 = 54) |
| `m.menu_id = up.parent_id` | 16 | `100 외래 \| 101 접수` | ❌ 줄 수는 맞지만 위·아래가 뒤집힘 |
| `m.parent_id = up.menu_id` | 16 | `101 접수 \| 100 외래` | ✅ |

`=` 양쪽 자리를 바꾸는 것(`up.menu_id = m.parent_id`)은 결과가 같다. 결과가 달라지는 건 `m.`과 `up.` 뒤의 칸 이름이 서로 바뀔 때다.

**해석:** 진료기록의 상위 번호는 100이고 100번 메뉴는 외래라서 옆에 외래가 붙었다.

## 35. 맨 위 메뉴까지 보기 (셀프 조인 + LEFT JOIN)

34번에서 `JOIN`을 `LEFT JOIN`으로만 바꿨다. 왼쪽(`FROM`에 먼저 쓴 `menu m`)의 줄은 짝이 없어도 전부 남고, 짝이 없는 줄은 `up` 쪽 칸이 빈칸이다.

```sql
SELECT m.menu_id, m.menu_name, up.menu_id AS 상위번호, up.menu_name AS 상위메뉴
FROM menu m
LEFT JOIN menu up ON m.parent_id = up.menu_id
ORDER BY m.menu_id;
```

| menu_id | menu_name | 상위번호 | 상위메뉴 |
|---:|---|---:|---|
| **100** | **외래** | | |
| 101 | 접수 | 100 | 외래 |
| 102 | 진료기록 | 100 | 외래 |
| 103 | 처방 | 100 | 외래 |
| 104 | 외래 일정 | 100 | 외래 |
| **200** | **원무** | | |
| 201 | 수납 | 200 | 원무 |
| 202 | 미수납 관리 | 200 | 원무 |
| 203 | 환자 등록 | 200 | 원무 |
| **300** | **약제** | | |
| 301 | 처방 확인 | 300 | 약제 |
| 302 | 조제 내역 | 300 | 약제 |
| **400** | **통계** | | |
| 401 | 접수 통계 | 400 | 통계 |
| 402 | 수납 통계 | 400 | 통계 |
| 403 | 대기 시간 통계 | 400 | 통계 |
| **500** | **시스템 관리** | | |
| 501 | 사용자 관리 | 500 | 시스템 관리 |
| 502 | 메뉴 권한 관리 | 500 | 시스템 관리 |
| 503 | SMS 발송내역 | 500 | 시스템 관리 |
| 504 | 공지사항 관리 | 500 | 시스템 관리 |

| 조인 | 줄 수 | 맨 위 메뉴 5개 (100 · 200 · 300 · 400 · 500) |
|---|---:|---|
| 34번 `JOIN` | 16 | 빠짐 |
| 35번 `LEFT JOIN` | **21** | 남음 · 상위번호·상위메뉴 칸 빈칸 |

21줄 = `menu` 테이블 전체 21줄. 맨 위 메뉴는 `parent_id`가 빈칸이라 `up` 쪽에 짝이 없다.

**해석:** 이너조인과는 다르게 레프트 조인이라서 빈칸이 따라 붙고 16줄에서 21줄로 늘어나 외래 원무 약제 통계 시스템 관리는 빈칸이 되어 붙었다.

## 36. 메뉴마다 볼 수 있는 역할 수 (LEFT JOIN + COUNT(*) · COUNT(칸))

32번과 같은 조인에 `GROUP BY`를 붙여 메뉴마다 센다. 같은 묶음을 `COUNT` 두 가지로 세면 숫자가 다른 줄이 생긴다.

| 순서 | 하는 일 | 줄 수 |
|---|---|---:|
| 1 | `menu m` 전체 | 21 |
| 2 | `LEFT JOIN role_menu rm` | 33 = 권한 줄 27 + 짝 없는 메뉴 6 |
| 3 | `GROUP BY m.menu_id, m.menu_name` | 21 |

```sql
SELECT m.menu_id, m.menu_name,
       COUNT(*)          AS 전체줄,
       COUNT(rm.role_id) AS 역할수
FROM menu m
LEFT JOIN role_menu rm ON m.menu_id = rm.menu_id
GROUP BY m.menu_id, m.menu_name
ORDER BY m.menu_id;
```

| menu_id | menu_name | 전체줄 | 역할수 |
|---:|---|---:|---:|
| **100** | **외래** | **1** | **0** |
| 101 | 접수 | 3 | 3 |
| 102 | 진료기록 | 2 | 2 |
| 103 | 처방 | 2 | 2 |
| 104 | 외래 일정 | 3 | 3 |
| **200** | **원무** | **1** | **0** |
| 201 | 수납 | 1 | 1 |
| 202 | 미수납 관리 | 1 | 1 |
| 203 | 환자 등록 | 1 | 1 |
| **300** | **약제** | **1** | **0** |
| 301 | 처방 확인 | 2 | 2 |
| 302 | 조제 내역 | 1 | 1 |
| **400** | **통계** | **1** | **0** |
| 401 | 접수 통계 | 3 | 3 |
| 402 | 수납 통계 | 2 | 2 |
| 403 | 대기 시간 통계 | 3 | 3 |
| **500** | **시스템 관리** | **1** | **0** |
| 501 | 사용자 관리 | 1 | 1 |
| 502 | 메뉴 권한 관리 | 1 | 1 |
| 503 | SMS 발송내역 | 1 | 1 |
| **504** | **공지사항 관리** | **1** | **0** |

숫자가 다른 6줄은 32번 ①의 6줄(짝 없는 메뉴)과 같다. `역할수`를 다 더하면 27 = `role_menu` 전체 줄 수.

| 메뉴 | `LEFT JOIN` 뒤 줄 | `COUNT(*)` | `COUNT(rm.role_id)` |
|---|---|---:|---:|
| 101 접수 | 의사 · 간호사 · 원무 3줄 | 3 | 3 |
| 100 외래 | `rm.role_id`가 빈칸인 1줄 | 1 | 0 |

`COUNT(*)`는 묶인 줄 수를 세고, `COUNT(칸)`은 그 칸에 값이 있는 줄만 센다.

**해석:** 카운트(*)와 카운트(칸)은 역할이 달라 각각 카운트(*)는 메뉴마다 묶인 줄 수를 세고 카운트(칸)은 값이 들어있는행만 센다. 외래·원무·약제·통계·시스템 관리·공지사항 관리 6개 메뉴는 전체줄 1, 역할수 0이다.

## 37. 고칠 수 있는 권한만 보기 (테이블 3개 JOIN + `WHERE can_write`)

`role_menu`에 줄이 있으면 그 메뉴를 볼 수 있고, 그 줄의 `can_write`(can = ~할 수 있다 · write = 쓰다)가 `Y`이면 고치기도 할 수 있다. 33번처럼 테이블 3개를 잇고 `WHERE` 한 줄로 `Y`인 줄만 남긴다.

```
role ro ──role_id── role_menu rm ──menu_id── menu m
(역할 이름)          (권한 · can_write)         (메뉴 이름)
```

```sql
SELECT ro.role_name, m.menu_id, m.menu_name, rm.can_write
FROM role_menu rm
JOIN role ro ON rm.role_id = ro.role_id
JOIN menu m  ON rm.menu_id = m.menu_id
WHERE rm.can_write = 'Y'
ORDER BY ro.role_id, m.menu_id;
```

| role_name | menu_id | menu_name | can_write |
|---|---:|---|---|
| 의사 | 102 | 진료기록 | Y |
| 의사 | 103 | 처방 | Y |
| 원무 | 101 | 접수 | Y |
| 원무 | 201 | 수납 | Y |
| 원무 | 202 | 미수납 관리 | Y |
| 원무 | 203 | 환자 등록 | Y |
| 약제 | 301 | 처방 확인 | Y |
| 약제 | 302 | 조제 내역 | Y |
| 전산 | 501 | 사용자 관리 | Y |
| 전산 | 502 | 메뉴 권한 관리 | Y |

| 역할 | 볼 수 있는 메뉴 (31번 ①) | 고칠 수 있는 메뉴 (37번) |
|---|---:|---:|
| 의사 | 7 | 2 |
| 간호사 | 4 | **0** |
| 원무 | 7 | 4 |
| 약제 | 3 | 2 |
| 전산 | 6 | 2 |
| 합계 | 27 | 10 |

간호사는 볼 수 있는 메뉴 4개(31번 ②)가 전부 `can_write = 'N'`이라서 결과에 한 줄도 없다.

**해석:** 의사·약제·원무·전산에서 고칠 수 있는 메뉴 이름들을 Y로 나타냈다. 그래서 27줄 중 10줄이고 간호사가 볼 수 있는 메뉴는 4개이나 Y가 0개라서 결과에 없다.

## 38. 역할별 볼 수 있는 메뉴 수 vs 고칠 수 있는 메뉴 수 (SUM + DECODE · WHERE와 비교)

31번 ①(볼 수 있는 메뉴 수)에 19번 방식(`SUM(DECODE(...))`)으로 칸 하나를 더 붙여, 37번의 고칠 수 있는 메뉴 수를 같은 표에 놓는다.

### ① SUM(DECODE)

줄마다 `can_write`가 `Y`면 1, 아니면 0을 적고 `SUM`으로 더한다.

```sql
SELECT ro.role_name,
       COUNT(*)                              AS 볼수있는,
       SUM(DECODE(rm.can_write, 'Y', 1, 0)) AS 고칠수있는
FROM role_menu rm
JOIN role ro ON rm.role_id = ro.role_id
GROUP BY ro.role_id, ro.role_name
ORDER BY ro.role_id;
```

| role_name | 볼수있는 | 고칠수있는 |
|---|---:|---:|
| 의사 | 7 | 2 |
| 간호사 | 4 | **0** |
| 원무 | 7 | 4 |
| 약제 | 3 | 2 |
| 전산 | 6 | 2 |
| 합계 | 27 | 10 |

37번 표와 숫자 5쌍이 모두 같다.

### ② WHERE로 먼저 거르면

①에서 `SUM(DECODE(...))` 줄을 빼고, 37번의 `WHERE rm.can_write = 'Y'`를 넣었다.

```sql
SELECT ro.role_name, COUNT(*) AS 고칠수있는
FROM role_menu rm
JOIN role ro ON rm.role_id = ro.role_id
WHERE rm.can_write = 'Y'
GROUP BY ro.role_id, ro.role_name
ORDER BY ro.role_id;
```

| role_name | 고칠수있는 |
|---|---:|
| 의사 | 2 |
| 원무 | 4 |
| 약제 | 2 |
| 전산 | 2 |

| 방법 | 줄 수 | 간호사 줄 |
|---|---:|---|
| ① `SUM(DECODE(...))` | 5 | 남음 · 고칠수있는 0 |
| ② `WHERE` + `COUNT(*)` | 4 | 없음 |

| 순서 | ① | ② |
|---|---|---|
| FROM + JOIN | 27줄 (간호사 4줄 포함) | 27줄 (간호사 4줄 포함) |
| WHERE | 없음 → 27줄 | `Y`만 남김 → 10줄 (간호사 4줄은 전부 `N`) |
| GROUP BY | 5묶음 · 간호사는 0을 더해 0 | 4묶음 · 간호사는 묶을 줄이 없음 |

`WHERE`는 세기 전에 줄을 지우고, `SUM(DECODE(...))`는 줄을 남긴 채 0을 적는다.

**해석:** ①은 간호사 줄이 남고 고칠수있는 칸은 0 이다. ②는 4줄이고 간호사 줄이 없다. 간호사 4줄은 can_write가 전부 N이라서 웨어절에서 지워졌기 때문이다.
