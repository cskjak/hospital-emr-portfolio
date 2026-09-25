# ============================================================
# 가상 병원 외래 데이터 생성기 (2026-01-02 ~ 2026-06-30)
# - 모든 이름·번호는 무작위로 지어낸 값입니다. 실제 데이터 아님.
# - 시드 고정 → 몇 번을 돌려도 같은 데이터가 나옵니다.
# 사용법: powershell -File generate_data.ps1 -OutDir <출력폴더>
# ============================================================
param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [int]$PatientCount = 10000
)
$ErrorActionPreference = 'Stop'

# ---- 안전장치: 기존 폴더는 절대 덮어쓰지 않음 ----
Write-Host "출력 경로: $OutDir"
if (Test-Path $OutDir) { throw "이미 존재하는 경로입니다. 덮어쓰지 않고 중단합니다: $OutDir" }

$rng  = New-Object System.Random 20260926
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
function F([datetime]$dt) { $dt.ToString('yyyy-MM-dd HH:mm:ss', $script:inv) }
function FD([datetime]$dt) { $dt.ToString('yyyy-MM-dd', $script:inv) }

# ---- 기간 · 공휴일 (평일에 걸린 것만) ----
$Start = [datetime]'2026-01-02'
$End   = [datetime]'2026-06-30'
$Holi  = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($h in '2026-01-01', '2026-02-16', '2026-02-17', '2026-02-18', '2026-03-02',
               '2026-05-05', '2026-05-25', '2026-06-03') { [void]$Holi.Add($h) }

# ---- 이름 재료 ----
$surnames = @('김','이','박','최','정','강','조','윤','장','임','한','오','서','신','권','황','안','송','류','홍')
$surW     = @( 21, 15,  8,  5,  4,2.5,2.1,  2,  2,1.7,1.5,1.5,1.5,1.4,1.3,1.3,1.3,1.2,1.1,  1)
$given    = @('민','서','지','현','준','우','예','도','하','윤','수','진','영','은','성',
              '재','유','시','채','태','소','연','호','혜','경','동','상','미','정','희')
function NewName {
    do { $a = Pick $given; $b = Pick $given } while ($a -eq $b)
    (PickW $surnames $surW) + $a + $b
}

# ---- 진료과 (W = 환자 비중, Min/Max = 주 연령대) ----
$depts = @(
    @{ Id = 1; Code = 'GI'; Name = '소화기내과';   Floor = 3; W = 18; Min = 30; Max = 80 },
    @{ Id = 2; Code = 'CV'; Name = '순환기내과';   Floor = 3; W = 14; Min = 45; Max = 88 },
    @{ Id = 3; Code = 'EN'; Name = '내분비내과';   Floor = 3; W = 12; Min = 35; Max = 80 },
    @{ Id = 4; Code = 'OS'; Name = '정형외과';     Floor = 2; W = 16; Min = 20; Max = 85 },
    @{ Id = 5; Code = 'NR'; Name = '신경과';       Floor = 4; W = 10; Min = 40; Max = 88 },
    @{ Id = 6; Code = 'PD'; Name = '소아청소년과'; Floor = 1; W = 10; Min =  1; Max = 17 },
    @{ Id = 7; Code = 'DM'; Name = '피부과';       Floor = 2; W = 10; Min = 12; Max = 70 },
    @{ Id = 8; Code = 'OP'; Name = '안과';         Floor = 4; W = 10; Min = 40; Max = 88 }
)
$deptW = @($depts | ForEach-Object { $_.W })

# ---- 의사: 과마다 3명, 각자 주 2회 외래 (과 안에서 요일·오전오후 안 겹침) ----
$wdName    = @{ 1 = '월'; 2 = '화'; 3 = '수'; 4 = '목'; 5 = '금' }
$doctors   = New-Object System.Collections.Generic.List[object]
$docByDept = @{}
$docId = 1001
foreach ($d in $depts) {
    $slots = New-Object System.Collections.Generic.List[object]
    foreach ($wd in 1..5) { foreach ($s in 'AM', 'PM') { $slots.Add(@{ Wd = $wd; Ses = $s }) } }
    for ($i = $slots.Count - 1; $i -gt 0; $i--) {                     # 섞기
        $j = $rng.Next(0, $i + 1); $tmp = $slots[$i]; $slots[$i] = $slots[$j]; $slots[$j] = $tmp
    }
    $docByDept[$d.Id] = New-Object System.Collections.Generic.List[object]
    $positions = @('교수', '부교수', '조교수')
    $hireRange = @(@(2004, 2010), @(2011, 2016), @(2017, 2023))
    for ($k = 0; $k -lt 3; $k++) {
        $hr   = $hireRange[$k]
        $y    = RInt ($hr[0]) ($hr[1])
        $hire = [datetime]("{0}-{1}-01" -f $y, (Pick @('03', '09')))
        $doc  = @{ Id = $docId; Dept = $d; Name = (NewName); Pos = $positions[$k]; Hire = $hire
                   Sessions = @($slots[2 * $k], $slots[2 * $k + 1]) }
        $doctors.Add($doc); $docByDept[$d.Id].Add($doc); $docId++
    }
}

# d 날짜부터 그 의사의 다음 외래(공휴일 제외, 정원 안 찬 세션)를 찾음
$Cap  = 18                                                             # 세션당 최대 환자 수
$load = @{}
function NextSession($doc, [datetime]$d) {
    for ($i = 0; $i -lt 60; $i++) {
        $day = $d.AddDays($i)
        if ($day -gt $script:End) { return $null }
        $wd = [int]$day.DayOfWeek
        if ($wd -lt 1 -or $wd -gt 5 -or $script:Holi.Contains((FD $day))) { continue }
        $hits = New-Object System.Collections.Generic.List[object]
        foreach ($s in $doc.Sessions) {
            $k = '{0}|{1}|{2}' -f $doc.Id, (FD $day), $s.Ses
            if ($s.Wd -eq $wd -and $script:load[$k] -lt $script:Cap) { $hits.Add($s) }
        }
        if ($hits.Count -gt 0) {
            $ses = (Pick $hits).Ses
            $k = '{0}|{1}|{2}' -f $doc.Id, (FD $day), $ses
            $script:load[$k] = [int]$script:load[$k] + 1
            return @{ Date = $day; Ses = $ses }
        }
    }
    return $null
}
# 도착(접수) 시각: 오전 08:20~, 오후 12:50~ / 두 난수 중 작은 값 → 이른 시간에 몰림
function Arrival([datetime]$date, [string]$ses) {
    $base = if ($ses -eq 'AM') { $date.AddHours(8).AddMinutes(20) } else { $date.AddHours(12).AddMinutes(50) }
    $off  = [math]::Min((RInt 0 180), (RInt 0 180))
    $base.AddMinutes($off).AddSeconds((RInt 0 59))
}

# ---- 환자 + 방문 일정 ----
# 일부 환자는 2025년부터 다니던 기존 환자 → 데이터 기간 안에서는 재진만 보임
$patients = New-Object System.Collections.Generic.List[object]
$visits   = New-Object System.Collections.Generic.List[object]
for ($p = 0; $p -lt $PatientCount; $p++) {
    $d     = PickW $depts $deptW
    $age   = RInt $d.Min $d.Max
    $birth = ([datetime]'2026-01-01').AddYears(-$age).AddDays(-(RInt 0 364))
    $pat   = @{ Tmp = $p; Name = (NewName); Gender = (Pick @('M', 'F')); Birth = $birth; Age = $age
                Phone = ('010-****-{0:D4}' -f (RInt 0 9999)); Visits = New-Object System.Collections.Generic.List[object] }

    $plans = New-Object System.Collections.Generic.List[object]
    $plans.Add(@{ Dept = $d; Doc = (Pick $docByDept[$d.Id]); Count = (PickW @(1,2,3,4,5,6) @(35,25,18,12,6,4))
                  From = $Start.AddDays((RInt -365 178)) })
    if ((RInt 1 100) -le 20) {                                            # 20%는 다른 과도 다님
        $cand = @($depts | Where-Object { $_.Id -ne $d.Id -and $age -ge $_.Min -and $age -le $_.Max })
        if ($cand.Count -gt 0) {
            $d2 = Pick $cand
            $plans.Add(@{ Dept = $d2; Doc = (Pick $docByDept[$d2.Id]); Count = (PickW @(1,2,3) @(60,30,10))
                          From = $Start.AddDays((RInt -180 178)) })
        }
    }
    foreach ($pl in $plans) {
        $cur = $pl.From
        for ($i = 0; $i -lt $pl.Count; $i++) {
            $ns = NextSession $pl.Doc $cur
            if ($null -eq $ns) { break }
            $v = @{ Pat = $pat; Dept = $pl.Dept; Doc = $pl.Doc; Date = $ns.Date; Ses = $ns.Ses
                    Arr = (Arrival $ns.Date $ns.Ses); Cancel = $false; InData = ($ns.Date -ge $Start) }
            $pat.Visits.Add($v); $visits.Add($v)
            $cur = $ns.Date.AddDays((RInt 14 56))                         # 2~8주 뒤 재진
        }
    }
    $patients.Add($pat)
}

# ---- 데이터 기간 안의 방문만 남김 · 4% 접수취소 ----
$recs = @($visits | Where-Object { $_.InData } | Sort-Object { $_.Arr })
foreach ($v in $recs) { if ((RInt 1 100) -le 4) { $v.Cancel = $true } }

# ---- 초진/재진: 그 과에서 완료된 진료가 전에 있었으면 재진 ----
$byPD = @{}
foreach ($v in ($visits | Sort-Object { $_.Arr })) {
    $key = "$($v.Pat.Tmp)-$($v.Dept.Id)"
    $v.Type = if ($byPD.ContainsKey($key)) { '재진' } else { '초진' }
    if (-not $v.Cancel) { $byPD[$key] = $true }
}

# ---- 환자 등록일시 · 차트번호 ----
$kept = @($patients | Where-Object { @($_.Visits | Where-Object { $_.InData }).Count -gt 0 })
foreach ($pat in $kept) {
    $first = ($pat.Visits | Sort-Object { $_.Arr } | Select-Object -First 1).Arr
    $reg   = $first.AddMinutes(-(RInt 5 20))
    if ($pat.Age -ge 20 -and (RInt 1 100) -le 30) { $reg = $reg.AddDays(-(RInt 30 3000)) }  # 오래전 다른 과로 등록
    $pat.Reg = $reg
}
$kept = @($kept | Sort-Object { $_.Reg })
for ($i = 0; $i -lt $kept.Count; $i++) { $kept[$i].Id = 10000001 + $i }

# ---- 접수번호 ----
for ($i = 0; $i -lt $recs.Count; $i++) { $recs[$i].Id = $i + 1 }

# ---- 진료: 의사별·세션별로 도착순 줄 세우기 → 대기시간이 자연스럽게 생김 ----
$groups = @{}
foreach ($v in $recs) {
    if ($v.Cancel) { continue }
    $key = '{0}|{1}|{2}' -f $v.Doc.Id, (FD $v.Date), $v.Ses
    if (-not $groups.ContainsKey($key)) { $groups[$key] = New-Object System.Collections.Generic.List[object] }
    $groups[$key].Add($v)
}
foreach ($key in ($groups.Keys | Sort-Object)) {
    $q = $groups[$key]
    $sesStart = if ($q[0].Ses -eq 'AM') { $q[0].Date.AddHours(9) } else { $q[0].Date.AddHours(13).AddMinutes(30) }
    $prevEnd  = $sesStart
    foreach ($v in $q) {
        $ready = $v.Arr.AddMinutes((RInt 3 10))                          # 접수 후 진료실 앞까지
        $st = $ready
        $gap = $prevEnd.AddSeconds((RInt 0 90))
        if ($gap -gt $st) { $st = $gap }
        if ($sesStart -gt $st) { $st = $sesStart }
        $dur = if ($v.Type -eq '초진') { RInt 480 900 } else { RInt 180 480 }
        $v.TStart = $st; $v.TEnd = $st.AddSeconds($dur); $prevEnd = $v.TEnd
    }
}

# ---- 수납: 2%는 미수납으로 남김 ----
$pays = New-Object System.Collections.Generic.List[object]
foreach ($v in $recs) {
    if ($v.Cancel) { continue }
    if ((RInt 1 100) -le 2) { continue }
    $total = if ($v.Type -eq '초진') { (RInt 2800 4500) * 10 } else { (RInt 1800 3000) * 10 }
    if ((RInt 1 100) -le 35) { $total += (RInt 2000 25000) * 10 }            # 검사 추가
    $patAmt = [int]([math]::Floor($total * 0.6 / 100) * 100)          # 본인부담 60%, 100원 미만 절사
    $pays.Add(@{ Rec = $v; PaidAt = $v.TEnd.AddSeconds((RInt 120 1500)); Total = $total
                 Ins = $total - $patAmt; PatAmt = $patAmt; Method = (PickW @('카드','간편결제','현금') @(78,15,7)) })
}
$pays = @($pays | Sort-Object { $_.PaidAt })

# ---- CSV 저장 ----
New-Item -ItemType Directory -Path $OutDir | Out-Null
function WriteCsv($name, $header, $rows) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append($header + "`n")
    foreach ($r in $rows) { [void]$sb.Append(($r -join ',') + "`n") }
    [IO.File]::WriteAllText((Join-Path $OutDir "$name.csv"), $sb.ToString(), $script:utf8)
}

WriteCsv 'department' 'dept_id,dept_code,dept_name,floor' ($depts | ForEach-Object { ,@($_.Id, $_.Code, $_.Name, $_.Floor) })
WriteCsv 'doctor' 'doctor_id,doctor_name,dept_id,position,hire_date' ($doctors | ForEach-Object { ,@($_.Id, $_.Name, $_.Dept.Id, $_.Pos, (FD $_.Hire)) })
$schedRows = foreach ($doc in $doctors) { foreach ($s in ($doc.Sessions | Sort-Object { $_.Wd * 10 + ($(if ($_.Ses -eq 'AM') { 0 } else { 1 })) })) { ,@($doc.Id, $wdName[$s.Wd], $s.Ses) } }
WriteCsv 'doctor_schedule' 'doctor_id,weekday,session_type' $schedRows
WriteCsv 'patient' 'patient_id,patient_name,gender,birth_date,phone,registered_at' ($kept | ForEach-Object { ,@($_.Id, $_.Name, $_.Gender, (FD $_.Birth), $_.Phone, (F $_.Reg)) })
WriteCsv 'reception' 'reception_id,patient_id,dept_id,doctor_id,reception_at,visit_type,status' ($recs | ForEach-Object { ,@($_.Id, $_.Pat.Id, $_.Dept.Id, $_.Doc.Id, (F $_.Arr), $_.Type, $(if ($_.Cancel) { '취소' } else { '정상' })) })
$tid = 0
$treatRows = foreach ($v in $recs) { if (-not $v.Cancel) { $tid++; ,@($tid, $v.Id, (F $v.TStart), (F $v.TEnd)) } }
WriteCsv 'treatment' 'treatment_id,reception_id,start_at,end_at' $treatRows
$pid2 = 0
$payRows = foreach ($py in $pays) { $pid2++; ,@($pid2, $py.Rec.Id, (F $py.PaidAt), $py.Total, $py.Ins, $py.PatAmt, $py.Method) }
WriteCsv 'payment' 'payment_id,reception_id,paid_at,total_amount,insurance_amount,patient_amount,method' $payRows

# ---- 검산용 통계 ----
$done   = @($recs | Where-Object { -not $_.Cancel })
$waits  = @($done | ForEach-Object { ($_.TStart - $_.Arr).TotalMinutes })
$sess   = $groups.Count
Write-Host ("patient {0} / doctor {1} / reception {2} (취소 {3}) / treatment {4} / payment {5} (미수납 {6})" -f `
    $kept.Count, $doctors.Count, $recs.Count, ($recs.Count - $done.Count), $done.Count, $pays.Count, ($done.Count - $pays.Count))
Write-Host ("초진 비율 {0:P1} / 대기(분) 평균 {1:N1} 최대 {2:N0} / 세션당 평균 {3:N1}명" -f `
    (@($recs | Where-Object { $_.Type -eq '초진' }).Count / $recs.Count), ($waits | Measure-Object -Average).Average, ($waits | Measure-Object -Maximum).Maximum, ($done.Count / $sess))
Write-Host '월별 접수:'
$recs | Group-Object { $_.Arr.ToString('yyyy-MM') } | Sort-Object Name | ForEach-Object { Write-Host ("  {0} {1}" -f $_.Name, $_.Count) }
Write-Host '과별 접수:'
$recs | Group-Object { $_.Dept.Name } | Sort-Object Count -Descending | ForEach-Object { Write-Host ("  {0} {1}" -f $_.Name, $_.Count) }
Write-Host ("등록일 2026년 이전 환자: {0}" -f @($kept | Where-Object { $_.Reg -lt $Start }).Count)
