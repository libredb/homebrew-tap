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
  desc "Web-based SQL IDE for Postgres, MySQL, SQLite, Oracle, MSSQL, MongoDB, Redis"
  homepage "https://github.com/libredb/libredb-studio"
  version "0.9.63"
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
      url "https://github.com/libredb/libredb-studio/releases/download/0.9.63/libredb-studio-standalone-0.9.63-darwin-x64.tar.gz"
      sha256 "1d145d854a9404ea2553d02d6b72c4025fbceffd6767e4bf424a857b0edff053"
    end
    on_arm do
      url "https://github.com/libredb/libredb-studio/releases/download/0.9.63/libredb-studio-standalone-0.9.63-darwin-arm64.tar.gz"
      sha256 "7354462081f8d9b7889e0b09174435e8942fed2df3e07452ed724d92d15aeedb"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/libredb/libredb-studio/releases/download/0.9.63/libredb-studio-standalone-0.9.63-linux-x64.tar.gz"
      sha256 "e8c097851b143334796debb5a6210b12192562239a7d618b483dc802682798f6"
    end
    on_arm do
      url "https://github.com/libredb/libredb-studio/releases/download/0.9.63/libredb-studio-standalone-0.9.63-linux-arm64.tar.gz"
      sha256 "1520fac04a9e97deea208345c3dcc7e10c50f60a02dc84b3951edf8fc037da15"
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
