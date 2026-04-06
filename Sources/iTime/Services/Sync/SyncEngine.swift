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
        // 如果有一个是被删除的，直接返回被删除的状态（如果两个都删除了，取最新的删除时间对应的那条）
        if lhs.isDeleted || rhs.isDeleted {
            if lhs.isDeleted && rhs.isDeleted {
                // 如果都有 deletedAt，取 deletedAt 较新的。或者 fallback 到 updatedAt 等
                let lDeletedTime = lhs.deletedAt ?? .distantPast
                let rDeletedTime = rhs.deletedAt ?? .distantPast
                if lDeletedTime != rDeletedTime {
                    return lDeletedTime > rDeletedTime ? lhs : rhs
                }
            } else if lhs.isDeleted {
                return lhs
            } else {
                return rhs
            }
        }
        
        // 都没有被删除的情况下，如果是相同项目有了编辑，以最新的编辑为主
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt ? lhs : rhs
        }
        if lhs.version != rhs.version {
            return lhs.version > rhs.version ? lhs : rhs
        }
        return lhs.recordID >= rhs.recordID ? lhs : rhs
    }
}
