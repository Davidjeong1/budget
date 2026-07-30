# 다비드 가계부 (David Ledger) — iOS

카드 승인 문자를 읽어 **금액·사용처·분류를 자동으로 가계부에 기록**하는 iOS 앱입니다.

## 먼저 알아야 할 iOS 제약

iOS는 앱이 문자(SMS)나 다른 앱의 알림을 직접 읽는 것을 **플랫폼 차원에서 금지**합니다.
안드로이드의 `RECEIVE_SMS`나 `NotificationListenerService`에 해당하는 API가 존재하지 않습니다.
(`ILMessageFilterExtension`은 모르는 번호의 스팸 차단 전용이라 내용을 앱에 저장할 수 없습니다.)

그래서 이 앱은 **단축어(Shortcuts) 자동화**를 통해 자동 기록을 구현합니다.
사용자가 자동화를 한 번 만들어두면, 문자가 도착할 때마다 iOS가 그 내용을 앱의 App Intent로 넘겨주고
앱이 파싱해서 저장합니다.

| | 자동 기록 |
| --- | --- |
| 문자(SMS/iMessage) 카드 승인 | 가능 — 단축어 자동화 |
| 카카오톡 승인 알림톡 | **불가능** — 공유 시트나 직접 입력으로 기록 |

## 주요 기능

- **결제 문자 자동 기록** — 단축어 자동화가 넘겨준 문자에서 금액, 가맹점, 카드 뒷 4자리, 승인 시각, 할부 개월을 추출합니다.
- **공유 시트 기록** — 문자나 알림을 길게 눌러 `공유 → 다비드 가계부`로 보내면 그 자리에서 기록됩니다.
- **중복 방지** — 같은 승인이 두 번 들어와도 한 건만 저장됩니다.
- **자동 분류** — 가맹점 이름으로 식비/카페/교통/쇼핑 등을 추정하며, 언제든 수정할 수 있습니다.
- **결제 취소 반영** — 승인 취소를 음수 지출로 기록해 원 결제와 상계합니다.
- **인식 테스트** — 설정 화면에 실제 카드 문자를 붙여넣어 저장 없이 인식 결과만 확인할 수 있습니다.
- **월별 가계부** — 월 단위 지출·수입 합계와 분류별 지출 비중.

## 지원하는 메시지 형식

| 발신 | 예시 |
| --- | --- |
| 신한카드 | `[Web발신] 신한카드(1234)승인 다비드님 12,000원 일시불 07/30 14:23 스타벅스코리아` |
| KB국민카드 | `[Web발신]KB국민카드 승인 다비드님 12,300원 일시불 07/30 14:23 스타벅스 정상승인` |
| 삼성카드 (할부) | `[삼성카드]승인 다비드님 33,000원(3개월) 07/30 14:23 스타벅스코리아` |
| 카카오페이 | `[카카오페이] 스타벅스코리아 12,000원 결제 완료` |
| 토스 | `[토스] 12,000원 승인 스타벅스코리아 07/30 14:23` |
| 승인 취소 | `신한카드(1234)승인취소 12,000원 07/30 15:00 스타벅스코리아` |

`누적`, `잔액`, `한도`, `포인트` 뒤에 나오는 금액은 결제 금액이 아니므로 무시합니다.

## 자동화 설정 방법

앱 설치 후 **설정** 화면의 안내를 따르거나, 아래대로 진행하세요.

1. **단축어** 앱 → **자동화** 탭
2. **새로운 자동화** → **메시지**
3. **메시지에 다음이 포함**에 `승인` 입력 (보낸 사람은 비워 둠)
4. **즉시 실행** 켜기, **실행 시 알림** 끄기
5. 동작으로 **결제 문자 가계부에 기록** 추가
6. `메시지 내용` 항목에 **메시지 내용** 변수를 넣고 저장

이후 승인 문자가 오면 자동으로 기록됩니다. 결제 문자가 아닌 메시지가 걸려도 파서가 걸러내므로 그냥 무시됩니다.

## 프로젝트 구조

```
budget/
├── Package.swift                 LedgerParser 스위프트 패키지
├── Sources/LedgerParser/         순수 로직 (UIKit/SwiftUI 의존성 없음)
│   ├── PaymentMessageParser      승인 문자 → 금액·가맹점·카드·시각 추출
│   ├── MerchantCategoryClassifier  가맹점 이름 → 분류 추정
│   ├── Category                  가계부 분류 항목
│   └── ParsedPayment             추출 결과 모델
├── Tests/LedgerParserTests/      파서 단위 테스트
├── DavidLedger/                  앱 타깃
│   ├── Model/Transaction         SwiftData 모델
│   ├── Model/LedgerStore         파싱 → 저장, 중복 방지 키 생성
│   ├── Intents/RecordPaymentIntent  단축어 자동화가 호출하는 App Intent
│   └── Views/                    Home / AddEdit / Settings
├── ShareExtension/               공유 시트로 받은 텍스트 기록
└── project.yml                   XcodeGen 스펙
```

인식 로직을 UI 의존성이 없는 `LedgerParser` 패키지로 분리했기 때문에 시뮬레이터 없이 `swift test`로 검증할 수 있습니다.
앱과 공유 확장은 App Group(`group.com.davidjeong.ledger`)으로 같은 SwiftData 저장소를 씁니다.

## 빌드

`.xcodeproj`는 `project.yml`에서 생성하므로 저장소에 커밋하지 않습니다.

```bash
brew install xcodegen
xcodegen generate
open DavidLedger.xcodeproj
```

파서 로직만 검증하려면:

```bash
swift test
```

Xcode에서 열었다면 앱 타깃과 공유 확장 모두에 **본인의 Apple Developer 팀**과
**App Group `group.com.davidjeong.ledger`** 를 설정해야 합니다.
번들 ID를 바꾸는 경우 `LedgerStore.appGroupID`와 두 `.entitlements` 파일의 값을 함께 맞춰 주세요.

## 검증 상태

`Sources/LedgerParser`와 `Tests/LedgerParserTests`의 테스트 12건은 **아직 실행되지 않았습니다.**
작성 환경(Linux 컨테이너)의 egress 정책이 `download.swift.org`를 차단해 Swift 툴체인을 설치할 수 없었고,
iOS 앱 빌드에는 macOS와 Xcode가 필요합니다. macOS에서 `swift test`를 먼저 돌려 보시고,
실패하는 카드사 문자가 있으면 원문을 테스트 케이스로 추가하면 됩니다.

## 개인정보 처리

읽어들인 메시지는 **기기 안에서만** 분석·저장됩니다. 네트워크로 전송하지 않으며 네트워크 권한도 요청하지 않습니다.
데이터는 App Group 컨테이너의 SwiftData 저장소에만 있고, 앱을 삭제하면 함께 지워집니다.

## 새로운 카드사 형식 추가하기

`Sources/LedgerParser/PaymentMessageParser.swift`의 `knownIssuers`에 카드사 이름을 추가하고,
`Tests/LedgerParserTests/PaymentMessageParserTests.swift`에 실제 문자 예시로 테스트를 추가하세요.
가맹점 자동 분류 키워드는 `MerchantCategoryClassifier.keywords`에서 관리합니다.
