import SwiftUI
import SwiftData
import LedgerCore

/// 설정 → 카테고리 관리. Adds, edits and archives the user's own categories. The built-in eight are
/// listed read-only, so it is visible which names are already taken and why they cannot be removed.
struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var customCategories: [CustomCategory]

    @State private var editor: Editor?
    /// The name of an archived category whose restore was refused, so the alert can say which one.
    @State private var blockedRestoreName: String?

    private enum Editor: Identifiable {
        case new
        case edit(CustomCategory)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let category): category.uuid.uuidString
            }
        }
    }

    private var catalog: CategoryCatalog { CategoryCatalog(customs: customCategories) }

    private var active: [CustomCategory] {
        customCategories.filter { !$0.isArchived }.sorted { $0.createdAt < $1.createdAt }
    }

    private var archived: [CustomCategory] {
        customCategories.filter(\.isArchived).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    mineSection
                    if !archived.isEmpty { archivedSection }
                    builtinSection
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .background(Palette.background)
            .navigationTitle("카테고리 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { editor = .new } label: { Image(systemName: "plus") }
                        .accessibilityLabel("카테고리 추가")
                }
            }
            .alert(
                "복원할 수 없습니다",
                isPresented: Binding(
                    get: { blockedRestoreName != nil },
                    set: { if !$0 { blockedRestoreName = nil } }
                ),
                presenting: blockedRestoreName
            ) { _ in
                Button("확인", role: .cancel) {}
            } message: { name in
                Text("'\(name)'와 같은 이름의 카테고리가 이미 있습니다. 그 카테고리의 이름을 먼저 바꾼 뒤 복원해 주세요.")
            }
            .sheet(item: $editor) { destination in
                switch destination {
                case .new:
                    CategoryEditorSheet(catalog: catalog, existing: nil, onSave: create)
                case .edit(let category):
                    CategoryEditorSheet(catalog: catalog, existing: category) { draft in
                        apply(draft, to: category)
                    }
                }
            }
        }
    }

    private var mineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "내 카테고리")

            if active.isEmpty {
                EmptyStateView(
                    title: "추가한 카테고리가 없습니다",
                    message: "오른쪽 위 + 를 눌러 원하는 카테고리를 만들어 보세요."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(active) { category in
                        Button { editor = .edit(category) } label: {
                            categoryRow(
                                LedgerCategory(custom: category),
                                trailing: category.isIncome ? "수입" : "지출",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("삭제", role: .destructive) { archive(category) }
                        }
                    }
                }

                Text("삭제해도 이미 기록된 내역은 그대로 남고, 그 카테고리의 이름과 색으로 계속 표시됩니다.")
                    .font(.captionSmall)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "보관됨")

            VStack(spacing: 10) {
                ForEach(archived) { category in
                    HStack(spacing: 12) {
                        categoryRow(LedgerCategory(custom: category), trailing: nil, showsChevron: false)
                        Button("복원") { restore(category) }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
            }

            Text("복원하면 새 내역에서 다시 선택할 수 있습니다.")
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var builtinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "기본 카테고리")

            VStack(spacing: 10) {
                ForEach(Category.allCases) { builtin in
                    categoryRow(
                        LedgerCategory(builtin: builtin),
                        trailing: builtin.isIncome ? "수입" : "지출",
                        showsChevron: false
                    )
                }
            }

            Text("기본 카테고리는 이름과 색을 바꾸거나 삭제할 수 없습니다.")
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private func categoryRow(
        _ category: LedgerCategory,
        trailing: String?,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(category: category, size: 32)

            Text(category.label)
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.captionSmall)
                    .foregroundStyle(Palette.textTertiary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardSurface(cornerRadius: 12)
    }

    private func create(_ draft: CategoryDraft) {
        context.insert(
            CustomCategory(
                name: draft.name,
                symbolName: draft.symbolName,
                colorValue: draft.colorValue,
                isIncome: draft.isIncome
            )
        )
    }

    private func apply(_ draft: CategoryDraft, to category: CustomCategory) {
        category.name = draft.name
        category.symbolName = draft.symbolName
        category.colorValue = draft.colorValue
        category.isIncome = draft.isIncome
    }

    /// Archives instead of deleting, so transactions already filed under this category keep
    /// rendering with the name, icon and colour they were recorded with.
    private func archive(_ category: CustomCategory) {
        withAnimation { category.isArchived = true }
    }

    /// The duplicate-name check the editor runs only looks at categories that are not archived —
    /// which is right, because an archived one is not offered anywhere. But it means the name of an
    /// archived category is free to take, and taking it makes this restore produce two cards
    /// reading 반려동물 side by side in the picker with nothing to tell them apart.
    ///
    /// Refused rather than renamed on the way back in: the name is the user's, and picking a new
    /// one for them is not this button's decision.
    private func restore(_ category: CustomCategory) {
        guard !catalog.nameIsTaken(category.name, excluding: category.raw) else {
            blockedRestoreName = category.name
            return
        }
        withAnimation { category.isArchived = false }
    }
}

/// The values the editor collects. A plain struct rather than a half-built `CustomCategory`, so
/// cancelling cannot leave an empty row inserted in the store.
struct CategoryDraft {
    var name: String
    var symbolName: String
    var colorValue: Int
    var isIncome: Bool
}

private struct CategoryEditorSheet: View {
    let catalog: CategoryCatalog
    /// nil when creating.
    let existing: CustomCategory?
    let onSave: (CategoryDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var symbolName = CategoryStyle.symbols[0]
    @State private var colorValue = Int(CategoryStyle.colors[0])
    @State private var isIncome = false
    @State private var didLoad = false
    /// The name field is the only thing here that takes a keyboard, and the 완료 accessory below is
    /// what gives it back.
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var isDuplicate: Bool {
        catalog.nameIsTaken(trimmedName, excluding: existing?.raw)
    }

    private var canSave: Bool { !trimmedName.isEmpty && !isDuplicate }

    private var selectedColor: Color { Color(hex: UInt32(truncatingIfNeeded: colorValue)) }

    private var preview: LedgerCategory {
        LedgerCategory(
            draft: trimmedName.isEmpty ? "새 카테고리" : trimmedName,
            symbolName: symbolName,
            colorHex: UInt32(truncatingIfNeeded: colorValue),
            isIncome: isIncome
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    previewRow
                    nameField
                    modeToggle
                    symbolGrid
                    colorGrid
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background)
            .navigationTitle(existing == nil ? "카테고리 추가" : "카테고리 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { isNameFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(
                            CategoryDraft(
                                name: trimmedName,
                                symbolName: symbolName,
                                colorValue: colorValue,
                                isIncome: isIncome
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private var previewRow: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: preview, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(preview.label)
                    .font(.rowTitle)
                    .foregroundStyle(trimmedName.isEmpty ? Palette.textTertiary : Palette.textPrimary)
                Text(isIncome ? "수입 카테고리" : "지출 카테고리")
                    .font(.captionSmall)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이름").font(.sectionTitle).foregroundStyle(Palette.textPrimary)
            TextField("예: 반려동물", text: $name)
                .focused($isNameFocused)
                // A 한글 keyboard's return key only commits the composition, so without these the
                // field keeps the keyboard and it covers the 저장 button.
                .submitLabel(.done)
                .onSubmit { isNameFocused = false }
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDuplicate ? Palette.expense : Palette.border, lineWidth: 1)
                )

            if isDuplicate {
                Text("같은 이름의 카테고리가 이미 있습니다.")
                    .font(.captionSmall)
                    .foregroundStyle(Palette.expense)
            }
        }
    }

    private var modeToggle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("구분").font(.sectionTitle).foregroundStyle(Palette.textPrimary)

            HStack(spacing: 0) {
                modeButton(title: "지출", selected: !isIncome) { isIncome = false }
                modeButton(title: "수입", selected: isIncome) { isIncome = true }
            }
            .padding(4)
            .cardSurface(cornerRadius: 12)
        }
    }

    private func modeButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Palette.textPrimary : Palette.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Palette.background : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private var symbolGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("아이콘").font(.sectionTitle).foregroundStyle(Palette.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(CategoryStyle.symbols, id: \.self) { symbol in
                    let selected = symbol == symbolName
                    Button { symbolName = symbol } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selected ? selectedColor : Palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selected
                                    ? selectedColor.opacity(0.12)
                                    : Palette.surface
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    selected ? selectedColor : Palette.border,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                }
            }
        }
    }

    private var colorGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("색상").font(.sectionTitle).foregroundStyle(Palette.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(CategoryStyle.colors, id: \.self) { hex in
                    let selected = Int(hex) == colorValue
                    Button { colorValue = Int(hex) } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Palette.textPrimary, lineWidth: selected ? 2 : 0)
                                    .padding(-3)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: "#%06X", hex))
                }
            }
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing else { return }
        name = existing.name
        symbolName = existing.symbolName
        colorValue = existing.colorValue
        isIncome = existing.isIncome
    }
}

/// The icon and colour choices offered for a user category. Deliberately a short curated list: an
/// open SF Symbols search would surface glyphs that do not match the rest of the app.
enum CategoryStyle {
    static let symbols = [
        "cart.fill", "fork.knife", "cup.and.saucer.fill", "bus.fill", "car.fill",
        "house.fill", "tag.fill", "gift.fill", "heart.fill", "cross.case.fill",
        "book.fill", "graduationcap.fill", "pawprint.fill", "gamecontroller.fill", "airplane",
        "dumbbell.fill", "scissors", "wrench.and.screwdriver.fill", "creditcard.fill", "wonsign.circle.fill",
    ]

    static let colors: [UInt32] = [
        0x4F46E5, 0x3B82F6, 0x0EA5E9, 0x14B8A6, 0x10B981, 0x84CC16,
        0xF59E0B, 0xF97316, 0xEF4444, 0xEC4899, 0xA855F7, 0x6B7280,
    ]
}
