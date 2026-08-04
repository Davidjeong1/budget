# 다비드 가계부 — iOS

수동 입력 기반 가계부 iOS 앱입니다. Figma 디자인의 6개 화면(홈 / 내역 / 추가 / 통계 / 예산 / 설정)을 SwiftUI로 구현했습니다.

## 화면

| 탭 | 내용 |
| --- | --- |
| 홈 | 남은 예산 중심 요약(D-day·전체 예산·수입/지출), 주간 소비 추이, 최근 내역 4건 |
| 내역 | 일자별 그룹, 전체/지출/수입/카테고리 필터, 사용처·메모 검색, 탭하여 수정 |
| 추가 | 큰 금액 입력, 지출·수입 전환, 카테고리 선택, 날짜, 메모 |
| 통계 | 카테고리별 도넛 차트, 비율 막대가 붙은 카테고리 목록 |
| 예산 | 월 총 목표 예산과 카테고리별 목표(카테고리를 골라 설정), 사용률 막대 |
| 설정 | 화면 모드·강조 색, 알림·생체 인증, 카테고리 관리, CSV 내보내기, 버전 정보 |

모든 화면은 상단의 월 이동 컨트롤을 공유하며, 같은 달을 함께 바라봅니다.

## 기능

- **수동 입력** — 사용처를 입력하면 카테고리를 추정해 미리 선택해 줍니다(`MerchantCategoryClassifier`). 직접 고르면 추정이 더 이상 개입하지 않습니다.
- **사용자 카테고리** — 기본 8개 외에 이름·아이콘·색을 직접 정한 카테고리를 추가할 수 있습니다. 삭제는 보관 방식이라 이미 기록된 내역은 원래 이름과 색 그대로 남고, 새 내역에서만 선택 목록에서 빠집니다.
- **월별 예산** — 총 목표와 카테고리별 목표를 달마다 따로 저장합니다. 90%를 넘긴 카테고리는 빨간색으로 표시됩니다.
- **예산 소진 예측** — 지금까지의 지출 속도로 홈에 "이 속도면 24일에 예산을 다 씁니다"를 표시합니다. 90% 알림은 이미 쓴 뒤에 오지만, 이건 아직 바꿀 수 있을 때 알려 줍니다.
- **문자 공유로 기록** — 문자 앱에서 승인 문자를 공유하면 공유 시트에 다비드 가계부가 뜹니다. 금액·사용처·카테고리를 확인하고 저장하면 앱을 열지 않고 기록됩니다.
- **문자로 채우기** — 카드 승인 문자를 붙여넣으면 금액·사용처·시각을 읽어 추가 화면을 채웁니다. 사용처가 기존 카테고리 추정으로 이어져 분류까지 자동으로 됩니다. 읽은 내용을 보여준 뒤 적용하므로 잘못 읽으면 눈에 보입니다.
- **매일 저녁 알림** — 21시에 기록을 상기시키는 로컬 알림.
- **예산 초과 알림** — 저장 시점에 이번 달 예산의 90%를 넘으면 한 번 알립니다.
- **생체 인증 잠금** — Face ID 또는 기기 암호로 앱을 잠급니다. 백그라운드로 나가면 다시 잠기며, 사용할 수 없는 기기에서는 토글이 자동으로 꺼집니다.
- **홈 화면 위젯** — 오늘 쓴 돈과 이번 달 예산 사용률을 링으로 보여줍니다. 앱을 열지 않아도 보이는 것이 가계부에서는 기록만큼 중요합니다. 내역이나 예산이 바뀌면 즉시 갱신되고, 자정에 오늘 합계가 리셋됩니다.
- **다크 모드** — 설정에서 시스템·라이트·다크 중 고릅니다. 기본값은 시스템이라 첫 실행 시 기기 설정을 따릅니다. 강조 색도 10가지 중에서 따로 지정할 수 있습니다.
- **CSV 내보내기** — 공유 시트로 전체 내역을 내보냅니다. Excel에서 한글이 깨지지 않도록 BOM을 붙입니다.

## 자동 인식을 넣지 않은 이유

문자·카카오톡 승인 알림을 읽어 자동 기록하는 기능은 **iOS에서 구현할 수 없어 제외했습니다.**
iOS에는 안드로이드의 `RECEIVE_SMS`나 `NotificationListenerService`에 해당하는 API가 없고,
`ILMessageFilterExtension`은 모르는 번호의 스팸 차단 전용이라 내용을 앱에 저장할 수 없습니다.

앱이 문자를 **스스로 읽는** 것은 불가능하지만 사용자가 **건네주는** 것은 가능하므로, 그 경로를 두 가지
넣었습니다(둘 다 `PaymentMessageParser`를 씁니다).

- **공유** — 문자에서 텍스트를 선택해 공유 → 다비드 가계부. 앱을 열지 않고 두 탭이면 끝납니다(`LedgerShare`).
- **붙여넣기** — 복사한 뒤 추가 화면의 '문자로 채우기'. 공유가 뜨지 않는 앱에서 쓰는 경로입니다.

## 프로젝트 구조

```
budget/
├── Package.swift              LedgerCore 스위프트 패키지
├── Sources/LedgerCore/        UI 의존성 없는 도메인 로직
│   ├── Category               분류 항목 — 라벨, SF Symbol, 색상
│   ├── MerchantCategoryClassifier  사용처 이름 → 분류 추정
│   ├── BudgetPace             지출 속도 → 예산 소진 예측
│   └── PaymentMessageParser   카드 승인 문자 → 금액·사용처·시각
├── Tests/LedgerCoreTests/     단위 테스트
├── DavidLedger/
│   ├── Model/                 Transaction, Budget, CustomCategory (SwiftData), MonthRange
│   ├── Support/               DesignSystem, CategoryCatalog, MonthlyDigest, 알림, CSV, 설정
│   └── Views/                 6개 화면 + 공용 컴포넌트 + 잠금 화면
├── LedgerShare/               공유 익스텐션 — 문자 앱에서 바로 기록
├── LedgerWidget/              홈 화면 위젯 — 오늘 지출과 예산 사용률
└── project.yml                XcodeGen 스펙
```

`MonthlyDigest`가 월별 집계를 한곳에서 계산하므로 홈의 합계, 통계의 도넛, 예산의 막대가 서로 어긋나지 않습니다.

익스텐션들은 앱과 **별개의 프로세스**라 자기 샌드박스만 봅니다. 그래서 SwiftData 저장소와 설정을 App Group
(`group.com.davidjeong.ledger`)에 두고 셋이 같은 것을 읽습니다. 각 익스텐션이 컴파일하는 앱 파일은
`project.yml`에 하나씩 나열되어 있습니다 — 디렉터리 통째로 넣으면 익스텐션에서 쓸 수 없는 코드까지 끌려옵니다.

위젯은 별도 프로세스라 앱이 저장해도 스스로 알지 못합니다. 내역·예산을 쓰는 지점마다
`WidgetCenter.reloadAllTimelines()`를 호출해 갱신합니다.

## 디자인 반영 시 유의사항

- **앱 아이콘**: `DavidLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` 한 장만 두면 iOS가
  나머지 크기를 만들어 냅니다. 정사각형 원본이어야 하고 **알파 채널이 없어야** 합니다 — 모서리는 iOS가
  깎으므로 미리 둥글릴 필요가 없고, 투명한 픽셀이 있으면 App Store 업로드가 거부됩니다.
- **아이콘**: 디자인의 아이콘 세트를 번들에 넣지 못해 SF Symbols로 대체했습니다. 원본 에셋을 쓰려면 `Category.symbolName`과 `Tab.symbolName`을 이미지 애셋으로 교체하세요.
- **폰트**: 디자인은 Pretendard를 쓰지만 번들되어 있지 않아 시스템 폰트에 같은 크기·굵기로 매핑했습니다. `DesignSystem.swift`의 `Font` 확장만 바꾸면 교체됩니다.
- **색상**: Figma에 토큰 변수가 없어 원시 hex를 `Palette`에 한 번만 정의하고 나머지는 이름으로 참조합니다.
  라이트·다크 프레임이 모두 있어 두 값을 쌍으로 넣었습니다. 강조 색만 사용자가 고르므로 `Palette.accent`는
  상수가 아니라 `AppSettings`를 읽는 계산 속성이고, 통계의 도넛·막대는 카테고리 고유색 대신 강조색의
  명암 단계(`Palette.accentShade`)로 순위를 표현합니다.
- **월 이동 컨트롤**: 새 디자인에는 없지만 각 화면 헤더에 남겼습니다. 모든 화면이 같은 달을 공유하는 구조라
  빼면 이번 달에 갇힙니다.
- **추가 화면의 사용처**: 디자인에는 없지만 유지했습니다. 내역 목록이 행마다 사용처를 찍고, 카테고리 추정도
  사용처로 동작합니다.
- **상태 표시줄·홈 인디케이터**: 디자인에 그려진 것은 OS가 그리는 영역이라 앱에서는 재현하지 않았습니다.
- 설정 화면의 계정 카드는 이 앱에 계정 개념이 없어, 가상의 사용자를 만들지 않고 가계부 정보를 보여주도록 바꿨습니다.
- 설정의 '연결된 은행 및 카드'는 iOS에서 구현이 불가능해 제외했습니다.

## 빌드

`.xcodeproj`는 `project.yml`에서 생성하므로 저장소에 커밋하지 않습니다.

```bash
brew install xcodegen
xcodegen generate
open DavidLedger.xcodeproj
```

Xcode에서 본인의 Apple Developer 팀을 선택해야 실기기 빌드가 됩니다. 타겟이 셋(`DavidLedger`,
`LedgerShare`, `LedgerWidget`)이므로 **전부** 팀을 선택해야 합니다.

**App Groups**는 유료 개발자 프로그램에서만 쓸 수 있습니다. 서명 후 세 타겟의 Signing & Capabilities에
`group.com.davidjeong.ledger`가 체크되어 있는지 확인하세요. 없으면 저장소를 열지 못해 앱이 메모리 모드로
떨어지고, 기록한 내역이 남지 않습니다. 이 상태에서는 앱 상단에 빨간 배너가 뜨고 공유 익스텐션은 저장을
거부합니다 — 화면상으로는 전부 정상으로 보이는데 앱을 닫으면 한 달치가 사라지는 것이 가장 나쁜 결과라
`LedgerStore.isEphemeral`을 눈에 보이게 했습니다.

Xcode Cloud도 같은 이유로 클론 직후에는 프로젝트가 없으므로, `ci_scripts/ci_post_clone.sh`가
`xcodegen generate`를 대신 실행합니다.

### 개인정보 보호 매니페스트

세 타겟에 각각 `PrivacyInfo.xcprivacy`가 있고, 셋 다 `UserDefaults`를 필수 사유 API로 선언합니다.
앱 번들과 `PlugIns/` 안의 익스텐션은 별개의 번들이라 검사가 번들마다 돌기 때문에, 앱 쪽 한 장으로는
익스텐션이 덮이지 않습니다. 파일은 각 타겟 디렉터리에 두면 XcodeGen이 리소스로 잡아 번들 루트에
복사합니다.

**필수 사유 API를 새로 쓰기 시작하면 해당 타겟의 매니페스트에도 추가해야 합니다.** 빠뜨려도 빌드와
업로드는 통과하고, 심사 단계에서 `ITMS-91053`과 함께 "잘못된 바이너리"로 돌아옵니다. 지금 걸리는
것은 `UserDefaults`뿐이지만, 파일 타임스탬프(`creationDate`·`modificationDate`)나 디스크 여유
공간, `systemUptime`을 읽게 되면 각각 별도 항목이 필요합니다.

도메인 로직만 검증하려면:

```bash
swift test
```

### fastlane

`brew install fastlane` 후:

```bash
fastlane build              # 시뮬레이터용 컴파일 확인, 서명 없음
FASTLANE_TEAM_ID=ABCD123456 fastlane beta   # 아카이브 후 TestFlight 업로드
```

두 레인 모두 `xcodegen generate`를 먼저 돌립니다. `beta`는 빌드 번호를 타임스탬프로 채우는데,
App Store Connect가 한 번 받은 번호를 다시 받지 않기 때문입니다.

**아카이브는 시드가 아닌 SDK로 해야 합니다.** 버전 번호가 아니라 빌드 번호를 봐야 합니다. 빌드
202608031815과 202608041848이 `ITMS-90111`로 반려됐는데, 둘 다 그날의 최신 정식 Xcode
26.6 (17F113)에 iOS 26.5 SDK — 짝이 맞는 조합입니다. 문제는 그 SDK의 빌드가 **23F81a**였다는
것입니다. 릴리스는 23F77이고, 끝의 소문자가 Apple의 시드 표기입니다. ITMS-90111이 요구하는 것은
"latest Xcode and SDK **Release Candidates**"라, 시드는 버전이 맞아도 받지 않습니다.

반려 시점이 특히 나쁩니다. 업로드도 처리도 다 지나가고 심사에 넣은 뒤에야 옵니다. 아카이브 내용에는
문제가 없고 만든 툴체인만 시드라, 소스를 고쳐서는 없어지지 않습니다.

```bash
xcrun --sdk iphoneos --show-sdk-build-version   # 소문자로 끝나면 시드입니다
xcodebuild -downloadPlatform iOS                # 릴리스 플랫폼 받기
```

베타 Xcode를 함께 두고 계시면 시드 SDK는 대개 거기서 딸려옵니다. 정식 Xcode로 아카이브하세요.

`beta`는 아카이브 전에 무엇으로 빌드하는지 찍고, SDK 빌드가 시드거나 `xcode-select`이
Command Line Tools를 가리키고 있으면 거기서 멈춥니다:

```bash
xcode-select -p                          # /Applications/Xcode.app/... 을 가리켜야 합니다
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version  # 요구 버전은 developer.apple.com/news/releases
```

시드 SDK가 원인이라는 판단은 위 두 번의 반려에서 읽어낸 것이지 Apple이 문서로 밝힌 규칙은
아닙니다. 틀렸다고 보시면 `FASTLANE_ALLOW_SEED_SDK=1`로 넘길 수 있습니다 — 잘못된 추론이
릴리스를 막는 일은 없어야 하니까요.

버전 하한은 코드에 박아 두지 않았습니다 — Apple이 해마다 올리므로 적어 두는 순간 틀리기 시작합니다.
강제하려면 `FASTLANE_MINIMUM_IOS_SDK=26.0 fastlane beta`처럼 넘기세요.

**업로드 자격 증명도 따로 필요합니다.** `upload_to_testflight`가 내부에서 쓰는 altool은 fastlane이
여는 App Store Connect 세션과 별개로 인증합니다. 그래서 "Login successful"이 찍혀도 업로드가 된다는
뜻이 아니고, 자격 증명이 없으면 아카이브·서명이 다 끝난 뒤에야 `-22938`로 떨어집니다. `beta`는 이것도
아카이브 전에 확인합니다. 둘 중 하나를 넘기세요:

```bash
# 1. App Store Connect API 키 — 2FA 프롬프트가 없고 세션이 만료되지 않아 이쪽을 권합니다.
#    App Store Connect → 사용자 및 액세스 → 통합 → App Store Connect API 에서 발급합니다.
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH=~/private_keys/AuthKey_XXXXXXXXXX.p8

# 2. 앱 전용 암호 — account.apple.com → 로그인 및 보안 → 앱 전용 암호.
#    계정 비밀번호는 받지 않습니다. 그게 -22938이 말하는 내용입니다.
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

이미 만들어 둔 `.ipa`가 있으면 다시 빌드하지 않고 그것만 올릴 수 있습니다:

```bash
fastlane run upload_to_testflight ipa:DavidLedger.ipa skip_waiting_for_build_processing:true
```

Xcode Cloud로 빌드할 때는 이 검사가 걸리지 않습니다. 그쪽 Xcode 버전은 저장소가 아니라 워크플로
설정에 있으니, App Store Connect → Xcode Cloud → 워크플로에서 직접 올려야 합니다.

`bundle exec`는 쓰지 마세요 — macOS 기본 Ruby 2.6에는 `fastlane init`이 적어 둔 bundler 버전이
없어서 실행 전에 실패합니다.

## 검증 상태

`Tests/LedgerCoreTests`의 테스트 28건(단언 61개)은 macOS에서 **전부 통과했습니다.**

```
Executed 28 tests, with 0 failures (0 unexpected) in 0.003 seconds
```

세 타겟(`DavidLedger`, `LedgerShare`, `LedgerWidget`) 모두 시뮬레이터 SDK로 컴파일됩니다:

```bash
for t in DavidLedger LedgerShare LedgerWidget; do
  xcodebuild -project DavidLedger.xcodeproj -target $t \
    -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
done
```

`-target`과 `-sdk`를 쓰는 것은 목적지 해석을 건너뛰기 위해서입니다. `-scheme`과 `-destination`은
시뮬레이터 런타임이 설치되어 있어야 하고, 없으면 컴파일 확인 전에 실패합니다.

`swift test`는 XCTest를 포함하지 않는 Command Line Tools 툴체인에서는 `unable to resolve module
dependency: 'XCTest'`로 실패합니다. `xcode-select -p`가 `/Library/Developer/CommandLineTools`를
가리키면 Xcode 쪽으로 바꿔 주세요:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

위 테스트가 다루는 범위는 UI 의존성이 없는 `Sources/LedgerCore`(분류 추정, 예산 예측, 문자 파싱)뿐입니다.
**`DavidLedger/`의 SwiftUI 화면과 SwiftData 모델을 검증하는 자동화된 테스트는 없으므로**, 화면 동작은
시뮬레이터나 실기기에서 직접 확인해야 합니다.
