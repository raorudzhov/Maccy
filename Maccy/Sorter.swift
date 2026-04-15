import AppKit
import Defaults

// swiftlint:disable identifier_name
// swiftlint:disable type_name
class Sorter {
  enum By: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
    case lastCopiedAt
    case firstCopiedAt
    case numberOfCopies

    var id: Self { self }

    var description: String {
      switch self {
      case .lastCopiedAt:
        return NSLocalizedString("LastCopiedAt", tableName: "StorageSettings", comment: "")
      case .firstCopiedAt:
        return NSLocalizedString("FirstCopiedAt", tableName: "StorageSettings", comment: "")
      case .numberOfCopies:
        return NSLocalizedString("NumberOfCopies", tableName: "StorageSettings", comment: "")
      }
    }
  }

  func sort(_ items: [HistoryItem], by: By = Defaults[.sortBy]) -> [HistoryItem] {
    items.sorted { lhs, rhs in
      if let lhsBeforeRhs = comparePinnedGroups(lhs, rhs) {
        return lhsBeforeRhs
      }

      if lhs.pin != nil, rhs.pin != nil, lhs.pinSortIndex != rhs.pinSortIndex {
        return lhs.pinSortIndex < rhs.pinSortIndex
      }

      return bySortingAlgorithm(lhs, rhs, by)
    }
  }

  /// `true` if `lhs` should be ordered before `rhs`; `nil` if both are in the same pinned / unpinned group.
  private func comparePinnedGroups(_ lhs: HistoryItem, _ rhs: HistoryItem) -> Bool? {
    let lhsPinned = lhs.pin != nil
    let rhsPinned = rhs.pin != nil
    if lhsPinned == rhsPinned {
      return nil
    }

    if Defaults[.pinTo] == .bottom {
      // Unpinned first, then pinned.
      return !lhsPinned && rhsPinned
    }
    // Pinned first, then unpinned.
    return lhsPinned && !rhsPinned
  }

  private func bySortingAlgorithm(_ lhs: HistoryItem, _ rhs: HistoryItem, _ by: By) -> Bool {
    switch by {
    case .firstCopiedAt:
      return lhs.firstCopiedAt > rhs.firstCopiedAt
    case .numberOfCopies:
      return lhs.numberOfCopies > rhs.numberOfCopies
    default:
      return lhs.lastCopiedAt > rhs.lastCopiedAt
    }
  }
}
// swiftlint:enable identifier_name
// swiftlint:enable type_name
