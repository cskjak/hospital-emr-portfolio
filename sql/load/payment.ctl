-- payment.csv → payment 테이블 (저장소 맨 위 폴더에서 실행 · INFILE 경로가 그 폴더 기준)
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'data/payment.csv' "STR '\n'"
APPEND INTO TABLE payment
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(payment_id, reception_id, paid_at DATE "YYYY-MM-DD HH24:MI:SS", total_amount, insurance_amount, patient_amount, method)
