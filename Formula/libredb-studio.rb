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
  version "0.9.50"
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
      url "https://github.com/libredb/libredb-studio/releases/download/0.9.50/libredb-studio-standalone-0.9.50-darwin-x64.tar.gz"
      sha256 "dd13cf55141ecb102e893690e0a5531ccec470ac71e3ec7bba1dff7939842318"
    end
    on_arm do
      url "https://github.com/libredb/libredb-studio/releases/download/0.9.50/libredb-studio-standalone-0.9.50-darwin-arm64.tar.gz"
      sha256 "c0cd656bdd5b44235aa20c6ec4c375a33be9bd7532cfa34fda5013be9bcf5dc1"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/libredb/libredb-studio/releases/download/0.9.50/libredb-studio-standalone-0.9.50-linux-x64.tar.gz"
      sha256 "9d698f6e36f925c1f384da02b8fd3dc70e9c7e3d3afe2c7dbe1b92074feb9d69"
    end
    on_arm do
      url "https://github.com/libredb/libredb-studio/releases/download/0.9.50/libredb-studio-standalone-0.9.50-linux-arm64.tar.gz"
      sha256 "97f57918e8205002114b49ac6f9a8e687a08460d556631326c8f8c683fcea85f"
    end
  end

  def install
    # The tarball is the standalone server payload with server.js at its root
    # (no top-level directory), so install everything - including the hidden
    # .next directory - into libexec.
    libexec.install Dir["*", ".next"]

    # Launcher: run the standalone server under Homebrew's node@24, passing
    # the caller's environment through untouched. All configuration is
    # environment-driven; the zero-config first run generates missing auth
    # secrets and prints the admin password once.
    (bin/"libredb-studio").write <<~SCRIPT
      #!/bin/bash
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
    # manually with HOSTNAME=0.0.0.0 or use a reverse proxy to expose it.
    environment_variables STORAGE_PROVIDER: "sqlite",
                          STORAGE_SQLITE_PATH: var/"libredb-studio/libredb-storage.db",
                          HOSTNAME: "127.0.0.1"
  end

  test do
    assert_path_exists libexec/"server.js"
    assert_predicate bin/"libredb-studio", :executable?
  end
end
