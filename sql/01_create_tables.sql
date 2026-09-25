-- ============================================================
-- 01. 테이블 생성 (Oracle)
-- 실행: emr 계정으로 접속한 뒤  SQL> @X:\hospital-emr-portfolio\sql\01_create_tables.sql
-- 만드는 순서 = 참조받는 쪽 먼저 (부모 → 자식)
-- ============================================================

-- 진료과
CREATE TABLE department (
    dept_id     NUMBER(3)          PRIMARY KEY,
    dept_code   VARCHAR2(5 CHAR)   NOT NULL UNIQUE,
    dept_name   VARCHAR2(20 CHAR)  NOT NULL,
    floor       NUMBER(2)
);

-- 의사
CREATE TABLE doctor (
    doctor_id    NUMBER(5)          PRIMARY KEY,
    doctor_name  VARCHAR2(20 CHAR)  NOT NULL,
    dept_id      NUMBER(3)          NOT NULL REFERENCES department (dept_id),
    position     VARCHAR2(10 CHAR),
    hire_date    DATE
);

-- 외래 일정 (의사 1명 × 요일 × 오전/오후)
CREATE TABLE doctor_schedule (
    doctor_id     NUMBER(5)         NOT NULL REFERENCES doctor (doctor_id),
    weekday       VARCHAR2(1 CHAR)  NOT NULL CHECK (weekday IN ('월','화','수','목','금')),
    session_type  VARCHAR2(2 CHAR)  NOT NULL CHECK (session_type IN ('AM','PM')),
    PRIMARY KEY (doctor_id, weekday, session_type)
);

-- 환자
CREATE TABLE patient (
    patient_id     NUMBER(8)          PRIMARY KEY,
    patient_name   VARCHAR2(20 CHAR)  NOT NULL,
    gender         CHAR(1)            CHECK (gender IN ('M','F')),
    birth_date     DATE,
    phone          VARCHAR2(20 CHAR),
    registered_at  DATE
);

-- 접수
CREATE TABLE reception (
    reception_id  NUMBER(10)        PRIMARY KEY,
    patient_id    NUMBER(8)         NOT NULL REFERENCES patient (patient_id),
    dept_id       NUMBER(3)         NOT NULL REFERENCES department (dept_id),
    doctor_id     NUMBER(5)         NOT NULL REFERENCES doctor (doctor_id),
    reception_at  DATE              NOT NULL,
    visit_type    VARCHAR2(2 CHAR)  CHECK (visit_type IN ('초진','재진')),
    status        VARCHAR2(2 CHAR)  CHECK (status IN ('정상','취소'))
);

-- 진료 (접수 1건당 최대 1건 → reception_id UNIQUE)
CREATE TABLE treatment (
    treatment_id  NUMBER(10)  PRIMARY KEY,
    reception_id  NUMBER(10)  NOT NULL UNIQUE REFERENCES reception (reception_id),
    start_at      DATE,
    end_at        DATE
);

-- 수납 (접수 1건당 최대 1건 → reception_id UNIQUE)
CREATE TABLE payment (
    payment_id        NUMBER(10)         PRIMARY KEY,
    reception_id      NUMBER(10)         NOT NULL UNIQUE REFERENCES reception (reception_id),
    paid_at           DATE,
    total_amount      NUMBER(10),
    insurance_amount  NUMBER(10),
    patient_amount    NUMBER(10),
    method            VARCHAR2(10 CHAR)
);

-- 확인: 7개가 나오면 성공
SELECT table_name FROM user_tables ORDER BY table_name;
