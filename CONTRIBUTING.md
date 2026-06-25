# MoaIMF 기여 안내

## 개발 환경

- macOS 13 이상
- Xcode 16 이상 및 Xcode Command Line Tools
- Swift 6 이상

저장소를 복제한 뒤 다음 명령으로 포맷, 테스트, 디버그 빌드, 릴리스 앱 번들과 서명을 한 번에 검사합니다.

```sh
scripts/check.sh
```

특정 테스트만 실행할 때도 최종 제출 전에는 반드시 전체 검사를 실행해야 합니다.

## 개발 원칙

- 기능과 버그 수정은 실패하는 테스트를 먼저 작성하는 TDD 흐름을 사용합니다.
- 파일명 변경은 내용과 확장 속성을 보존하고, 기존 대상에 덮어쓰지 않아야 합니다.
- 테스트는 임시 디렉터리 안의 자체 fixture만 변경해야 합니다. 실제 `Downloads`, 홈 디렉터리 또는 사용자의 감시 폴더를 사용하지 마세요.
- 심볼릭 링크 대상을 따라가거나 macOS 패키지 내부를 검사하는 테스트를 만들지 마세요.
- 네트워크 요청, 텔레메트리, 원격 설정, 자동 다운로드를 추가하지 마세요. MoaIMF는 로컬 전용 앱입니다.
- 새 의존성이 필요하다면 표준 프레임워크만으로 해결할 수 없는 이유를 PR에 설명하세요.

## 제출 전 확인

```sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
scripts/build-app.sh
codesign --verify --deep --strict .build/MoaIMF.app
```

UI 변경에는 한국어·영어, 긴 경로, 키보드 접근, 밝은/어두운 모드에서의 실제 렌더링 확인을 포함하세요.
