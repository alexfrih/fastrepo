import Foundation

// Owns all GitHub API access: fetches orgs + every accessible repo
// (owned, org, collaborator) and caches the unified list.
actor GitHubClient {
    func sync() async throws -> [Item] {
        guard let token = Keychain.get() else { throw GHError.noToken }
        var items: [Item] = []

        let orgs: [GHOrg] = try await get("/user/orgs?per_page=100", token)
        items += orgs.map { Item(org: $0) }

        for page in 1...25 { // up to 2500 repos
            let path = "/user/repos?per_page=100&page=\(page)" +
                "&affiliation=owner,collaborator,organization_member&sort=pushed&direction=desc"
            let batch: [GHRepo] = try await get(path, token)
            items += batch.map { Item(repo: $0) }
            if batch.count < 100 { break }
        }

        Cache.save(items)
        return items
    }

    private func get<T: Decodable>(_ path: String, _ token: String) async throws -> T {
        guard let url = URL(string: "https://api.github.com" + path) else { throw GHError.network }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GHError.network }
        if http.statusCode == 401 { throw GHError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw GHError.status(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
