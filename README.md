# Planet Diary

365일 동안 태양계를 여행한다는 콘셉트의 Flutter 웹 일기 앱입니다. 사용자는 여행 시작일을 설정하고, 날짜별 일기와 감정, 사진, 행성별 퀘스트를 기록하면서 리캡과 업적을 통해 자신의 기록 흐름을 확인할 수 있습니다.

배포 URL: https://mink20001203-hub.github.io/planet_diary/

## 핵심 기능

- 365일 태양계 여행 콘셉트: 수성부터 해왕성까지 날짜에 따라 행성 구간이 바뀝니다.
- CustomPainter 기반 태양계 맵: 추가 패키지 없이 타원 궤도, 깊이감, 행성 셰이딩, 토성 고리, 우주인 위치를 직접 계산해 표현했습니다.
- 일기 작성/조회/수정 분리: 새 기록은 작성 화면으로, 기존 기록은 조회 화면으로 먼저 진입한 뒤 수정할 수 있습니다.
- 미래 날짜 작성 제한: 오늘 이후 날짜는 일기를 작성할 수 없도록 막았습니다.
- 월간/연간 리캡: 기록 일수, 감정 분포, 퀘스트 완료율, 사진 하이라이트, 행성별 기록을 요약합니다.
- 업적/배지 시스템: 첫 일기, 7일 연속 기록, 사진 10장, 퀘스트 30개 완료 등 성장 요소를 제공합니다.
- 백업/복원: Hive에 저장된 일기 데이터를 JSON으로 내보내고 다시 복원할 수 있습니다.
- GitHub Pages 자동 배포: `main` 브랜치 push 시 GitHub Actions로 웹 빌드와 배포가 실행됩니다.

## 기술 스택

- Flutter 3.38.3
- Dart
- Riverpod: 앱 상태 관리
- GoRouter: 화면 라우팅
- Hive / Hive Flutter: 로컬 데이터 저장
- Table Calendar: 월간 캘린더 UI
- Image Picker: 사진 선택
- Google Fonts: Space Mono, Noto Sans KR 기반 타이포그래피
- GitHub Actions + GitHub Pages: 웹 자동 배포

## 주요 화면

스크린샷은 `docs/screenshots/` 또는 포트폴리오 자료에 추가해서 연결하면 됩니다.

- 태양계 맵: 3D 느낌의 타원 궤도와 현재 여행 위치 표시
- 캘린더: 날짜별 기록, 사진, 퀘스트 상태 표시
- 일기 조회/수정: 기존 기록 조회 후 수정 가능
- 월간 리캡: 해당 월의 기록 요약
- 연간 리캡: 전체 365일 여행 기록 요약
- 설정: 여행 시작일 변경, 백업/복원

## 문제 해결 사례

- GitHub Pages 404 문제: 저장소가 private이면 Pages가 비활성화된다는 점을 확인하고 public 전환 및 Pages 설정이 필요함을 정리했습니다.
- Web build 실패: `diary_entry.g.dart` 누락으로 Hive Adapter가 생성되지 않아 빌드가 실패한 문제를 파악하고 생성 파일을 반영했습니다.
- 한글 깨짐 문제: Space Mono가 한글을 지원하지 않아 한글 텍스트에는 Noto Sans KR 또는 시스템 폰트를 적용했습니다.
- 중복 XP 획득 문제: 기존 일기 수정 시 신규 작성으로 처리되어 XP가 반복 지급되던 문제를 `existing == null` 기준으로 방지했습니다.
- 날짜 불일치 문제: 하드코딩된 시작일을 제거하고 Hive settings 기반 사용자 시작일로 tripDay와 실제 날짜를 계산하도록 수정했습니다.
- 웹 데이터 보존: Hive가 웹에서 IndexedDB 기반으로 동작하도록 구성하고, 백업/복원 기능을 추가해 브라우저 데이터 삭제에 대비했습니다.

## AI 활용 방식

- 기능 요구사항을 자연어로 정리하고 ChatGPT/Codex를 통해 구현 단위를 분해했습니다.
- 오류 로그와 화면 캡처를 기반으로 원인을 추론하고 수정 방향을 결정했습니다.
- 반복 작업인 라우트 추가, Provider 확장, UI 섹션 구성, GitHub Actions 배포 설정을 AI와 함께 빠르게 구현했습니다.
- 단순 코드 생성에 그치지 않고, 빌드 오류/배포 오류/폰트 문제/데이터 흐름 문제를 검증하며 개선했습니다.

## 실행 방법

```powershell
flutter pub get
flutter run -d chrome
```

## 웹 빌드

GitHub Pages 배포용 빌드는 base href를 저장소 이름에 맞춰 실행합니다.

```powershell
flutter build web --release --base-href="/planet_diary/"
```

## 테스트 및 점검

전체 정적 분석은 시간이 오래 걸릴 수 있어 필요할 때만 실행합니다.

```powershell
flutter test
git diff --check
```

수동 점검 항목:

- 여행 시작일을 바꾼 뒤 캘린더 날짜와 DAY가 맞는지 확인
- 오늘 이후 날짜에서 일기 작성이 막히는지 확인
- 새 일기 작성 후 다시 들어갔을 때 조회 모드로 열리는지 확인
- 기존 일기 수정 시 XP가 중복 지급되지 않는지 확인
- 월간/연간 리캡과 업적 배지가 기록 데이터에 맞게 갱신되는지 확인
- 설정 화면에서 JSON 백업/복원이 동작하는지 확인

## 배포

`main` 브랜치에 push하면 `.github/workflows/deploy.yml`이 실행되어 GitHub Pages로 자동 배포됩니다.

```powershell
git add .
git commit -m "문서 정리"
git push origin main
```
