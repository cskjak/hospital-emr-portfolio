# ============================================================
# 권한 테이블 데이터 생성기 (역할 · 직원 · 메뉴 · 역할-메뉴 권한)
# - 모든 이름은 무작위로 지어낸 값입니다. 실제 데이터 아님.
# - 메뉴 이름은 일반적인 외래 업무 이름만 씁니다.
# - 시드 고정 → 몇 번을 돌려도 같은 데이터가 나옵니다.
# - department.csv · doctor.csv 는 읽기만 합니다 (의사 24명도 직원으로 들어감).
# 사용법: powershell -File generate_auth.ps1 -DataDir <data 폴더>
# ============================================================
param(
    [Parameter(Mandatory = $true)][string]$DataDir
)
$ErrorActionPreference = 'Stop'

# ---- 안전장치: 만들 파일이 이미 있으면 덮어쓰지 않음 ----
$outNames = 'role', 'staff', 'menu', 'role_menu'
Write-Host "출력 경로: $DataDir"
foreach ($n in $outNames) {
    $p = Join-Path $DataDir "$n.csv"
    if (Test-Path $p) { throw "이미 존재하는 파일입니다. 덮어쓰지 않고 중단합니다: $p" }
}

$rng  = New-Object System.Random 20261014
$inv  = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object System.Text.UTF8Encoding $false

function RInt([int]$a, [int]$b) { $script:rng.Next($a, $b + 1) }          # a~b 정수
function Pick($arr) { $arr[$script:rng.Next(0, $arr.Count)] }
function PickW($items, $weights) {                                     # 가중치 뽑기
    $t = 0; foreach ($w in $weights) { $t += $w }
    $x = $script:rng.NextDouble() * $t
    for ($i = 0; $i -lt $items.Count; $i++) { $x -= $weights[$i]; if ($x -lt 0) { return $items[$i] } }
    return $items[$items.Count - 1]
}
function FD([datetime]$dt) { $dt.ToString('yyyy-MM-dd', $script:inv) }

# ---- 읽기: 진료과 · 의사 ----
$depts   = @(Import-Csv (Join-Path $DataDir 'department.csv') -Encoding UTF8)
$doctors = @(Import-Csv (Join-Path $DataDir 'doctor.csv') -Encoding UTF8)

# ---- 이름 재료 (generate_data.ps1과 같음) · 이름은 겹치지 않게 ----
$surnames = @('김','이','박','최','정','강','조','윤','장','임','한','오','서','신','권','황','안','송','류','홍')
$surW     = @( 21, 15,  8,  5,  4,2.5,2.1,  2,  2,1.7,1.5,1.5,1.5,1.4,1.3,1.3,1.3,1.2,1.1,  1)
$given    = @('민','서','지','현','준','우','예','도','하','윤','수','진','영','은','성',
              '재','유','시','채','태','소','연','호','혜','경','동','상','미','정','희')
$used = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($d in $doctors) { [void]$used.Add($d.doctor_name) }
function NewName {
    do {
        do { $a = Pick $given; $b = Pick $given } while ($a -eq $b)
        $n = (PickW $surnames $surW) + $a + $b
    } while (-not $script:used.Add($n))
    $n
}

# ---- 역할 ----
$roles = @(
    @{ Id = 1; Code = 'DOC'; Name = '의사' },
    @{ Id = 2; Code = 'NUR'; Name = '간호사' },
    @{ Id = 3; Code = 'ADM'; Name = '원무' },
    @{ Id = 4; Code = 'PHA'; Name = '약제' },
    @{ Id = 5; Code = 'ITS'; Name = '전산' }
)

# ---- 메뉴 (Parent = 상위 메뉴 번호, 빈칸 = 맨 위 메뉴) ----
$menus = @(
    @{ Id = 100; Name = '외래';           Parent = ''; Ord = 1 },
    @{ Id = 101; Name = '접수';           Parent = 100; Ord = 1 },
    @{ Id = 102; Name = '진료기록';       Parent = 100; Ord = 2 },
    @{ Id = 103; Name = '처방';           Parent = 100; Ord = 3 },
    @{ Id = 104; Name = '외래 일정';      Parent = 100; Ord = 4 },
    @{ Id = 200; Name = '원무';           Parent = ''; Ord = 2 },
    @{ Id = 201; Name = '수납';           Parent = 200; Ord = 1 },
    @{ Id = 202; Name = '미수납 관리';    Parent = 200; Ord = 2 },
    @{ Id = 203; Name = '환자 등록';      Parent = 200; Ord = 3 },
    @{ Id = 300; Name = '약제';           Parent = ''; Ord = 3 },
    @{ Id = 301; Name = '처방 확인';      Parent = 300; Ord = 1 },
    @{ Id = 302; Name = '조제 내역';      Parent = 300; Ord = 2 },
    @{ Id = 400; Name = '통계';           Parent = ''; Ord = 4 },
    @{ Id = 401; Name = '접수 통계';      Parent = 400; Ord = 1 },
    @{ Id = 402; Name = '수납 통계';      Parent = 400; Ord = 2 },
    @{ Id = 403; Name = '대기 시간 통계'; Parent = 400; Ord = 3 },
    @{ Id = 500; Name = '시스템 관리';    Parent = ''; Ord = 5 },
    @{ Id = 501; Name = '사용자 관리';    Parent = 500; Ord = 1 },
    @{ Id = 502; Name = '메뉴 권한 관리'; Parent = 500; Ord = 2 },
    @{ Id = 503; Name = 'SMS 발송내역';   Parent = 500; Ord = 3 },
    @{ Id = 504; Name = '공지사항 관리';  Parent = 500; Ord = 4 }       # 일부러 어느 역할에도 안 줌
)

# ---- 역할-메뉴 권한 (행이 있으면 볼 수 있음 · can_write Y = 고치기도 가능) ----
# 권한은 맨 아래 메뉴에만 줌 (위 메뉴 100·200… 은 묶음 이름)
$perms = @(
    @(1,101,'N'), @(1,102,'Y'), @(1,103,'Y'), @(1,104,'N'), @(1,301,'N'), @(1,401,'N'), @(1,403,'N'),
    @(2,101,'N'), @(2,102,'N'), @(2,104,'N'), @(2,403,'N'),
    @(3,101,'Y'), @(3,104,'N'), @(3,201,'Y'), @(3,202,'Y'), @(3,203,'Y'), @(3,401,'N'), @(3,402,'N'),
    @(4,103,'N'), @(4,301,'Y'), @(4,302,'Y'),
    @(5,401,'N'), @(5,402,'N'), @(5,403,'N'), @(5,501,'Y'), @(5,502,'Y'), @(5,503,'N')
)

# ---- 직원 ----
$staff = New-Object System.Collections.Generic.List[object]
$sid = 20000
foreach ($d in ($doctors | Sort-Object { [int]$_.doctor_id })) {                  # 의사 = doctor 테이블과 같은 사람
    $sid++
    $staff.Add(@{ Id = $sid; Name = $d.doctor_name; Role = 1; Dept = $d.dept_id; Doc = $d.doctor_id
                  Hire = $d.hire_date; Status = '재직' })
}
function AddStaff($role, $dept) {
    $script:sid++
    $script:staff.Add(@{ Id = $script:sid; Name = (NewName); Role = $role; Dept = $dept; Doc = ''
                         Hire = (FD ([datetime]'2008-03-01').AddDays((RInt 0 6450))); Status = '재직' })
}
foreach ($d in $depts) { AddStaff 2 $d.dept_id; AddStaff 2 $d.dept_id }        # 간호사: 과마다 2명
1..8 | ForEach-Object { AddStaff 3 '' }                                         # 원무 (과 없음)
1..5 | ForEach-Object { AddStaff 4 '' }                                         # 약제 (과 없음)
1..4 | ForEach-Object { AddStaff 5 '' }                                         # 전산 (과 없음)

# 의사가 아닌 직원 중 3명은 퇴사
$others = @($staff | Where-Object { $_.Role -ne 1 })
$left = 0
while ($left -lt 3) {
    $s = Pick $others
    if ($s.Status -eq '재직') { $s.Status = '퇴사'; $left++ }
}

# ---- CSV 저장 ----
function WriteCsv($name, $header, $rows) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append($header + "`n")
    foreach ($r in $rows) { [void]$sb.Append(($r -join ',') + "`n") }
    [IO.File]::WriteAllText((Join-Path $DataDir "$name.csv"), $sb.ToString(), $script:utf8)
}

WriteCsv 'role' 'role_id,role_code,role_name' ($roles | ForEach-Object { ,@($_.Id, $_.Code, $_.Name) })
WriteCsv 'menu' 'menu_id,menu_name,parent_id,sort_order' ($menus | ForEach-Object { ,@($_.Id, $_.Name, $_.Parent, $_.Ord) })
WriteCsv 'role_menu' 'role_id,menu_id,can_write' ($perms | ForEach-Object { ,@($_[0], $_[1], $_[2]) })
WriteCsv 'staff' 'staff_id,staff_name,role_id,dept_id,doctor_id,hire_date,status' ($staff | ForEach-Object { ,@($_.Id, $_.Name, $_.Role, $_.Dept, $_.Doc, $_.Hire, $_.Status) })

# ---- 검산용 통계 ----
Write-Host ("role {0} / staff {1} (퇴사 {2}) / menu {3} / role_menu {4}" -f `
    $roles.Count, $staff.Count, @($staff | Where-Object { $_.Status -eq '퇴사' }).Count, $menus.Count, $perms.Count)
Write-Host '역할별 직원:'
$staff | Group-Object { $_.Role } | Sort-Object Name | ForEach-Object { Write-Host ("  {0} {1}" -f $_.Name, $_.Count) }
