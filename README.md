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
| 설정 | 알림·생체 인증, CSV 내보내기, 버전 정보 |

모든 화면은 상단의 월 이동 컨트롤을 공유하며, 같은 달을 함께 바라봅니다.

## 기능

- **수동 입력** — 사용처를 입력하면 카테고리를 추정해 미리 선택해 줍니다(`MerchantCategoryClassifier`). 직접 고르면 추정이 더 이상 개입하지 않습니다.
- **월별 예산** — 총 목표와 카테고리별 목표를 달마다 따로 저장합니다. 90%를 넘긴 카테고리는 빨간색으로 표시됩니다.
- **매일 저녁 알림** — 21시에 기록을 상기시키는 로컬 알림.
- **예산 초과 알림** — 저장 시점에 이번 달 예산의 90%를 넘으면 한 번 알립니다.
- **생체 인증 잠금** — Face ID 또는 기기 암호로 앱을 잠급니다. 백그라운드로 나가면 다시 잠기며, 사용할 수 없는 기기에서는 토글이 자동으로 꺼집니다.
- **CSV 내보내기** — 공유 시트로 전체 내역을 내보냅니다. Excel에서 한글이 깨지지 않도록 BOM을 붙입니다.

## 자동 인식을 넣지 않은 이유

문자·카카오톡 승인 알림을 읽어 자동 기록하는 기능은 **iOS에서 구현할 수 없어 제외했습니다.**
iOS에는 안드로이드의 `RECEIVE_SMS`나 `NotificationListenerService`에 해당하는 API가 없고,
`ILMessageFilterExtension`은 모르는 번호의 스팸 차단 전용이라 내용을 앱에 저장할 수 없습니다.

## 프로젝트 구조

```
budget/
├── Package.swift              LedgerCore 스위프트 패키지
├── Sources/LedgerCore/        UI 의존성 없는 도메인 로직
│   ├── Category               분류 항목 — 라벨, SF Symbol, 색상
│   └── MerchantCategoryClassifier  사용처 이름 → 분류 추정
├── Tests/LedgerCoreTests/     단위 테스트
├── DavidLedger/
│   ├── Model/                 Transaction, Budget (SwiftData), MonthRange
│   ├── Support/               DesignSystem, MonthlyDigest, 알림, CSV, 설정
│   └── Views/                 6개 화면 + 공용 컴포넌트 + 잠금 화면
└── project.yml                XcodeGen 스펙
```

`MonthlyDigest`가 월별 집계를 한곳에서 계산하므로 홈의 합계, 통계의 도넛, 예산의 막대가 서로 어긋나지 않습니다.

## 디자인 반영 시 유의사항

- **아이콘**: 디자인의 아이콘 세트를 번들에 넣지 못해 SF Symbols로 대체했습니다. 원본 에셋을 쓰려면 `Category.symbolName`과 `Tab.symbolName`을 이미지 애셋으로 교체하세요.
- **폰트**: 디자인은 Pretendard를 쓰지만 번들되어 있지 않아 시스템 폰트에 같은 크기·굵기로 매핑했습니다. `DesignSystem.swift`의 `Font` 확장만 바꾸면 교체됩니다.
- **색상**: Figma에 토큰 변수가 없어 원시 hex를 `Palette`에 한 번만 정의하고 나머지는 이름으로 참조합니다.
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

도메인 로직만 검증하려면:

```bash
swift test
```

## 검증 상태

`Tests/LedgerCoreTests`의 테스트 10건(단언 24개)은 macOS에서 **전부 통과했습니다.**

```
Executed 10 tests, with 0 failures (0 unexpected) in 0.002 seconds
```

`swift test`는 XCTest를 포함하지 않는 Command Line Tools 툴체인에서는 `unable to resolve module
dependency: 'XCTest'`로 실패합니다. `xcode-select -p`가 `/Library/Developer/CommandLineTools`를
가리키면 Xcode 쪽으로 바꿔 주세요:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**iOS 앱 자체의 빌드와 실행은 아직 검증되지 않았습니다.** 위 테스트가 다루는 범위는 UI 의존성이 없는
`Sources/LedgerCore`(분류 추정과 `Category`)뿐이고, `DavidLedger/`의 SwiftUI 화면과 SwiftData 모델은
포함되지 않습니다.
