-- payment.csv → payment 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\payment.csv' "STR '\n'"
APPEND INTO TABLE payment
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(payment_id, reception_id, paid_at DATE "YYYY-MM-DD HH24:MI:SS", total_amount, insurance_amount, patient_amount, method)
