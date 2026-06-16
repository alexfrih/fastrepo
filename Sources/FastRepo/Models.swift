import Foundation

// A unified, searchable entry: either a repo or an org.
struct Item: Codable, Identifiable, Sendable, Hashable {
    enum Kind: String, Codable, Sendable { case repo, org }
    let id: String          // html url (stable + unique)
    let kind: Kind
    let title: String       // repo name / org login
    let subtitle: String    // owner login / "Organization"
    let url: String
    let isPrivate: Bool
    let pushedAt: String?    // ISO8601, repos only
}

// GitHub API decoding shapes.
struct GHOwner: Decodable { let login: String }
struct GHRepo: Decodable {
    let name: String
    let full_name: String
    let html_url: String
    let `private`: Bool
    let pushed_at: String?
    let owner: GHOwner
}
struct GHOrg: Decodable { let login: String }

extension Item {
    init(repo: GHRepo) {
        self.init(id: repo.html_url, kind: .repo, title: repo.name,
                  subtitle: repo.owner.login, url: repo.html_url,
                  isPrivate: repo.`private`, pushedAt: repo.pushed_at)
    }
    init(org: GHOrg) {
        let url = "https://github.com/\(org.login)"
        self.init(id: url, kind: .org, title: org.login,
                  subtitle: "Organization", url: url, isPrivate: false, pushedAt: nil)
    }
}

enum GHError: Error { case noToken, unauthorized, status(Int), network }

// Fuzzy search + ranking, mirrors the extension's scoring.
enum Search {
    static func filter(_ items: [Item], _ query: String) -> [Item] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return Array(items.prefix(100)) }
        return items
            .compactMap { it -> (Item, Int)? in
                let s = score(it, q)
                return s > 0 ? (it, s) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(100)
            .map { $0.0 }
    }

    private static func score(_ it: Item, _ q: String) -> Int {
        let t = it.title.lowercased()
        let full = (it.subtitle + "/" + it.title).lowercased()
        if t == q { return 1000 }
        if t.hasPrefix(q) { return 800 }
        if full.hasPrefix(q) { return 700 }
        if t.contains(q) { return 500 }
        if full.contains(q) { return 300 }
        if subseq(full, q) { return 60 }
        return 0
    }

    private static func subseq(_ text: String, _ q: String) -> Bool {
        var i = q.startIndex
        for c in text {
            if i == q.endIndex { break }
            if c == q[i] { i = q.index(after: i) }
        }
        return i == q.endIndex
    }
}

enum RelTime {
    private static let iso = ISO8601DateFormatter()
    static func short(_ s: String?) -> String {
        guard let s = s, let d = iso.date(from: s) else { return "" }
        let secs = Int(Date().timeIntervalSince(d))
        if secs < 60 { return "now" }
        let m = secs / 60; if m < 60 { return "\(m)m" }
        let h = m / 60; if h < 24 { return "\(h)h" }
        let dd = h / 24; if dd < 30 { return "\(dd)d" }
        let mo = dd / 30; if mo < 12 { return "\(mo)mo" }
        return "\(mo / 12)y"
    }
}

enum Cache {
    private static let key = "fastrepo.items"
    static func save(_ items: [Item]) {
        if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: key) }
    }
    static func load() -> [Item] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let a = try? JSONDecoder().decode([Item].self, from: d) else { return [] }
        return a
    }
}
