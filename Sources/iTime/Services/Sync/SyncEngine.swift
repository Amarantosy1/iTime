import Foundation

public enum SyncEngine {
    public static func merge<Value: Codable & Equatable & Sendable>(
        local: [SyncRecord<Value>],
        remote: [SyncRecord<Value>]
    ) -> [SyncRecord<Value>] {
        var map = Dictionary(uniqueKeysWithValues: local.map { ($0.recordID, $0) })
        for candidate in remote {
            guard let existing = map[candidate.recordID] else {
                map[candidate.recordID] = candidate
                continue
            }
            map[candidate.recordID] = pickWinner(lhs: existing, rhs: candidate)
        }
        return map.values.sorted { $0.recordID < $1.recordID }
    }

    private static func pickWinner<Value: Codable & Equatable & Sendable>(
        lhs: SyncRecord<Value>,
        rhs: SyncRecord<Value>
    ) -> SyncRecord<Value> {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt ? lhs : rhs
        }
        if lhs.version != rhs.version {
            return lhs.version > rhs.version ? lhs : rhs
        }
        if lhs.deletedAt != rhs.deletedAt {
            switch (lhs.deletedAt, rhs.deletedAt) {
            case (.some(let l), .some(let r)):
                return l >= r ? lhs : rhs
            case (.some, .none):
                return lhs
            case (.none, .some):
                return rhs
            case (.none, .none):
                break
            }
        }
        return lhs.recordID >= rhs.recordID ? lhs : rhs
    }
}
