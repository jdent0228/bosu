# KDA 보수교육 일정 크롤러 (다년도)
# 사용법:  powershell -ExecutionPolicy Bypass -File crawl.ps1
#          powershell -ExecutionPolicy Bypass -File crawl.ps1 -Years 2025,2026,2027
# 결과:  같은 폴더의 data.js / data.json 갱신

param([int[]]$Years = @(2025, 2026, 2027))

$uri = 'https://edu.kda.or.kr/user/schedule/selectScheduleList.kda'
$out = [System.Collections.Generic.List[object]]::new()

foreach ($Year in $Years) {
  foreach ($m in 1..12) {
    $mm = '{0:D2}' -f $m
    $page = 1
    while ($true) {
      $body = "pageIndex=$page&srchArea=&srchTitle=&srchOrgName=&planYear=$Year&planMonth=$mm&passNo=3"
      try {
        $x = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 30
      } catch {
        Write-Warning "요청 실패 $Year-$mm p$page : $($_.Exception.Message)"; break
      }
      if (-not $x.scheduleList -or $x.scheduleList.Count -eq 0) { break }
      foreach ($s in $x.scheduleList) {
        $fy = [string]$s.frymd; $ty = [string]$s.toymd
        $dateFmt = if ($fy.Length -eq 8) { "{0}-{1}-{2}" -f $fy.Substring(0,4),$fy.Substring(4,2),$fy.Substring(6,2) } else { $fy }
        $endFmt  = if ($ty.Length -eq 8) { "{0}-{1}-{2}" -f $ty.Substring(0,4),$ty.Substring(4,2),$ty.Substring(6,2) } else { $ty }

        # 공식 사이트 로직: 보수교육점수 = jumsu + reqjumsu, 필수교육점수 = reqjumsu
        # (plantype=8 인 경우: 보수 없음, 필수 = jumsu)
        $ju = [int]$s.jumsu; $rq = [int]$s.reqjumsu; $pt = [int]$s.plantype
        if ($pt -eq 8) { $bosu = $null; $reqScore = $ju }
        else           { $bosu = $ju + $rq; $reqScore = $rq }

        $out.Add([ordered]@{
          id       = $s.planno
          title    = ($s.lectitle).Trim()
          org      = $s.gigwanname
          region   = $s.branchname
          score    = $bosu       # 보수교육점수
          reqScore = $reqScore   # 필수교육점수
          plantype = $pt
          place    = $s.lecplace
          lecturer = $s.lecturer
          year     = [int]$fy.Substring(0,4)
          month    = [int]$fy.Substring(4,2)
          date     = $dateFmt
          endDate  = $endFmt
          start    = $s.frtime
          end      = $s.totime
          cost     = ($s.costbyperson).Trim()
          capacity = $s.inwon
          contact  = $s.contact
          regpage  = $s.regpage
          note     = ($s.note).Trim()
          groupSeq = $s.plangroupseq
        })
      }
      if ($page * 10 -ge $x.totalCount) { break }
      $page++
    }
    Write-Host "$Year-$mm 완료 (누적 $($out.Count)건)"
  }
}

$payload = [ordered]@{
  years       = $Years
  generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  count       = $out.Count
  items       = $out
}
$json = $payload | ConvertTo-Json -Depth 5
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'data.js'), "window.KDA_DATA = $json;", $enc)
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'data.json'), $json, $enc)
Write-Host "완료: 총 $($out.Count)건 (연도: $($Years -join ', '))"
