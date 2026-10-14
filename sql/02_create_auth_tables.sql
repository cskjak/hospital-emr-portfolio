-- ============================================================
-- 02. 권한 테이블 생성 (Oracle) — 역할 · 메뉴 · 직원 · 역할-메뉴 권한
-- 실행: emr 계정으로 접속한 뒤  SQL> @X:\hospital-emr-portfolio\sql\02_create_auth_tables.sql
-- 01번(진료 테이블 7개)이 먼저 있어야 함 (staff가 department · doctor를 참조)
-- 만드는 순서 = 참조받는 쪽 먼저 (부모 → 자식)
-- ============================================================

-- 역할
CREATE TABLE role (
    role_id    NUMBER(2)          PRIMARY KEY,
    role_code  VARCHAR2(5 CHAR)   NOT NULL UNIQUE,
    role_name  VARCHAR2(20 CHAR)  NOT NULL
);

-- 메뉴 (parent_id = 상위 메뉴 번호 → 같은 menu 테이블을 참조 · 빈칸이면 맨 위 메뉴)
CREATE TABLE menu (
    menu_id     NUMBER(4)          PRIMARY KEY,
    menu_name   VARCHAR2(30 CHAR)  NOT NULL,
    parent_id   NUMBER(4)          REFERENCES menu (menu_id),
    sort_order  NUMBER(2)
);

-- 직원 (의사는 doctor_id로 doctor 테이블과 이어짐 · 의사가 아니면 빈칸)
CREATE TABLE staff (
    staff_id    NUMBER(5)          PRIMARY KEY,
    staff_name  VARCHAR2(20 CHAR)  NOT NULL,
    role_id     NUMBER(2)          NOT NULL REFERENCES role (role_id),
    dept_id     NUMBER(3)          REFERENCES department (dept_id),
    doctor_id   NUMBER(5)          UNIQUE REFERENCES doctor (doctor_id),
    hire_date   DATE,
    status      VARCHAR2(2 CHAR)   CHECK (status IN ('재직','퇴사'))
);

-- 역할-메뉴 권한 (행이 있으면 볼 수 있음 · can_write = 'Y'면 고치기도 가능)
CREATE TABLE role_menu (
    role_id    NUMBER(2)  NOT NULL REFERENCES role (role_id),
    menu_id    NUMBER(4)  NOT NULL REFERENCES menu (menu_id),
    can_write  CHAR(1)    CHECK (can_write IN ('Y','N')),
    PRIMARY KEY (role_id, menu_id)
);

-- 확인: 11개가 나오면 성공 (01번 7개 + 02번 4개)
SELECT table_name FROM user_tables ORDER BY table_name;
