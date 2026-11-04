# ============================================================
# CSV 11개를 Oracle 테이블에 적재 (부모 테이블부터 차례로)
# - 먼저 sql/01_create_tables.sql → sql/02_create_auth_tables.sql로 테이블을 만든다.
# - 테이블이 비어 있을 때 한 번만 돌린다. (.ctl이 APPEND라서 다시 돌리면 기본키 중복으로 멈춘다)
# - 비밀번호는 한 번만 묻는다. 명령 줄에 남지 않게 임시 parfile에 적었다가 끝나면 지운다.
# - 로그 · bad 파일은 저장소 밖 임시 폴더(%TEMP%\hospital-emr-load)에 남는다.
# 사용법: powershell -ExecutionPolicy Bypass -File scripts\load_data.ps1
#         powershell -ExecutionPolicy Bypass -File scripts\load_data.ps1 -User emr -Service //localhost:1521/FREEPDB1
#         (-ExecutionPolicy Bypass는 이번 실행에만 적용 · PC의 실행 정책은 그대로)
# ============================================================
param(
    [string]$User    = 'emr',
    [string]$Service = '//localhost:1521/FREEPDB1'
)
$ErrorActionPreference = 'Stop'

# 부모 테이블부터 (FK가 가리키는 테이블이 먼저 차 있어야 한다)
$order = 'department', 'doctor', 'doctor_schedule', 'patient', 'reception',
         'treatment', 'payment', 'role', 'menu', 'staff', 'role_menu'

$root   = Split-Path -Parent $PSScriptRoot        # 저장소 맨 위 폴더 (scripts의 한 단계 위)
$logDir = Join-Path ([IO.Path]::GetTempPath()) 'hospital-emr-load'
$par    = Join-Path $logDir 'userid.par'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$secure = Read-Host "$User 비밀번호" -AsSecureString
$bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)

Push-Location $root                               # .ctl의 INFILE 'data/....csv'는 실행한 폴더 기준
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [IO.File]::WriteAllText($par, "userid=$User/$plain@$Service")
    $plain = $null

    foreach ($t in $order) {
        # -Encoding UTF8이 없으면 Windows PowerShell 5.1은 CP949로 읽어서, 홀수 글자 한글로 끝나는 줄(role.csv의 간호사)이 다음 줄과 붙는다
        $rows = @(Get-Content -LiteralPath "data/$t.csv" -Encoding UTF8).Count - 1   # 첫 줄(컬럼명) 제외
        $log  = Join-Path $logDir "$t.log"
        $bad  = Join-Path $logDir "$t.bad"
        Write-Host ('{0,-16} CSV {1,6:N0}행' -f $t, $rows)
        & sqlldr "parfile=$par" "control=sql/load/$t.ctl" "log=$log" "bad=$bad" 'silent=feedback'
        # 0 = 모든 줄 적재 · 2 = 거부되거나 버려진 줄 있음 · 그 밖 = 실패
        if ($LASTEXITCODE -ne 0) {
            throw "$t 적재 실패 (sqlldr 종료 코드 $LASTEXITCODE) · 로그: $log"
        }
    }
    Write-Host "11개 테이블 적재 완료 · 로그: $logDir"
    Write-Host '행 수가 SQL.md 2번 표와 같은지 확인한다.'
}
finally {
    if (Test-Path -LiteralPath $par) { Remove-Item -LiteralPath $par -Force }
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Pop-Location
}
