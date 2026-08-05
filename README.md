# 치과의사 보수교육 일정 조회

KDA(대한치과의사협회) 보수교육 일정을 빠르게 조회·필터링하는 정적 웹페이지.

**▶ 사이트: https://jdent0228.github.io/bosu/**

## 동작 방식 (완전 자동)
1. GitHub Actions가 **매일 05:00 KST** `refresh.ps1` 실행
   - 오늘 기준 **앞 6개월만** 재크롤 (약 30초), 과거 데이터는 보존·병합
2. 변경분(`data.js`/`data.json`)을 자동 커밋
3. GitHub Pages가 자동 재배포 → 사이트가 항상 최신

수동 갱신: **Actions 탭 → "보수교육 일정 갱신" → Run workflow**

## 파일 구성
| 파일 | 역할 |
|------|------|
| `index.html` | 조회 UI (월 스와이프 · 지역/점수 상세검색 · 표) |
| `data.js` / `data.json` | 크롤된 일정 데이터 (자동 갱신 대상) |
| `refresh.ps1` | 증분 갱신 (앞 6개월 재크롤 + 병합) — Actions가 매일 실행 |
| `crawl.ps1` | 전체 재수집 (연도 지정, 최초 시드/복구용) |
| `.github/workflows/refresh-schedule.yml` | 자동 갱신 스케줄 |

## 데이터/점수 규칙
- 공식 사이트 로직과 동일: **보수교육점수 = jumsu + reqjumsu**, **필수교육점수 = reqjumsu**
  (plantype=8이면 보수점수 없음, 필수 = jumsu)
- 필수교육점수가 있는 일정은 점수 옆 ⓘ에 마우스오버로 표시
- 각 일정 클릭 → 상세 + KDA 공식 페이지 링크(`scheduleInfo.kda?planno=`)

## 로컬 개발
```bash
git clone https://github.com/jdent0228/bosu.git
cd bosu
# 정적 파일이라 아무 서버나 가능. 예:
python3 -m http.server 4321      # http://localhost:4321
# 또는 index.html 더블클릭 (data.js 방식이라 file:// 로도 동작)
```
데이터 수동 갱신(선택): `pwsh ./refresh.ps1 -Months 6` (맥은 `brew install --cask powershell`)

## 참고
- 예전 비공개 저장소 `kda-bosu`는 이 저장소로 **이전 완료** (그쪽 자동 갱신은 중지됨)
