# Repository Guidelines

## Project Structure & Module Organization

This repository stores OpenWrt build overlays rather than a complete OpenWrt source tree. Shared configuration, scripts, filesystem overlays, and patches live under `devices/common/`. Each target has a matching directory such as `devices/amlogic_meson8b/` containing its `.config`, `diy.sh`, target patches, and image-generation helpers. Keep device-specific changes in that target directory; promote code to `devices/common/` only when every target should inherit it. The CI entry point is `.github/workflows/Openwrt-AutoBuild.yml`, which clones the pinned OpenWrt source and applies these overlays.

## Build, Test, and Development Commands

Run checks from the repository root:

```sh
bash -n devices/common/diy.sh devices/amlogic_meson8b/diy.sh \
  devices/amlogic_meson8b/gen_aml_emmc_img.sh
actionlint .github/workflows/Openwrt-AutoBuild.yml
bunx prettier --check AGENTS.md .github/workflows/Openwrt-AutoBuild.yml
git diff --check
```

The authoritative firmware build is the **Build OneCloud with OpenClash** GitHub Actions workflow. Start it with `workflow_dispatch`; it installs feeds, runs `make defconfig`, downloads sources, compiles OpenWrt, and verifies the packaged burn image. Use a clean Actions run for changes affecting packages, patches, kernel configuration, or image generation.

## Coding Style & Naming Conventions

Write Bash for scripts and enable `set -euo pipefail` in new executable scripts. Quote expansions, use descriptive `snake_case` variables and functions, and fail with actionable messages. Use two-space indentation in YAML. Name target directories as OpenWrt target/subtarget identifiers, for example `amlogic_meson8b`. Prefix patches numerically when ordering matters, and use `.patch`, `.revert.patch`, or `.bin.patch` according to the workflow conventions. OpenWrt login-shell customization belongs in `/etc/profile`, not `.bashrc`.

## Testing Guidelines

There is no standalone unit-test suite. Treat shell parsing, workflow linting, configuration validation, and a successful firmware build as required tests. For image changes, confirm the expected `.img.gz` artifact exists, passes gzip integrity checks, has checksums, and is accepted by the workflow's Amlogic image validation.

## Commit & Pull Request Guidelines

Follow the recent concise, imperative convention: `fix: package OneCloud burn image` or `build: stabilize OpenClash firmware`. Keep each commit focused. Pull requests should identify the affected target, source tag, package or network-default changes, commands run, and the successful Actions run URL. Include screenshots only for visible LuCI changes.

## Security & Configuration

Never commit GitHub tokens, passwords, `.env` files, or private endpoints. Store CI credentials in GitHub Actions secrets. Pin third-party actions and source revisions where practical, and review external downloads before changing their URLs.
