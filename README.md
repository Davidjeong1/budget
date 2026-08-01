# 다비드 가계부 — iOS

수동 입력 기반 가계부 iOS 앱입니다. Figma 디자인의 6개 화면(홈 / 내역 / 추가 / 통계 / 예산 / 설정)을 SwiftUI로 구현했습니다.

## 화면

| 탭 | 내용 |
| --- | --- |
| 홈 | 월 소비 요약(지출·수입·남은 예산), 주간 지출 추이 막대, 최근 내역 4건 |
| 내역 | 일자별 그룹, 전체/지출/수입/카테고리 필터, 사용처·메모 검색, 탭하여 수정 |
| 추가 | 큰 금액 입력, 지출·수입 전환, 카테고리 선택, 날짜, 메모 |
| 통계 | 카테고리별 도넛 차트(상위 4개 + 기타), 가장 많이 쓴 카테고리 3개 |
| 예산 | 월 총 목표 예산과 카테고리별 목표, 사용률 막대 |
| 설정 | 화면 모드·강조 색, 알림·생체 인증, 카테고리 관리, CSV 내보내기, 버전 정보 |

모든 화면은 상단의 월 이동 컨트롤을 공유하며, 같은 달을 함께 바라봅니다.

## 기능

- **수동 입력** — 사용처를 입력하면 카테고리를 추정해 미리 선택해 줍니다(`MerchantCategoryClassifier`). 직접 고르면 추정이 더 이상 개입하지 않습니다.
- **사용자 카테고리** — 기본 8개 외에 이름·아이콘·색을 직접 정한 카테고리를 추가할 수 있습니다. 삭제는 보관 방식이라 이미 기록된 내역은 원래 이름과 색 그대로 남고, 새 내역에서만 선택 목록에서 빠집니다.
- **월별 예산** — 총 목표와 카테고리별 목표를 달마다 따로 저장합니다. 90%를 넘긴 카테고리는 빨간색으로 표시됩니다.
- **예산 소진 예측** — 지금까지의 지출 속도로 홈에 "이 속도면 24일에 예산을 다 씁니다"를 표시합니다. 90% 알림은 이미 쓴 뒤에 오지만, 이건 아직 바꿀 수 있을 때 알려 줍니다.
- **문자로 채우기** — 카드 승인 문자를 붙여넣으면 금액·사용처·시각을 읽어 추가 화면을 채웁니다. 사용처가 기존 카테고리 추정으로 이어져 분류까지 자동으로 됩니다. 읽은 내용을 보여준 뒤 적용하므로 잘못 읽으면 눈에 보입니다.
- **매일 저녁 알림** — 21시에 기록을 상기시키는 로컬 알림.
- **예산 초과 알림** — 저장 시점에 이번 달 예산의 90%를 넘으면 한 번 알립니다.
- **생체 인증 잠금** — Face ID 또는 기기 암호로 앱을 잠급니다. 백그라운드로 나가면 다시 잠기며, 사용할 수 없는 기기에서는 토글이 자동으로 꺼집니다.
- **다크 모드** — 설정에서 시스템·라이트·다크 중 고릅니다. 기본값은 시스템이라 첫 실행 시 기기 설정을 따릅니다. 강조 색도 10가지 중에서 따로 지정할 수 있습니다.
- **CSV 내보내기** — 공유 시트로 전체 내역을 내보냅니다. Excel에서 한글이 깨지지 않도록 BOM을 붙입니다.

## 자동 인식을 넣지 않은 이유

문자·카카오톡 승인 알림을 읽어 자동 기록하는 기능은 **iOS에서 구현할 수 없어 제외했습니다.**
iOS에는 안드로이드의 `RECEIVE_SMS`나 `NotificationListenerService`에 해당하는 API가 없고,
`ILMessageFilterExtension`은 모르는 번호의 스팸 차단 전용이라 내용을 앱에 저장할 수 없습니다.

앱이 문자를 **스스로 읽는** 것은 불가능하지만 사용자가 **건네주는** 것은 가능하므로, 대신 '문자로 채우기'를
넣었습니다(`PaymentMessageParser`). 복사해서 붙여넣으면 나머지는 자동으로 채워집니다.

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
└── project.yml                XcodeGen 스펙
```

`MonthlyDigest`가 월별 집계를 한곳에서 계산하므로 홈의 합계, 통계의 도넛, 예산의 막대가 서로 어긋나지 않습니다.

## 디자인 반영 시 유의사항

- **아이콘**: 디자인의 아이콘 세트를 번들에 넣지 못해 SF Symbols로 대체했습니다. 원본 에셋을 쓰려면 `Category.symbolName`과 `Tab.symbolName`을 이미지 애셋으로 교체하세요.
- **폰트**: 디자인은 Pretendard를 쓰지만 번들되어 있지 않아 시스템 폰트에 같은 크기·굵기로 매핑했습니다. `DesignSystem.swift`의 `Font` 확장만 바꾸면 교체됩니다.
- **색상**: Figma에 토큰 변수가 없어 원시 hex를 `Palette`에 한 번만 정의하고 나머지는 이름으로 참조합니다.
  디자인에 다크 프레임이 없어 다크 값은 파생시켰습니다 — 회색 계열은 같은 단계로 뒤집고, 수입·지출 색은
  어두운 배경에서 대비가 유지되도록 밝혔습니다. 강조 색만 사용자가 고르므로 `Palette.accent`는 상수가 아니라
  `AppSettings`를 읽는 계산 속성입니다.
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

Xcode에서 본인의 Apple Developer 팀을 선택해야 실기기 빌드가 됩니다.

Xcode Cloud도 같은 이유로 클론 직후에는 프로젝트가 없으므로, `ci_scripts/ci_post_clone.sh`가
`xcodegen generate`를 대신 실행합니다.

도메인 로직만 검증하려면:

```bash
swift test
```

## 검증 상태

`Tests/LedgerCoreTests`는 테스트 28건(단언 61개)입니다.

`MerchantCategoryClassifierTests` 10건은 macOS에서 **통과를 확인했습니다.**

```
Executed 10 tests, with 0 failures (0 unexpected) in 0.002 seconds
```

`BudgetPaceTests`와 `PaymentMessageParserTests`의 18건은 **아직 실행되지 않았습니다.**

`swift test`는 XCTest를 포함하지 않는 Command Line Tools 툴체인에서는 `unable to resolve module
dependency: 'XCTest'`로 실패합니다. `xcode-select -p`가 `/Library/Developer/CommandLineTools`를
가리키면 Xcode 쪽으로 바꿔 주세요:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

위 테스트가 다루는 범위는 UI 의존성이 없는 `Sources/LedgerCore`(분류 추정, 예산 예측, 문자 파싱)뿐입니다.
**`DavidLedger/`의 SwiftUI 화면과 SwiftData 모델을 검증하는 자동화된 테스트는 없으므로**, 화면 동작은
시뮬레이터나 실기기에서 직접 확인해야 합니다.
