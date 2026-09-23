import Cocoa

/// Checks GitHub Releases for a newer XMRMenuCalc and installs it in place.
/// Only runs when the user asks; the only request goes to api.github.com / github.com.
final class Updater {
    static let shared = Updater()

    private let repo = "brainchainz/XMRMenuCalc"
    private let assetName = "XMRMenuCalc.dmg"
    private var busy = false

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    // MARK: - Check

    func checkForUpdates() {
        guard !busy else { return }
        busy = true
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("XMRMenuCalc/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.busy = false
                guard error == nil, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else {
                    self.alert("Couldn't check for updates",
                               "GitHub could not be reached. Please try again later.")
                    return
                }
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                guard Self.isNewer(latest, than: self.currentVersion) else {
                    self.alert("You're up to date",
                               "XMRMenuCalc \(self.currentVersion) is the latest version.")
                    return
                }
                let assets = json["assets"] as? [[String: Any]] ?? []
                let dmg = assets.first { ($0["name"] as? String) == self.assetName }
                let dmgURL = (dmg?["browser_download_url"] as? String).flatMap(URL.init(string:))
                let page = (json["html_url"] as? String).flatMap(URL.init(string:))
                let notes = (json["body"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                self.offer(version: latest, notes: notes, dmgURL: dmgURL, page: page)
            }
        }.resume()
    }

    /// Numeric dotted-version compare: "1.10.0" > "1.9.2".
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - Offer / install

    private func offer(version: String, notes: String, dmgURL: URL?, page: URL?) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "XMRMenuCalc \(version) is available"
        let shortNotes = notes.count > 600 ? String(notes.prefix(600)) + "…" : notes
        a.informativeText = "You have \(currentVersion).\n\n\(shortNotes)"
        a.addButton(withTitle: dmgURL != nil ? "Install and Relaunch" : "Open Download Page")
        a.addButton(withTitle: "Later")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        if let dmgURL = dmgURL { install(from: dmgURL, fallback: page) }
        else if let page = page { NSWorkspace.shared.open(page) }
    }

    private func install(from dmgURL: URL, fallback page: URL?) {
        busy = true
        URLSession.shared.downloadTask(with: dmgURL) { [weak self] tmp, _, error in
            guard let self = self else { return }
            let fail: (String) -> Void = { msg in
                DispatchQueue.main.async {
                    self.busy = false
                    self.alert("Update failed", msg + "\n\nYou can download it manually from the release page.")
                    if let page = page { NSWorkspace.shared.open(page) }
                }
            }
            guard error == nil, let tmp = tmp else { return fail("The download didn't finish.") }
            do {
                try self.replaceApp(withDMGAt: tmp)
            } catch {
                fail(error.localizedDescription)
            }
        }.resume()
    }

    private struct UpdateError: LocalizedError {
        let errorDescription: String?
        init(_ s: String) { errorDescription = s }
    }

    @discardableResult
    private func run(_ path: String, _ args: [String]) -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        do { try p.run() } catch { return (-1, error.localizedDescription) }
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, out)
    }

    private func replaceApp(withDMGAt downloaded: URL) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("XMRMenuCalcUpdate-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        let dmg = work.appendingPathComponent(assetName)
        try fm.moveItem(at: downloaded, to: dmg)
        let mount = work.appendingPathComponent("mnt")

        let (st, out) = run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen",
                                                 "-mountpoint", mount.path])
        guard st == 0 else { throw UpdateError("Couldn't open the disk image. \(out)") }
        defer { run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }

        let newApp = mount.appendingPathComponent("XMRMenuCalc.app")
        guard let newBundle = Bundle(url: newApp),
              newBundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError("The download doesn't contain a valid XMRMenuCalc.app.")
        }

        // Stage next to the running app so the final swap is a same-volume rename.
        let current = URL(fileURLWithPath: Bundle.main.bundlePath)
        let staged = current.deletingLastPathComponent().appendingPathComponent(".XMRMenuCalc-update.app")
        try? fm.removeItem(at: staged)
        let (cst, cout) = run("/usr/bin/ditto", [newApp.path, staged.path])
        guard cst == 0 else {
            throw UpdateError("Couldn't write to \(current.deletingLastPathComponent().path). \(cout)")
        }
        run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path])

        // Swap after we quit, then relaunch the new version.
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(current.path)" && mv "\(staged.path)" "\(current.path)" && open "\(current.path)"
        rm -rf "\(work.path)"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script]
        try p.run()

        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }
}
