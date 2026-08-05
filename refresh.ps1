# KDA 보수교육 일정 증분 갱신기 (앞 N개월만 재크롤 + 기존 데이터 병합)
#  - 오늘(KST) 기준 현재 월부터 앞 N개월(기본 6)만 다시 크롤링
#  - 그 외(과거 및 그 이후) 데이터는 기존 data.json 을 그대로 보존
#  - GitHub Actions(pwsh) / 로컬(Windows PowerShell) 모두 동작
# 사용법:  powershell -ExecutionPolicy Bypass -File refresh.ps1 [-Months 6]

param([int]$Months = 6)

$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$uri = 'https://edu.kda.or.kr/user/schedule/selectScheduleList.kda'

# ---------- 1. 기존 데이터 로드 (DB) ----------
$dataPath = Join-Path $dir 'data.json'
$existing = @()
if (Test-Path $dataPath) {
  $j = [System.IO.File]::ReadAllText($dataPath) | ConvertFrom-Json
  if ($j.items) { $existing = @($j.items) }
}

# ---------- 2. 오늘(KST) 기준 앞 N개월 윈도우 ----------
$today = (Get-Date).ToUniversalTime().AddHours(9)   # KST
$curY = $today.Year; $curM = $today.Month
$window = @()
for ($i = 0; $i -lt $Months; $i++) {
  $idx = $curM - 1 + $i
  $window += @{ y = [int]($curY + [math]::Floor($idx / 12)); m = [int](($idx % 12) + 1) }
}
$winKeys = $window | ForEach-Object { "$($_.y)-$($_.m)" }
Write-Host "갱신 윈도우: $($winKeys -join ', ')"

# ---------- 3. 윈도우 재크롤 ----------
$fresh = [System.Collections.Generic.List[object]]::new()
foreach ($w in $window) {
  $mm = '{0:D2}' -f $w.m; $page = 1
  while ($true) {
    $body = "pageIndex=$page&srchArea=&srchTitle=&srchOrgName=&planYear=$($w.y)&planMonth=$mm&passNo=3"
    $x = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 30
    if (-not $x.scheduleList -or $x.scheduleList.Count -eq 0) { break }
    foreach ($s in $x.scheduleList) {
      $fy = [string]$s.frymd; $ty = [string]$s.toymd
      $dateFmt = if ($fy.Length -eq 8) { "{0}-{1}-{2}" -f $fy.Substring(0,4),$fy.Substring(4,2),$fy.Substring(6,2) } else { $fy }
      $endFmt  = if ($ty.Length -eq 8) { "{0}-{1}-{2}" -f $ty.Substring(0,4),$ty.Substring(4,2),$ty.Substring(6,2) } else { $ty }
      $ju = [int]$s.jumsu; $rq = [int]$s.reqjumsu; $pt = [int]$s.plantype
      if ($pt -eq 8) { $bosu = $null; $reqScore = $ju } else { $bosu = $ju + $rq; $reqScore = $rq }
      $fresh.Add([ordered]@{
        id=$s.planno; title=($s.lectitle).Trim(); org=$s.gigwanname; region=$s.branchname
        score=$bosu; reqScore=$reqScore; plantype=$pt; place=$s.lecplace; lecturer=$s.lecturer
        year=[int]$fy.Substring(0,4); month=[int]$fy.Substring(4,2); date=$dateFmt; endDate=$endFmt
        start=$s.frtime; end=$s.totime; cost=($s.costbyperson).Trim(); capacity=$s.inwon
        contact=$s.contact; regpage=$s.regpage; note=($s.note).Trim(); groupSeq=$s.plangroupseq
      })
    }
    if ($page * 10 -ge $x.totalCount) { break }
    $page++
  }
  Write-Host "  $($w.y)-$mm 재크롤 (누적 $($fresh.Count)건)"
}

# ---------- 4. 병합: 기존에서 윈도우 월 제거 후 새 데이터 추가 ----------
$kept = $existing | Where-Object { $winKeys -notcontains "$($_.year)-$($_.month)" }
$merged = @($kept) + @($fresh) | Sort-Object date, start

# ---------- 5. 연도 목록 (데이터 + 윈도우 + 내년 버퍼) ----------
$yset = [System.Collections.Generic.SortedSet[int]]::new()
$merged | ForEach-Object { [void]$yset.Add([int]$_.year) }
$window | ForEach-Object { [void]$yset.Add([int]$_.y) }
[void]$yset.Add([int]$curY); [void]$yset.Add([int]($curY + 1))
$years = @($yset)

# ---------- 6. 저장 ----------
$payload = [ordered]@{
  years       = $years
  generatedAt = $today.ToString('yyyy-MM-dd HH:mm')
  count       = $merged.Count
  items       = $merged
}
$json = $payload | ConvertTo-Json -Depth 5
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $dir 'data.js'), "window.KDA_DATA = $json;", $enc)
[System.IO.File]::WriteAllText($dataPath, $json, $enc)
Write-Host "완료: 총 $($merged.Count)건 (갱신 $($fresh.Count)건, 보존 $(@($kept).Count)건) · 연도 $($years -join ',')"
