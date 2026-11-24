import Foundation

enum VoiceWaveform {
    static func pack(_ samples: [UInt8]) -> Data {
        var bytes = [UInt8](repeating: 0, count: (samples.count * 5 + 7) / 8)
        for (index, sample) in samples.enumerated() {
            let offset = index * 5
            let value = UInt16(min(sample, 31)) << (offset % 8)
            bytes[offset / 8] |= UInt8(truncatingIfNeeded: value)
            if offset % 8 > 3 { bytes[offset / 8 + 1] |= UInt8(value >> 8) }
        }
        return Data(bytes)
    }

    static func unpack(_ data: Data) -> [UInt8] {
        let bytes = Array(data.prefix(125))
        return (0..<(bytes.count * 8 / 5)).map { index in
            let offset = index * 5
            let first = UInt16(bytes[offset / 8])
            let second = offset / 8 + 1 < bytes.count ? UInt16(bytes[offset / 8 + 1]) << 8 : 0
            return UInt8(((first | second) >> (offset % 8)) & 31)
        }
    }

    static func resample(_ samples: [UInt8], count: Int) -> [UInt8] {
        guard !samples.isEmpty && count > 0 else { return [] }
        return (0..<count).map { index in
            let from = index * samples.count / count
            let to = max(from + 1, (index + 1) * samples.count / count)
            return samples[from..<to].max() ?? 0
        }
    }
}
