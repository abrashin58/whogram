enum HistoryPage: Equatable {
    case older(Int64)
    case end

    static func progress(ids: [Int64], from cursor: Int64) -> Self {
        guard let oldest = ids.filter({ $0 > 0 && (cursor == 0 || $0 < cursor) }).min() else {
            return .end
        }
        return .older(oldest)
    }
}
