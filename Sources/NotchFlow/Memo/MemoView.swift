import SwiftUI
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

struct MemoView: View {
    @ObservedObject var model: MemoViewModel
    @State private var checklistText = ""
    @State private var deleteID: UUID?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text("Quick Memo")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text(model.saved ? "저장됨" : "저장 중…").font(.caption).foregroundStyle(.secondary)
                    Button { model.create() } label: { Image(systemName: "plus") }
                        .buttonStyle(NotchIconButtonStyle())
                        .help("새 메모")
                        .accessibilityLabel("새 메모")
                        .disabled(!model.writable)
                }
                if !model.memos.isEmpty {
                    Picker("최근 메모", selection: $model.selectedID) {
                        ForEach(model.recent) { memo in Text((memo.pinned ? "📌 " : "") + String(memo.title.prefix(30))).tag(Optional(memo.id)) }
                    }
                }
                if let memo = model.selected {
                    HStack {
                        Button { model.update { $0.pinned.toggle() } } label: { Label(memo.pinned ? "고정 해제" : "고정", systemImage: memo.pinned ? "pin.fill" : "pin") }
                        Spacer()
                        Button(role: .destructive) { deleteID = memo.id } label: { Image(systemName: "trash") }
                            .buttonStyle(NotchIconButtonStyle())
                            .help("메모 삭제")
                            .accessibilityLabel("메모 삭제")
                    }
                    TextEditor(text: Binding(get: { model.selected?.text ?? "" }, set: { value in model.update { $0.text = value } }))
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .frame(minHeight: 70, maxHeight: 100)
                        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                        .id(memo.id)
                    ForEach(memo.checklist) { item in
                        HStack {
                            Toggle(isOn: Binding(get: { model.selected?.checklist.first { $0.id == item.id }?.done ?? false }, set: { value in model.update { memo in if let index = memo.checklist.firstIndex(where: { $0.id == item.id }) { memo.checklist[index].done = value } } })) { Text(item.text).strikethrough(item.done).foregroundStyle(item.done ? .secondary : .primary) }.toggleStyle(.checkbox)
                            Spacer()
                            Button { model.update { $0.checklist.removeAll { $0.id == item.id } } } label: { Image(systemName: "minus.circle") }.buttonStyle(NotchIconButtonStyle()).accessibilityLabel("체크리스트 항목 제거")
                        }
                    }
                    HStack {
                        TextField("체크리스트 항목", text: $checklistText).onSubmit { addItem() }
                        Button { addItem() } label: { Image(systemName: "plus.circle.fill") }.buttonStyle(NotchIconButtonStyle()).accessibilityLabel("체크리스트 항목 추가").disabled(checklistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    ContentUnavailableView("생각을 놓치지 마세요", systemImage: "square.and.pencil", description: Text("+ 버튼으로 첫 메모를 만드세요."))
                }
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.orange); Button("저장 재시도") { model.flush() }.disabled(!model.writable) }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .disabled(!model.writable)
        .onDisappear { model.flush() }
        .confirmationDialog("이 메모를 삭제할까요?", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) { Button("메모 삭제", role: .destructive) { if let deleteID { model.delete(deleteID) }; deleteID = nil } }
    }

    private func addItem() {
        let value = checklistText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        model.update { $0.checklist.append(ChecklistItem(text: value)) }
        checklistText = ""
    }
}
