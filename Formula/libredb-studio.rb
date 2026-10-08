# ==============================================================================
# Homebrew formula template for libredb-studio (issue #111).
#
# Rendered by scripts/render-homebrew-formula.mjs: the version and the four
# per-platform sha256 placeholders are filled from the SHA256SUMS file
# attached to the GitHub release, then the result is pushed to
# libredb/homebrew-tap as Formula/libredb-studio.rb by
# .github/workflows/release-artifacts.yml. Never edit the rendered formula in
# the tap by hand - change this template and re-release.
# ==============================================================================
class LibredbStudio < Formula
  # No engine count in the desc: nothing regenerates this template from the
  # provider registry, so a number here is stale the day the next engine
  # lands (issue #445). Name the span instead. `brew audit` caps desc at 80
  # characters, forbids a leading article and forbids the formula name.
  desc "Web-based SQL IDE for SQL, NoSQL, analytics and search engines"
  homepage "https://github.com/libredb/libredb-studio"
  version "0.18.1"
  license "MIT"

  # The standalone payload runs under Node and ships a better-sqlite3 native
  # binding compiled against the Node 24 ABI in release CI. The floating
  # "node" formula tracks the latest major (satisfying the engines range but
  # not the ABI: loading the binding there fails with ERR_DLOPEN_FAILED), so
  # pin the versioned formula - matching the Node 24 runtime bundled into the
  # deb/rpm/snap channels by packaging/linux/fetch-node.sh.
  depends_on "node@24"

  on_macos do
    on_intel do
      url "https://github.com/libredb/libredb-studio/releases/download/0.18.1/libredb-studio-standalone-0.18.1-darwin-x64.tar.gz"
      sha256 "4cde1b783726f52c6fd344618a5083c5bde3db7f045ed07a5a9d6b0c4fbb2522"
    end
    on_arm do
      url "https://github.com/libredb/libredb-studio/releases/download/0.18.1/libredb-studio-standalone-0.18.1-darwin-arm64.tar.gz"
      sha256 "c1393254ff3c1c20e45d00d61756053a617e3f9c6b0139084d0e657f1953e15e"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/libredb/libredb-studio/releases/download/0.18.1/libredb-studio-standalone-0.18.1-linux-x64.tar.gz"
      sha256 "77470942bddd9ec40d60114f1ca5a19e7eea0c11cf1d5559de016dd515e2a599"
    end
    on_arm do
      url "https://github.com/libredb/libredb-studio/releases/download/0.18.1/libredb-studio-standalone-0.18.1-linux-arm64.tar.gz"
      sha256 "8cf528e64358b6c3e47699e0c8e9405cebb632859b6f2085856fabad9a8e4672"
    end
  end

  def install
    # The tarball is rooted under a top-level libredb-studio-<version>/
    # directory (issue #133); Homebrew strips that single top-level
    # directory automatically for the formula's main url/sha256 download,
    # so server.js and friends land directly in the staged working
    # directory. Install everything - including the hidden .next
    # directory - into libexec.
    libexec.install Dir["*", ".next"]

    # Launcher: run the standalone server under Homebrew's node@24, passing
    # the caller's environment through otherwise untouched. All configuration
    # is environment-driven; the zero-config first run generates missing auth
    # secrets and prints the admin password once.
    (bin/"libredb-studio").write <<~SCRIPT
      #!/bin/bash
      # Local-first bind (issue #134): default to loopback on a direct run,
      # regardless of any inherited HOSTNAME (empty, or - e.g. under Docker -
      # a container ID that Next.js would otherwise bind to); LIBREDB_BIND
      # opts in to a different bind address. The `brew services` block below
      # already passes HOSTNAME=127.0.0.1, so this resolves to the same
      # default there too.
      export HOSTNAME="${LIBREDB_BIND:-127.0.0.1}"
      # Local-first state (issue #135): server.js chdirs into the payload
      # (libexec) before resolving its default `./data`, so a direct run with
      # no STORAGE_SQLITE_PATH would persist the zero-config
      # auth-bootstrap.json (and any STORAGE_PROVIDER=sqlite data) inside the
      # versioned keg - wiped on every `brew upgrade`. Default to the same
      # path the `service` block below already uses, so state survives
      # upgrades and both run modes share one install.
      if [ -z "${STORAGE_SQLITE_PATH:-}" ]; then
        export STORAGE_SQLITE_PATH="#{var}/libredb-studio/libredb-storage.db"
      fi
      exec "#{Formula["node@24"].opt_bin}/node" "#{libexec}/server.js" "$@"
    SCRIPT
    (bin/"libredb-studio").chmod 0755
  end

  def post_install
    (var/"libredb-studio").mkpath
  end

  # brew services start libredb-studio: serve on the default port with the
  # server-side storage database under var (server.js chdirs into the payload,
  # so a relative STORAGE_SQLITE_PATH would otherwise land inside the keg).
  # STORAGE_PROVIDER must be set explicitly - the app defaults to
  # browser-local storage otherwise - mirroring the systemd unit and the snap.
  service do
    run [opt_bin/"libredb-studio"]
    keep_alive false
    working_dir var
    # HOSTNAME keeps the service loopback-only (local-first); run the binary
    # manually with LIBREDB_BIND=0.0.0.0 or use a reverse proxy to expose it.
    environment_variables STORAGE_PROVIDER: "sqlite",
                          STORAGE_SQLITE_PATH: var/"libredb-studio/libredb-storage.db",
                          HOSTNAME: "127.0.0.1"
  end

  test do
    assert_path_exists libexec/"server.js"
    assert_predicate bin/"libredb-studio", :executable?
  end
end
