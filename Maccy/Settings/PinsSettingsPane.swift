import AppKit
import SwiftData
import SwiftUI

fileprivate enum PinEditorFocus: Hashable {
  case title(PersistentIdentifier)
  case content(PersistentIdentifier)
}

struct PinPickerView: View {
  @Bindable var item: HistoryItem
  var availablePins: [String]

  var body: some View {
    if item.pin != nil {
      PinKeyPickerInner(item: item, availablePins: availablePins, selection: $item.pin)
    }
  }
}

private struct PinKeyPickerInner: View {
  @Bindable var item: HistoryItem
  var availablePins: [String]
  @Binding var selection: String?

  var body: some View {
    let letterChoices: Set<String> = {
      var set = Set(availablePins)
      if let p = item.pin, !p.isEmpty {
        set.insert(p)
      }
      return set
    }()
    let sortedLetters = letterChoices.sorted()

    Picker("", selection: $selection) {
      Text("PinKeyNone", tableName: "PinsSettings")
        .tag(Optional.some("") as String?)
      ForEach(sortedLetters, id: \.self) { letter in
        Text(letter)
          .tag(Optional.some(letter) as String?)
      }
    }
    .controlSize(.small)
    .labelsHidden()
  }
}

fileprivate struct PinTitleView: View {
  @Bindable var item: HistoryItem
  @FocusState.Binding var editorFocus: PinEditorFocus?

  var body: some View {
    TextField("", text: $item.title)
      .focused($editorFocus, equals: .title(item.persistentModelID))
  }
}

fileprivate struct PinValueView: View {
  @Bindable var item: HistoryItem
  @FocusState.Binding var editorFocus: PinEditorFocus?
  @State private var editableValue: String
  @State private var isTextContent: Bool
  @State private var isRichText: Bool

  private var isContentFieldFocused: Bool {
    editorFocus == .content(item.persistentModelID)
  }

  init(item: HistoryItem, editorFocus: FocusState<PinEditorFocus?>.Binding) {
    self.item = item
    self._editorFocus = editorFocus
    self._editableValue = State(initialValue: item.previewableText)

    // Check if this item has editable text content
    let hasPlainText = item.text != nil
    let hasImage = item.image != nil
    let hasFileURLs = !item.fileURLs.isEmpty
    let hasRichText = item.rtf != nil || item.html != nil

    // Consider it text content only if it has plain text and doesn't have images or file URLs
    self._isTextContent = State(initialValue: hasPlainText && !hasImage && !hasFileURLs)
    self._isRichText = State(initialValue: hasRichText && !hasImage && !hasFileURLs)
  }

  var body: some View {
    Group {
      if isTextContent || isRichText {
        ZStack(alignment: .trailing) {
          TextField("", text: $editableValue)
            .focused($editorFocus, equals: .content(item.persistentModelID))
            .onSubmit {
              updateItemContent()
            }
            .onChange(of: editableValue) { _, _ in
              updateItemContent()
            }
            .padding(.trailing, isRichText ? 40 : 0) // increased space for icon

          if isRichText && isContentFieldFocused {
            HStack(spacing: 0) {
              Spacer(minLength: 0)
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .help(Text("RichTextEditWarning", tableName: "PinsSettings"))
              Spacer().frame(width: 4)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.trailing, 4)
          }
        }
      } else {
        // Non-editable display for non-text content
        Text("ContentIsNotText", tableName: "PinsSettings")
          .foregroundStyle(.secondary)
          .italic()
      }
    }
  }

  private func updateItemContent() {
    // Only update if we're dealing with text or rich text content
    guard isTextContent || isRichText else { return }

    // Remove all non-plain-text content
    let stringType = NSPasteboard.PasteboardType.string.rawValue
    item.contents.removeAll { $0.type != stringType }

    // Update or add the plain text content
    if let index = item.contents.firstIndex(where: { $0.type == stringType }) {
      if let data = editableValue.data(using: .utf8) {
        item.contents[index].value = data
      }
    } else {
      if let data = editableValue.data(using: .utf8) {
        let newContent = HistoryItemContent(type: stringType, value: data)
        item.contents.append(newContent)
      }
    }
    // We don't automatically update title here since we want to preserve
    // OCR-extracted titles for images and other non-text content
  }
}

struct PinsSettingsPane: View {
  private static let pinKeyColumnWidth: CGFloat = 76

  @Environment(AppState.self) private var appState

  @Query(
    filter: #Predicate<HistoryItem> { $0.pin != nil },
    sort: [
      SortDescriptor(\HistoryItem.pinSortIndex),
      SortDescriptor(\HistoryItem.firstCopiedAt, order: .reverse)
    ]
  )
  private var items: [HistoryItem]

  @State private var availablePins: [String] = []
  @State private var selection: PersistentIdentifier?
  @FocusState private var editorFocus: PinEditorFocus?

  private var selectedRowIndex: Int? {
    guard let selection else {
      return nil
    }
    return items.firstIndex(where: { $0.persistentModelID == selection })
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Spacer()
        Button {
          addPin()
        } label: {
          Label {
            Text("AddPin", tableName: "PinsSettings")
          } icon: {
            Image(systemName: "plus")
          }
        }
        .help(Text("AddPinTooltip", tableName: "PinsSettings"))

        Button {
          removeSelectedPin()
        } label: {
          Label {
            Text("RemovePin", tableName: "PinsSettings")
          } icon: {
            Image(systemName: "minus")
          }
        }
        .help(Text("RemovePinTooltip", tableName: "PinsSettings"))
        .disabled(selection == nil)

        Button {
          moveSelected(by: -1)
        } label: {
          Label {
            Text("MovePinUp", tableName: "PinsSettings")
          } icon: {
            Image(systemName: "chevron.up")
          }
        }
        .help(Text("MovePinUpTooltip", tableName: "PinsSettings"))
        .disabled(selectedRowIndex == nil || selectedRowIndex == 0)

        Button {
          moveSelected(by: 1)
        } label: {
          Label {
            Text("MovePinDown", tableName: "PinsSettings")
          } icon: {
            Image(systemName: "chevron.down")
          }
        }
        .help(Text("MovePinDownTooltip", tableName: "PinsSettings"))
        .disabled(selectedRowIndex == nil || selectedRowIndex == items.count - 1)
      }

      // `Table` keeps cell hit-testing so TextFields receive clicks; `List` selection steals the first click.
      Table(items, selection: $selection) {
        TableColumn(Text("Key", tableName: "PinsSettings")) { item in
          PinPickerView(item: item, availablePins: availablePins)
            .onChange(of: item.pin) {
              availablePins = HistoryItem.availablePins
            }
        }
        .width(Self.pinKeyColumnWidth)

        TableColumn(Text("Alias", tableName: "PinsSettings")) { item in
          PinTitleView(item: item, editorFocus: $editorFocus)
        }

        TableColumn(Text("Content", tableName: "PinsSettings")) { item in
          PinValueView(item: item, editorFocus: $editorFocus)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .overlay {
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
      }
      .onAppear {
        availablePins = HistoryItem.availablePins
      }
      .onDeleteCommand {
        removeSelectedPin()
      }

      Text("PinCustomizationDescription", tableName: "PinsSettings")
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
    .frame(minWidth: 500, minHeight: 400)
    .padding()
  }

  private func addPin() {
    let stringType = NSPasteboard.PasteboardType.string.rawValue
    let placeholder = NSLocalizedString("NewPinContent", tableName: "PinsSettings", comment: "")
    let content = HistoryItemContent(
      type: stringType,
      value: placeholder.data(using: .utf8)
    )
    let newItem = HistoryItem(contents: [content])
    // Pinned without a shortcut by default; user can assign a letter in the Key column.
    newItem.pin = ""
    newItem.pinSortIndex = HistoryItem.nextPinSortIndex()
    newItem.title = NSLocalizedString("NewPinTitle", tableName: "PinsSettings", comment: "")

    if #unavailable(macOS 15.0) {
      try? appState.history.insertIntoStorage(newItem)
    }
    _ = appState.history.add(newItem, mergeSimilarItems: false)
    availablePins = HistoryItem.availablePins

    let newId = newItem.persistentModelID
    selection = newId
    DispatchQueue.main.async {
      editorFocus = .title(newId)
    }
  }

  private func removeSelectedPin() {
    guard let selection,
          let decorator = appState.history.all.first(where: { $0.item.persistentModelID == selection }) else {
      return
    }

    appState.history.delete(decorator)
    self.selection = nil
    availablePins = HistoryItem.availablePins
    normalizePinSortIndicesIfNeeded()
  }

  private func moveSelected(by offset: Int) {
    guard let idx = selectedRowIndex else {
      return
    }
    let newIdx = idx + offset
    guard newIdx >= 0, newIdx < items.count else {
      return
    }
    var ordered = Array(items)
    ordered.swapAt(idx, newIdx)
    for (i, item) in ordered.enumerated() {
      item.pinSortIndex = i
    }
    try? Storage.shared.context.save()
    appState.history.refreshSortOrder()
  }

  /// After deleting a pin, pack indices 0..<n so order stays stable.
  private func normalizePinSortIndicesIfNeeded() {
    let descriptor = FetchDescriptor<HistoryItem>(
      predicate: #Predicate { $0.pin != nil },
      sortBy: [
        SortDescriptor(\HistoryItem.pinSortIndex),
        SortDescriptor(\HistoryItem.firstCopiedAt, order: .reverse)
      ]
    )
    guard let pinned = try? Storage.shared.context.fetch(descriptor) else {
      return
    }
    for (i, item) in pinned.enumerated() where item.pinSortIndex != i {
      item.pinSortIndex = i
    }
    try? Storage.shared.context.save()
    appState.history.refreshSortOrder()
  }
}

#Preview {
  return PinsSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
