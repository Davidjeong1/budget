import SwiftUI
import SwiftData
import LocalAuthentication
import LedgerCore

struct SettingsView: View {
    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]
    @Query private var customCategories: [CustomCategory]

    @State private var settings = AppSettings.shared
    @State private var biometricUnavailableMessage: String?
    @State private var exportedCSV: LedgerCSV?
    @State private var isManagingCategories = false

    private var catalog: CategoryCatalog { CategoryCatalog(customs: customCategories) }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(version)"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ledgerCard
                    appearanceGroup
                    notificationGroup
                    dataGroup
                    appInfo
                }
                .padding(.bottom, 24)
            }
        }
        .alert(
            "생체 인증을 사용할 수 없습니다",
            isPresented: .init(
                get: { biometricUnavailableMessage != nil },
                set: { if !$0 { biometricUnavailableMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(biometricUnavailableMessage ?? "")
        }
    }

    private var headerBar: some View {
        HStack {
            Text("설정")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 16)
    }

    /// The design puts a profile card here. This app has no accounts, so the slot shows what the
    /// ledger actually holds rather than inventing a signed-in user.
    private var ledgerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 20))
                .foregroundStyle(Palette.accent)
                .frame(width: 48, height: 48)
                .background(Palette.track)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("다비드 가계부")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("기록된 내역 \(allTransactions.count)건")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 12)
    }

    // MARK: - 화면

    private var appearanceGroup: some View {
        group("화면") {
            VStack(alignment: .leading, spacing: 12) {
                Text("화면 모드")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textPrimary)

                HStack(spacing: 0) {
                    ForEach(Appearance.allCases) { option in
                        let selected = option == settings.appearance
                        Button {
                            settings.appearance = option
                        } label: {
                            Text(option.label)
                                .font(.system(size: 13, weight: selected ? .bold : .medium))
                                .foregroundStyle(selected ? Palette.accent : Palette.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(selected ? Palette.surfaceRaised : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                    }
                }
                .padding(3)
                .background(Palette.track)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .padding(16)

            divider

            VStack(alignment: .leading, spacing: 12) {
                Text("강조 색")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textPrimary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                    spacing: 12
                ) {
                    ForEach(Palette.accentOptions, id: \.self) { hex in
                        let selected = Int(hex) == settings.accentColorValue
                        Button {
                            settings.accentColorValue = Int(hex)
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Palette.textPrimary, lineWidth: selected ? 2 : 0)
                                        .padding(-3)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(ColorNames.of(hex))
                        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - 알림 및 보안

    private var notificationGroup: some View {
        group("알림 및 보안") {
            toggleRow(title: "매일 저녁 소비 알림", isOn: $settings.dailyReminderEnabled)
                .onChange(of: settings.dailyReminderEnabled) { _, enabled in
                    Task { await NotificationScheduler.setDailyReminder(enabled: enabled) }
                }

            divider

            toggleRow(title: "예산 90% 초과시 알림", isOn: $settings.budgetAlertEnabled)
                .onChange(of: settings.budgetAlertEnabled) { _, enabled in
                    guard enabled else { return }
                    Task { await NotificationScheduler.requestAuthorization() }
                }

            divider

            toggleRow(title: "생체 인증 사용", isOn: $settings.biometricLockEnabled)
                .onChange(of: settings.biometricLockEnabled) { _, enabled in
                    guard enabled else { return }
                    var error: NSError?
                    let context = LAContext()
                    // Turning the lock on without a usable sensor would lock the user out, so the
                    // toggle refuses rather than trusting the preference blindly.
                    if !context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                        settings.biometricLockEnabled = false
                        biometricUnavailableMessage = error?.localizedDescription
                            ?? "이 기기에서 Face ID 또는 암호를 사용할 수 없습니다."
                    }
                }
        }
    }

    // MARK: - 데이터 및 서비스

    private var dataGroup: some View {
        group("데이터 및 서비스") {
            // Built on demand rather than in `body`: eagerly joining the whole ledger into a string
            // on every view update would cost the same whether or not the user ever shares.
            Button {
                exportedCSV = LedgerCSV(transactions: allTransactions, catalog: catalog)
            } label: {
                valueRow(title: "소비 데이터 내보내기", value: "CSV", emphasised: true)
            }
            .buttonStyle(.plain)
            .disabled(allTransactions.isEmpty)
            .sheet(item: $exportedCSV) { csv in
                ShareSheet(csv: csv)
            }

            divider

            Button {
                isManagingCategories = true
            } label: {
                valueRow(
                    title: "카테고리 편집",
                    value: "\(catalog.activeCustoms.count)개",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isManagingCategories) {
                CategoryManagerView()
            }
        }
    }

    private var appInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("버전 정보")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(appVersion)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textTertiary)
            }

            // Absent when the bundle carries no address, rather than showing a link that goes
            // nowhere.
            if let privacyPolicy = AppLinks.privacyPolicy {
                Link("개인정보 처리방침", destination: privacyPolicy)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
                    .underline()
            }

            Text("기록한 내역은 이 기기 안에만 저장됩니다. 외부로 전송되지 않으며, 앱을 삭제하면 함께 지워집니다.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textTertiary)
                .padding(.top, 4)
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 16)
    }

    // MARK: - Building blocks

    /// A titled group whose rows sit in one card, hairlines between them — the design's list shape.
    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textSecondary)

            VStack(spacing: 0) { content() }
                .cardSurface()
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle().fill(Palette.border).frame(height: 1)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Palette.textPrimary)
        }
        .tint(Palette.accent)
        .padding(16)
    }

    private func valueRow(
        title: String,
        value: String,
        emphasised: Bool = false,
        showsChevron: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Palette.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: emphasised ? .bold : .regular))
                .foregroundStyle(emphasised ? Palette.accent : Palette.textSecondary)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
