# LibreDB Homebrew Tap

Homebrew formulae for [LibreDB](https://github.com/libredb) products.

## Usage

```bash
# One-time: Homebrew's untrusted-tap policy requires trusting third-party taps
brew trust libredb/tap

brew tap libredb/tap
brew install libredb-studio
brew services start libredb-studio
```

LibreDB Studio then serves on http://localhost:3000. On first start it generates
admin credentials and prints them once to the service log (zero-config first run);
set `JWT_SECRET` / `ADMIN_PASSWORD` explicitly or `AUTH_BOOTSTRAP=off` for strict mode.

## How this tap is maintained

`Formula/libredb-studio.rb` is rendered and pushed automatically by the
[libredb-studio release workflow](https://github.com/libredb/libredb-studio/blob/main/.github/workflows/release-artifacts.yml)
whenever a new release publishes its standalone tarballs. Do not edit the formula
by hand; changes belong in the
[formula template](https://github.com/libredb/libredb-studio/tree/main/packaging/homebrew).

The formula requires a libredb-studio release that ships standalone artifacts
(0.9.42 or later).
