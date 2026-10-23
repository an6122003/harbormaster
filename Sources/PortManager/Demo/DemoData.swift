import Foundation

/// Fictional sample data for `--demo` mode. Everything here is made up —
/// project names, paths, PIDs — and none of it is ever sent to a real process.
enum DemoData {
    static let lanIP = "192.168.1.42"

    // MARK: - Ports

    static func ports() -> [PortInfo] {
        var result: [PortInfo] = []

        func web(
            _ port: Int, pid: Int32, name: String, command: String, project: String,
            title: String = "", status: Int = 200, contentType: String = "text/html; charset=utf-8",
            server: String = "", bind: String = "127.0.0.1", memoryMB: Double, latency: Double,
            uptime: String, started: String, connections: Int, env: String = "", version: String = "",
            headers: [String: String] = [:]
        ) {
            var info = PortInfo(port: port, pid: pid, processName: name)
            info.command = command
            info.user = "dev"
            info.workingDirectory = project
            info.startedAtRaw = started
            info.uptimeRaw = uptime
            info.boundAddress = bind
            info.connectionsCount = connections
            info.memoryKB = Int(memoryMB * 1024)
            info.nodeEnv = env
            info.runtimeVersion = version
            info.reachable = true
            info.httpStatus = status
            info.title = title
            info.server = server
            info.contentType = contentType
            info.headers = headers
            info.probeOutcome = .responded(status: status)
            info.latencyMS = latency
            result.append(info)
        }

        func silent(
            _ port: Int, pid: Int32, name: String, command: String, project: String,
            outcome: ProbeOutcome, memoryMB: Double, uptime: String, started: String, connections: Int
        ) {
            var info = PortInfo(port: port, pid: pid, processName: name)
            info.command = command
            info.user = "dev"
            info.workingDirectory = project
            info.startedAtRaw = started
            info.uptimeRaw = uptime
            info.boundAddress = "127.0.0.1"
            info.connectionsCount = connections
            info.memoryKB = Int(memoryMB * 1024)
            info.probeOutcome = outcome
            result.append(info)
        }

        web(3000, pid: 48211, name: "node",
            command: "node /Users/dev/Developer/acme-storefront/node_modules/.bin/next dev",
            project: "/Users/dev/Developer/acme-storefront",
            title: "Acme Storefront", server: "", bind: "*", memoryMB: 214.4, latency: 9,
            uptime: "3h 12m 44s", started: "Oct 23, 2026 at 6:41:07 AM", connections: 4,
            env: "NODE_ENV=development", version: "v20.12.2",
            headers: [
                "Content-Type": "text/html; charset=utf-8",
                "X-Powered-By": "Next.js",
                "Cache-Control": "no-store, must-revalidate",
                "Vary": "RSC, Next-Router-State-Tree, Next-Router-Prefetch",
                "Connection": "keep-alive",
                "Keep-Alive": "timeout=5",
            ])
        web(9229, pid: 48211, name: "node",
            command: "node /Users/dev/Developer/acme-storefront/node_modules/.bin/next dev",
            project: "/Users/dev/Developer/acme-storefront",
            status: 400, contentType: "text/plain", memoryMB: 214.4, latency: 3,
            uptime: "3h 12m 44s", started: "Oct 23, 2026 at 6:41:07 AM", connections: 0,
            env: "NODE_ENV=development", version: "v20.12.2")
        web(3001, pid: 48990, name: "node",
            command: "node /Users/dev/Developer/acme-admin/node_modules/.bin/vite --port 3001",
            project: "/Users/dev/Developer/acme-admin",
            title: "Acme Admin — Orders", memoryMB: 156.8, latency: 6,
            uptime: "2h 48m 03s", started: "Oct 23, 2026 at 7:05:50 AM", connections: 2,
            env: "NODE_ENV=development", version: "v20.12.2",
            headers: ["Content-Type": "text/html", "Cache-Control": "no-cache", "Vary": "Origin"])
        web(4000, pid: 49102, name: "node",
            command: "node dist/server.js",
            project: "/Users/dev/Developer/acme-api",
            title: "GraphQL Playground", memoryMB: 121.2, latency: 14,
            uptime: "2h 41m 19s", started: "Oct 23, 2026 at 7:12:34 AM", connections: 6,
            env: "NODE_ENV=development", version: "v20.12.2")
        web(5173, pid: 50233, name: "node",
            command: "node /Users/dev/Developer/launchpad/node_modules/vite/bin/vite.js",
            project: "/Users/dev/Developer/launchpad",
            title: "Vite + React + TS", bind: "[::1]", memoryMB: 98.5, latency: 5,
            uptime: "1h 36m 52s", started: "Oct 23, 2026 at 8:17:21 AM", connections: 1,
            env: "NODE_ENV=development", version: "v20.12.2")
        web(8000, pid: 51877, name: "Python",
            command: "/opt/homebrew/bin/python3 -m uvicorn main:app --reload",
            project: "/Users/dev/Developer/inventory-service",
            title: "FastAPI - Swagger UI", memoryMB: 74.1, latency: 18,
            uptime: "58m 11s", started: "Oct 23, 2026 at 8:55:42 AM", connections: 3,
            version: "Python 3.12.4")
        web(8080, pid: 9013, name: "nginx",
            command: "nginx: master process /opt/homebrew/opt/nginx/bin/nginx",
            project: "/opt/homebrew/etc/nginx",
            title: "Welcome to nginx!", server: "nginx/1.25.5", bind: "*", memoryMB: 11.3, latency: 2,
            uptime: "2d 4h 17m", started: "Oct 21, 2026 at 4:49:16 AM", connections: 0,
            headers: ["Server": "nginx/1.25.5", "Content-Type": "text/html", "Accept-Ranges": "bytes"])
        web(11434, pid: 700, name: "ollama",
            command: "/Applications/Ollama.app/Contents/Resources/ollama serve",
            project: "/Users/dev",
            contentType: "text/plain; charset=utf-8", memoryMB: 342.7, latency: 4,
            uptime: "5d 1h 02m", started: "Oct 18, 2026 at 8:02:11 AM", connections: 1)
        web(27017, pid: 655, name: "mongod",
            command: "/opt/homebrew/opt/mongodb-community/bin/mongod --config /opt/homebrew/etc/mongod.conf",
            project: "/opt/homebrew/var/mongodb",
            contentType: "text/plain", memoryMB: 188.9, latency: 3,
            uptime: "5d 1h 02m", started: "Oct 18, 2026 at 8:02:09 AM", connections: 2)
        web(5000, pid: 763, name: "ControlCenter",
            command: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter",
            project: "/", status: 403, contentType: "text/plain", server: "AirTunes/950.7.1",
            bind: "*", memoryMB: 61.4, latency: 2,
            uptime: "5d 1h 03m", started: "Oct 18, 2026 at 8:01:20 AM", connections: 1)
        web(7000, pid: 763, name: "ControlCenter",
            command: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter",
            project: "/", status: 403, contentType: "text/plain", server: "AirTunes/950.7.1",
            bind: "*", memoryMB: 61.4, latency: 2,
            uptime: "5d 1h 03m", started: "Oct 18, 2026 at 8:01:20 AM", connections: 0)
        web(6463, pid: 20397, name: "Discord Helper (Renderer)",
            command: "/Applications/Discord.app/Contents/Frameworks/Discord Helper (Renderer).app/Contents/MacOS/Discord Helper (Renderer)",
            project: "/", status: 404, contentType: "text/plain", memoryMB: 187.7, latency: 3,
            uptime: "1d 7h 40m", started: "Oct 22, 2026 at 1:25:03 AM", connections: 0)

        silent(5432, pid: 612, name: "postgres",
               command: "/opt/homebrew/opt/postgresql@16/bin/postgres -D /opt/homebrew/var/postgresql@16",
               project: "/opt/homebrew/var/postgresql@16", outcome: .timeout, memoryMB: 52.6,
               uptime: "5d 1h 02m", started: "Oct 18, 2026 at 8:02:10 AM", connections: 5)
        silent(6379, pid: 640, name: "redis-server",
               command: "/opt/homebrew/opt/redis/bin/redis-server 127.0.0.1:6379",
               project: "/opt/homebrew/var/db/redis", outcome: .refused, memoryMB: 9.8,
               uptime: "5d 1h 02m", started: "Oct 18, 2026 at 8:02:10 AM", connections: 3)

        return result.sorted { $0.port < $1.port }
    }

    /// A few plausible recent samples, so sparklines have something real-looking to draw.
    static func memoryHistory(for port: PortInfo) -> [Int] {
        var generator = SeededGenerator(seed: UInt64(port.port) &* 2654435761)
        var value = Double(port.memoryKB) * 0.94
        return (0..<24).map { _ in
            value += Double.random(in: -0.012...0.02, using: &generator) * Double(port.memoryKB)
            value = min(max(value, Double(port.memoryKB) * 0.85), Double(port.memoryKB) * 1.08)
            return Int(value)
        }
    }

    static var portlessDevProcesses: [DevProcessInfo] {
        [
            DevProcessInfo(pid: 46310, ppid: 46290, name: "next-server (v14.2.3)",
                           command: "next-server (v14.2.3)", user: "dev", memoryKB: 1_482_752),
            DevProcessInfo(pid: 47102, ppid: 1, name: "node",
                           command: "node /Users/dev/Developer/acme-worker/dist/worker.js", user: "dev", memoryKB: 318_464),
        ]
    }

    // MARK: - Events

    static func events() -> [AppEvent] {
        func ago(_ minutes: Double) -> Date { Date().addingTimeInterval(-minutes * 60) }
        return [
            AppEvent(timestamp: ago(4), kind: .alert, message: "Port 5432 (postgres) went to Warning"),
            AppEvent(timestamp: ago(11), kind: .recovered, message: "Port 8000 (Python) is responding again"),
            AppEvent(timestamp: ago(25), kind: .kill, message: "Stopped node (PID 47102) on port 3002"),
            AppEvent(timestamp: ago(38), kind: .revealTerminal, message: "Focused terminal tab for port 3000"),
            AppEvent(timestamp: ago(52), kind: .alert, message: "Port 6379 (redis-server) went to Error"),
            AppEvent(timestamp: ago(70), kind: .forceKill, message: "Force quit node (PID 46310) on port 5174"),
            AppEvent(timestamp: ago(96), kind: .recovered, message: "Port 4000 (node) is responding again"),
        ]
    }

    // MARK: - Process tree & connections

    static func ancestry(of pid: Int32) -> [ProcessTreeNode] {
        [
            ProcessTreeNode(pid: 1, name: "launchd", command: "/sbin/launchd"),
            ProcessTreeNode(pid: 412, name: "login", command: "/usr/bin/login"),
            ProcessTreeNode(pid: 413, name: "zsh", command: "-zsh"),
            ProcessTreeNode(pid: 48190, name: "npm", command: "npm run dev"),
            ProcessTreeNode(pid: 48210, name: "node", command: "node /Users/dev/Developer/acme-storefront/node_modules/.bin/next dev"),
            ProcessTreeNode(pid: pid, name: "next-server", command: "next-server (v14.2.3)"),
        ]
    }

    static func connections(forPort port: Int) -> [ConnectionInfo] {
        let local = "127.0.0.1:\(port)"
        return [
            ConnectionInfo(localAddress: local, remoteAddress: "127.0.0.1:53124", state: "ESTABLISHED"),
            ConnectionInfo(localAddress: local, remoteAddress: "127.0.0.1:53127", state: "ESTABLISHED"),
            ConnectionInfo(localAddress: local, remoteAddress: "192.168.1.58:49812", state: "ESTABLISHED"),
            ConnectionInfo(localAddress: local, remoteAddress: "127.0.0.1:53090", state: "CLOSE_WAIT"),
        ]
    }

    // MARK: - Task Manager

    static func systemProcesses() -> [SystemProcessInfo] {
        func process(_ pid: Int32, _ name: String, cpu: Double, mb: Double, threads: Int, user: String = "dev") -> SystemProcessInfo {
            SystemProcessInfo(pid: pid, ppid: 1, cpuPercent: cpu, memoryKB: Int(mb * 1024),
                              threadCount: threads, user: user, name: name, command: name)
        }
        return [
            process(1, "kernel_task", cpu: 5.5, mb: 1_420, threads: 482, user: "root"),
            process(407, "WindowServer", cpu: 6.1, mb: 884, threads: 18, user: "_windowserver"),
            process(2210, "Xcode", cpu: 3.2, mb: 2_410, threads: 61),
            process(2764, "Google Chrome Helper (Renderer)", cpu: 12.8, mb: 1_126, threads: 24),
            process(3105, "Google Chrome Helper (Renderer)", cpu: 2.4, mb: 512, threads: 19),
            process(1180, "Docker Desktop", cpu: 1.4, mb: 982, threads: 41),
            process(1203, "com.docker.backend", cpu: 0.9, mb: 240, threads: 27),
            process(4420, "Slack Helper (Renderer)", cpu: 2.2, mb: 640, threads: 22),
            process(91019, "Code Helper (Renderer)", cpu: 9.4, mb: 574, threads: 31),
            process(48211, "node", cpu: 4.1, mb: 214, threads: 14),
            process(48990, "node", cpu: 1.7, mb: 157, threads: 12),
            process(50233, "node", cpu: 0.6, mb: 98, threads: 11),
            process(51877, "Python", cpu: 0.8, mb: 74, threads: 6),
            process(5532, "Figma Helper (Renderer)", cpu: 1.1, mb: 388, threads: 18),
            process(6011, "Notion Helper (Renderer)", cpu: 0.7, mb: 331, threads: 20),
            process(6120, "Safari", cpu: 0.5, mb: 322, threads: 12),
            process(700, "ollama", cpu: 0.4, mb: 343, threads: 16),
            process(655, "mongod", cpu: 0.6, mb: 189, threads: 38),
            process(612, "postgres", cpu: 0.1, mb: 53, threads: 4),
            process(640, "redis-server", cpu: 0.2, mb: 10, threads: 5),
            process(20397, "Discord Helper (Renderer)", cpu: 4.6, mb: 188, threads: 17),
            process(331, "Finder", cpu: 0.3, mb: 164, threads: 9),
            process(763, "ControlCenter", cpu: 0.2, mb: 112, threads: 10),
            process(335, "Dock", cpu: 0.1, mb: 98, threads: 8),
            process(842, "mds_stores", cpu: 0.8, mb: 142, threads: 7, user: "root"),
            process(960, "Terminal", cpu: 0.2, mb: 128, threads: 8),
            process(4801, "Spotify", cpu: 1.9, mb: 402, threads: 34),
        ]
    }

    // MARK: - Demo preview page

    /// Stand-in for the live page the Preview tab would normally load from
    /// 127.0.0.1 — loading real localhost URLs while demoing could show the
    /// presenter's actual apps, so demo mode renders this local page instead.
    static func previewHTML(title: String) -> String {
        let name = (title.isEmpty ? "Local Service" : title)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: dark }
        * { box-sizing: border-box }
        body { margin: 0; height: 100vh; overflow: hidden; color: #e8eefc;
               font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
               background: radial-gradient(700px 420px at 12% -10%, #2459d6 0%, #0b1226 64%) fixed; }
        nav { display: flex; align-items: center; gap: 10px; padding: 14px 20px; font-weight: 600; font-size: 13px; }
        .logo { width: 20px; height: 20px; border-radius: 6px; background: linear-gradient(135deg, #38bdf8, #6366f1); }
        .live { margin-left: auto; font-weight: 500; font-size: 12px; opacity: .7; }
        .live::before { content: ""; display: inline-block; width: 7px; height: 7px; border-radius: 50%;
                        background: #34d399; margin-right: 6px; }
        main { padding: 14px 20px; }
        h1 { font-size: 28px; line-height: 1.1; margin: 0 0 8px; letter-spacing: -.02em; }
        p { margin: 0; opacity: .72; font-size: 13px; max-width: 26em; }
        .row { display: flex; gap: 8px; margin-top: 16px; }
        .btn { padding: 7px 14px; border-radius: 9px; background: #3b82f6; color: #fff; font-weight: 600; font-size: 12.5px; }
        .btn.alt { background: rgba(255,255,255,.1); }
        .bars { display: flex; gap: 8px; margin-top: 18px; }
        .bar { height: 30px; flex: 1; border-radius: 10px; background: rgba(255,255,255,.07);
               border: 1px solid rgba(255,255,255,.08); }
        </style></head><body>
        <nav><div class="logo"></div>dev server<div class="live">hot reload</div></nav>
        <main>
          <h1>\(name)</h1>
          <p>Sample content rendered by the app's demo mode, not a real localhost page.</p>
          <div class="row"><div class="btn">Get started</div><div class="btn alt">Learn more</div></div>
          <div class="bars"><div class="bar"></div><div class="bar"></div><div class="bar"></div></div>
        </main></body></html>
        """
    }
}

/// Deterministic RNG so demo sparklines look the same on every run.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
