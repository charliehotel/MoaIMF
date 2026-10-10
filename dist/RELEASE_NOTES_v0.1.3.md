# MoaIMF 0.1.3

## 한국어

- 감시 폴더별 `지금 검사`가 해당 폴더를 검사하고 정규화까지 수행합니다.
- 검사 및 정규화 중 현재 단계, 처리 건수, 진행률, 현재 파일을 표시합니다.
- 최근 기록에서 저장된 전체 이벤트 수와 현재 표시 중인 수를 확인할 수 있습니다.
- 대량 기록을 청크 단위로 읽어 불필요한 메모리 사용을 줄이고, 각 결과에 개별 발생 시각을 기록합니다.
- 스캔 중 진행 상황을 주기적으로 전달하고, 완료된 파일 기준으로 정규화 진행률을 계산합니다.

## English

- “Scan Now” on a watched folder now scans and normalizes that folder.
- Scan and normalization progress shows the current phase, completed item count, percentage, and current file.
- History shows the total number of saved events alongside the number currently displayed.
- Large history files are read in chunks to reduce unnecessary memory use, and each result receives its own timestamp.
- Scanning reports progress periodically, and normalization progress counts completed files.
