# NotchFlow

현재 버전: **0.3.2 (build 6)**. 음악·캘린더 연결 설정 통합, 곡 변경 시 음악 화면 자동 펼침 토글, 첫 실행 권한 안내, 권한 상태별 복구 동작, GitHub 기반 업데이트 확인·다운로드, 앱 아이콘, 구버전 설정 호환 읽기와 업데이트 전 설정 백업을 포함합니다.

MacBook의 노치를 작은 생산성 공간으로 확장하는 macOS 네이티브 메뉴 막대 앱입니다. SwiftUI와 AppKit으로 구현했으며 외부 라이브러리를 사용하지 않습니다. 다른 앱의 코드·에셋을 사용하지 않은 독립 구현입니다.

## Features

- **Notch Engine:** 실제 안전 영역/노치 좌표 감지, 외부 모니터용 상단 중앙 Floating Island, 화면 선택과 연결 변경 대응. Hover 미리 보기, 클릭 확장, 외부 클릭/Esc 접기, 파일 드래그 확장.
- **Music:** 재생 중 노치 옆에 앨범 이미지 표시 (파형 없음), 일시 정지/연결 해제 시 축소. 가로형 미니 플레이어. Apple Music·Spotify 앱별 연결, 곡/아티스트/재생 상태, 재생 위치, 이전·재생/정지·다음. Apple Music이 제공하는 앨범 이미지 표시.
- **Calendar:** EventKit 오늘 일정과 다음 일정, 캘린더 앱 열기, 일정 시작 10분 전 내부 알림. 접근 권한은 연결 버튼을 눌렀을 때만 요청.
- **File Shelf:** 복수 파일·폴더 드롭, Drag Out, Quick Look, Finder에서 보기, 개별 제거/전체 비우기. 원본을 이동·복사·삭제하지 않음. 읽기 전용 security-scoped bookmark 저장, Missing 표시, 중복 제거.
- **Memo:** 생성·편집·삭제·고정·체크리스트·최근 목록, 500ms 디바운스 자동 저장, 접기/종료 시 저장. 저장 실패 시 종료 전 경고.
- **Dashboard:** 네 가지 기능을 가로 한 줄로 배치한 낮은 요약 패널과 상세 화면 전환. 대시보드는 노치 높이 + 214pt, 상세 화면은 필요한 높이만 사용합니다.
- **Notifications:** 곡 변경 시 음악 화면 자동 펼치기를 독립적으로 켜고 끌 수 있습니다. 일정·파일 추가·메모 저장 알림, 우선순위 큐, 중복 상태 알림 통합, 기존 확장/편집 상태 유지.
- **Settings:** 모듈별 활성화, 호버/클릭 설정, 애니메이션 시간, 화면, 테마·너비·곡률·불투명도·블러, 내부 알림. Reduce Motion 준수.
- **Global shortcut:** 기본 Option+Space. Control+Option+Space, Command+Shift+Space 또는 비활성화로 변경. 등록 충돌은 설정에 표시.
- **Launch at Login:** `SMAppService.mainApp`으로 등록/해제.
- **First Run:** 음악 자동화와 캘린더 권한을 단계별로 설명하고 현재 상태, 재시도, 시스템 설정 바로가기를 제공합니다. 설정에서 언제든 다시 열 수 있습니다.
- **Updates:** 앱 시작 시 선택적으로 HTTPS manifest를 확인하고, 새 DMG의 크기와 SHA-256을 검증한 뒤 엽니다. 업데이트 후에도 Application Support의 기존 설정·메모·선반 데이터는 유지됩니다.

## Screenshots

실행된 대시보드의 시각 검증을 완료했습니다. 저장소용 스크린샷은 아직 포함하지 않았습니다. 추후 `docs/screenshots/`에 노치/대시보드/선반 이미지를 추가할 수 있습니다. 실제 데이터처럼 보이는 샘플 곡이나 일정을 앱에 넣지 않았습니다.

## Requirements

- macOS **14.0 이상**, Apple silicon 또는 Intel Mac.
- Xcode **16 이상** 권장. 이 작업에서는 Xcode 27.0 (27A266a)으로 검증했습니다.
- 별도 패키지 설치, API 키, 개발 Team ID 불필요. 배포/로그인 실행에는 본인의 서명 설정을 사용하세요.
- 노치가 없는 화면에서도 실행됩니다. 선택한 한 화면에 하나의 패널을 표시합니다.

## Build / Run

### Xcode

1. **`NotchFlow.xcodeproj`** 를 엽니다. 앱 실행에는 `Package.swift` 대신 이 프로젝트를 사용하세요.
2. Scheme **NotchFlow**, 실행 대상 **My Mac** 을 선택합니다.
3. 로컬 실행은 Signing & Capabilities에서 **Sign to Run Locally**를 선택하거나 본인의 개발 Team을 지정합니다. 다른 사람의 Team ID는 포함하지 않았습니다.
4. **⌘R**. 메뉴 막대의 NotchFlow 아이콘 → **NotchFlow 열기**, 또는 노치 아래쪽을 클릭합니다.
5. 설정은 패널의 톱니바퀴 또는 메뉴 막대 → **설정…** 에 있습니다. 종료도 메뉴 막대에서 가능합니다.

### Terminal

```sh
./scripts/build-app.sh
open build/Build/Products/Debug/NotchFlow.app
```

직접 빌드할 경우:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project NotchFlow.xcodeproj -scheme NotchFlow \
  -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- build
```

실행 직후 대시보드를 펼치는 개발용 옵션:

```sh
open build/Build/Products/Debug/NotchFlow.app --args --show-dashboard
```

메뉴 막대 앱이므로 Dock 아이콘이나 일반 시작 창은 표시하지 않습니다. 앱을 두 번 실행하지 마세요. Xcode에서 기존 실행을 중지하고 다시 실행하면 됩니다.

### Tests

```sh
./scripts/build.sh test
```

Swift Package는 핵심 로직과 서비스 테스트를 위한 보조 빌드 경로입니다. 명령줄 executable을 직접 실행하면 앱 번들의 개인정보 사용 설명/서명 설정이 없으므로 캘린더·자동화의 실제 동작 검증에는 사용하지 마세요.

현재 **55개 XCTest 통과**: 좌표 계산, 음수 화면 원점, 상태 전환, 편집 중 알림, 일정 정렬과 권한 허용/거부/제한/오류 재시도/권한 철회, 큐 우선순위/FIFO/크기, 설정 정규화 및 구버전 복원/업데이트 백업, 메모 재실행 복원/손상 파일 보호, 선반 중복/원본 보호/Missing, 호버 이탈/재진입 및 예약 취소, 업데이트 버전 판정과 HTTPS 검증.

빌드 에이전트처럼 중첩 샌드박스가 차단되어 SwiftUI 매크로 실행이 실패하는 환경에서만 `NOTCHFLOW_DISABLE_MACRO_SANDBOX=1 ./scripts/build-app.sh`를 사용할 수 있습니다. 이는 컴파일러 프로세스 옵션이며 macOS 보안 설정을 변경하지 않습니다. 일반 Xcode 실행에는 필요하지 않습니다.

## Architecture

MVVM. `NotchStateMachine`이 상태 전환을 담당하고 `NotchViewModel`이 UI/윈도우를 연결합니다. SwiftUI는 콘텐츠와 전환을, borderless `NSPanel`은 위치·크기·포커스·Space 동작을 담당합니다. Window level은 `.statusBar`이며 그 이상으로 올리지 않습니다.

```text
Sources/
  NotchFlowCore/          순수 상태·좌표·모델·큐·원자적 저장
  NotchFlow/
    App/                 진입점, 메뉴 막대, lifecycle
    Core/                AppState, 모듈 선택/이벤트 연결
    Notch/               Panel, WindowController, View/ViewModel
    Music/               앱별 AppleScript 서비스, 재생 UI
    Calendar/            EventKit 서비스, 일정 및 단발 알림 타이머
    FileShelf/           북마크/접근 생명주기, Quick Look, 선반 UI
    Memo/                편집/자동 저장, 체크리스트 UI
    Dashboard/           요약 카드
    Notifications/       내부 알림 표시 수명 관리
    Settings/            설정 저장, ServiceManagement
    Services/            화면, 단축키, 저장 위치
    Utilities/           os.Logger
Resources/               Info.plist, hardened runtime entitlements
Tests/                   Core 단위 테스트 + mock 서비스 테스트
scripts/                 빌드 및 프로젝트 재생성
```

`CalendarProviding`, `MusicProviding`, `FileShelfProviding`, `ScreenProviding`으로 시스템 경계를 분리합니다. 신규 Swift 파일을 추가하면 Xcode에 추가하거나 `python3 scripts/generate_project.py`로 프로젝트를 재생성하세요. 재생성은 프로젝트의 수동 Signing 변경도 기본값으로 돌리므로 주의하세요.

저장은 SwiftData 대신 **버전별 Codable JSON + atomic write**를 선택했습니다. 네 모듈의 데이터를 단순하게 검사·백업할 수 있고 손상 파일을 덮어쓰지 않는 경로를 직접 테스트하기 위해서입니다. SwiftData는 현재 의존하지 않습니다.

## Permissions / Privacy

- **Calendar:** 연결 시 `requestFullAccessToEvents()` 요청. 읽기/목록만 제공하지만 EventKit에는 별도의 읽기 전용 권한이 없어 전체 접근 권한이 필요합니다. 거부하면 Calendar만 제한됩니다.
- Calendar 권한 창이 뜨지 않으면: 앱을 종료하고 새 버전으로 교체한 뒤 다시 실행하세요. 최초 요청 중에는 진행 상태가 표시됩니다. 이미 거부했다면 **시스템 설정에서 허용**을 눌러 **개인정보 보호 및 보안 → 캘린더 → NotchFlow**에서 전체 접근을 허용하세요. 승인 전에는 캘린더 데이터를 읽지 않습니다. 기기 관리 정책으로 제한된 경우에는 관리자 안내를 표시합니다.
- **Music:** 연결한 플레이어에 대해서만 Apple Events/자동화 권한을 요청합니다. 시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 관리합니다. 연결 전에는 스크립트를 실행하지 않습니다.
- **Files:** 사용자가 드롭한 URL의 보안 북마크를 저장합니다. 접근 중에만 security scope를 유지하고 선반 제거/종료 시 해제합니다. 전체 디스크 접근은 요청하지 않습니다.
- **Notifications:** Notification Center를 사용하지 않는 **앱 내부 알림**이므로 시스템 알림 권한을 요청하지 않습니다.
- **Keyboard:** 공개 Carbon `RegisterEventHotKey`를 사용합니다. 접근성/입력 모니터링 권한을 요구하지 않습니다. 외부 클릭 감지는 마우스 이벤트만 구독합니다.
- **Login:** 사용자가 설정에서 켤 때에만 등록합니다. 시스템의 추가 승인이 필요하면 안내합니다.
- 앱은 메모·일정·파일 목록을 외부에 전송하지 않습니다. 분석 SDK나 원격 측정 기능이 없으며 음악 제목/메모/일정 제목은 로그에 남기지 않습니다. 자동 업데이트를 켠 경우에만 설정된 HTTPS 주소에서 버전 manifest와 DMG를 받습니다.

현재 빌드는 **App Sandbox를 활성화하지 않은 직접 배포용 개발 구성**입니다. Hardened Runtime 구성과 Apple Events·Calendars entitlement를 포함합니다. 보안 북마크를 쓴다고 앱 전체가 샌드박스되는 것은 아닙니다. Mac App Store 배포를 위해서는 사용자 선택 파일/플레이어별 Apple Events entitlement와 심사 요건을 별도로 검토해야 합니다.

## Local Data / Recovery

### 버전 업데이트

기존 앱을 메뉴 막대에서 종료한 뒤 `/Applications/NotchFlow.app`만 새 버전으로 교체하세요. Bundle Identifier (`local.NotchFlow`), 데이터 폴더와 저장 파일 이름은 앱 버전과 무관하게 유지합니다. 따라서 기존 설정·메모·파일 선반을 그대로 읽습니다. 이전 앱에서 이미 초기화되어 저장된 값까지 되돌리는 기능은 아닙니다.

구버전에 없던 설정 키만 새 기본값으로 채우며, 기존 테마·모듈·단축키·화면·너비 등은 유지합니다. 이전 버전에서 지원한 380–599pt 너비도 유효한 값으로 취급합니다. 잘못된 데이터 유형이나 손상 파일은 자동 덮어쓰기하지 않습니다.

새 빌드에서 설정을 처음 변경하기 전에 `settings-v1.json.before-2.bak`처럼 이전 파일을 한 번 백업합니다. 백업은 같은 버전의 재실행/후속 편집으로 덮어쓰지 않습니다. 새 배포를 만들 때마다 CFBundleVersion을 증가시키세요. 운영체제의 자동화/캘린더 권한과 로그인 항목 승인은 macOS가 관리하므로 앱 설정 백업의 대상은 아닙니다.

### 업데이트 배포 연결

1. 새 DMG를 `dist/NotchFlow-X.Y.Z.dmg`에 만들고 `shasum -a 256`으로 체크섬을 계산합니다.
2. 저장소 루트의 `update.json`에 버전, build, GitHub raw DMG 주소, 체크섬, 변경 내용을 기록합니다.
3. DMG와 `update.json`을 `main` 브랜치에 함께 게시합니다. 앱은 `https://raw.githubusercontent.com/jb-han-cording/NotchFlow/main/update.json`을 확인합니다.

manifest와 DMG 주소는 모두 HTTPS여야 합니다. 앱은 2xx 응답, manifest 1MB 이하, DMG 250MB 이하, 64자리 SHA-256을 확인합니다. 현재 설치 방식은 검증된 DMG를 열고 사용자가 Applications의 앱을 교체하는 흐름입니다. 완전한 무인 교체와 공증 배포에는 Developer ID 서명과 Sparkle 같은 서명된 업데이트 프레임워크 구성이 필요합니다.

앱 아이콘의 원본과 생성 프롬프트: [Resources/Branding](Resources/Branding/README.md). `./scripts/build-icon.sh`로 macOS ICNS를 재생성할 수 있습니다. 변환에는 macOS의 iconutil이 필요합니다.

`~/Library/Application Support/NotchFlow/`:

- `memos-v1.json`: 메모/체크리스트
- `shelf-v1.json`: 파일 참조와 보안 북마크
- `settings-v1.json`: 설정

손상 데이터를 발견하면 해당 저장소의 쓰기를 막고 안내합니다. 앱을 종료한 뒤 파일을 백업하고 정상 백업으로 복구하세요. 저장 폴더를 옮기거나 비우기 전에는 메모를 반드시 백업하세요. 데이터는 로컬 평문이며 별도 앱 암호화는 제공하지 않습니다.

## Technical Constraints / Known Limitations

1. **범용 Now Playing 읽기/제어 없음.** `MPNowPlayingInfoCenter`는 앱 자신의 재생 정보를 제공하는 API입니다. private MediaRemote를 사용하지 않습니다. 브라우저·YouTube·임의 플레이어는 지원하지 않습니다.
2. **플레이어별 연동:** Apple Music/Spotify 데스크톱의 AppleScript 인터페이스를 사용합니다. 플레이어를 먼저 실행하고 연결하세요. 앱이 제공하는 재생 변경 알림은 갱신 힌트로 사용하며, 버전에 따라 전달되지 않을 수 있어 수동 새로 고침도 제공합니다. 자동 재연결/범용 탐지는 없습니다.
3. Apple Music 앨범 이미지는 스크립팅으로 제공되는 경우에만 표시합니다. **Spotify 앨범 이미지는 현재 SF Symbol 대체 표시**입니다. 진행 바는 최근 실제 위치에서 경과 시간을 계산하며, 다른 앱에서 seek한 후에는 새로 고침이 필요할 수 있습니다. seek 조작은 제공하지 않습니다.
4. Calendar는 **오늘**의 일정에 한정됩니다. 현재 실행 중인 앱에서 일정 10분 전 알림을 제공합니다. 앱 종료 중 알림은 없고, 절전 해제 후 아직 시작 전인 일정은 다시 계산합니다.
5. 전체 화면 Space는 `.fullScreenAuxiliary`로 지원을 요청합니다. 전체 화면 앱/Spaces/Stage Manager 조합 및 메뉴 막대 자동 숨김은 장치별 확인이 필요합니다. 시스템 잠금/보안 화면 위에는 표시하지 않습니다.
6. 파일 이동은 bookmark가 해결할 수 있는 범위에서 복구합니다. 볼륨 연결 해제·삭제·권한 변경 시 Missing으로 남기며 **새로 고침** 또는 다시 드롭해야 합니다. 파일 시스템을 계속 폴링하지 않습니다.
7. Launch at Login은 직접 배포·서명·설치 위치와 시스템 승인에 영향을 받습니다. 배포용으로 서명 후 `/Applications`에 설치해서 확인하세요. 이 개발 환경에서 자동 로그인은 켜지 않았습니다.
8. 단축키는 세 가지 안전한 조합 중 선택합니다. 임의 키 녹음 UI는 아직 없습니다. UI 자동화의 합성 키로 시스템 전역 단축키를 신뢰성 있게 확인하지 못했으므로 실제 키보드 검증이 남아 있습니다.
9. 현재는 초기 개발 버전입니다. 실제 플레이어 권한 허용 후 제어, 실제 캘린더, Finder Drag Out/Quick Look, 다중 디스플레이 hot-plug 등은 아래 수동 체크리스트로 검증해야 합니다.

## Performance

음악 재생 상태는 연결된 동안 1.25초 간격으로 가벼운 백그라운드 확인을 수행하며 앨범 이미지는 상태 변화가 있을 때만 가져옵니다. 접힌 패널에는 불필요한 진행 애니메이션이 없으며 높이는 화면의 실제 노치 안전 영역과 일치합니다. 일정에는 다음 알림과 자정 갱신용 단발 타이머만 있고, 음악 진행 표시는 상세 UI가 있을 때만 1초마다 갱신합니다. Observer, hotkey, security scope는 앱 종료 시 해제합니다. 업데이트 확인은 앱 시작 시 한 번 또는 사용자가 버튼을 누를 때만 수행합니다.

## Validation / Roadmap

자세한 실행 결과와 수동 체크리스트: [docs/VALIDATION.md](docs/VALIDATION.md).

다음 단계: 서명·공증 및 배포 패키지, VoiceOver/키보드 사용성 확대, 임의 단축키 recorder, Spotify 앨범 이미지, 내보내기/복원 UI, 다중 화면 실기 검증. 이후 타이머·Pomodoro·Downloads 모듈을 추가할 수 있습니다.

## API References

- [NSScreen auxiliaryTopLeftArea](https://developer.apple.com/documentation/AppKit/NSScreen/auxiliaryTopLeftArea-uglc)
- [MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)
- [EventKit access levels](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels)
- Apple Music scripting dictionary: `/System/Applications/Music.app/Contents/Resources/com.apple.Music.sdef` (로컬 API 정의 확인)
