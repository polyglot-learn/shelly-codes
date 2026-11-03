import Foundation

/// Finds the word a child probably meant, for "Did you mean ...?" messages.
nonisolated enum Suggest {
    /// Edit distance where swapping two neighbouring letters counts as one edit.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
                }
            }
        }
        return d[a.count][b.count]
    }

    /// The closest candidate, if it's close enough to be a likely typo.
    static func closest(to word: String, in candidates: some Sequence<String>) -> String? {
        let lower = word.lowercased()
        var best: (String, Int)?
        for candidate in candidates where candidate != word {
            let d = candidate.lowercased() == lower ? 0 : distance(lower, candidate.lowercased())
            if best == nil || d < best!.1 || (d == best!.1 && candidate < best!.0) {
                best = (candidate, d)
            }
        }
        guard let (candidate, d) = best else { return nil }
        let allowed = word.count <= 3 ? 1 : 2
        return d <= allowed ? candidate : nil
    }
}
