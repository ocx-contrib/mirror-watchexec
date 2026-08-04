# mirror-watchexec

OCX mirror for [watchexec](https://github.com/watchexec/watchexec), which
executes commands in response to file modifications. One repository, one spec
directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [watchexec](https://github.com/watchexec/watchexec) | [`watchexec/mirror.yml`](watchexec/mirror.yml) | `ghcr.io/ocx-contrib/watchexec/watchexec` | [`ocx.sh/watchexec/watchexec`](https://index.ocx.sh/watchexec/watchexec) | `Apache-2.0` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
watchexec/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all.

## Two tag schemes — only one is the CLI

The upstream repository is a workspace, and it tags twice:

| Tag shape | What it is | Assets |
|---|---|---|
| `vX.Y.Z` (e.g. `v2.5.1`) | the **watchexec CLI** — what this mirror ships | 112–128 per release |
| `watchexec-vX.Y.Z` (e.g. `watchexec-v8.2.0`) | the internal **`watchexec` library crate** | none — no GitHub Release object at all |

The library tags carry a much higher number than the CLI and read like "newer".
They are crates.io publish markers: `gh api
repos/watchexec/watchexec/releases/tags/watchexec-v8.2.0` answers `404 Not
Found`. `tag_pattern` is anchored `^v(?P<version>\d+\.\d+\.\d+)$` so only the
bare CLI tags are ever considered.

## Platforms

`watchexec` publishes **five** platform entries: both Linux arches, both macOS
arches and `windows/amd64`.

**There is no `windows/arm64`, and none is planned.** Upstream ships exactly one
Windows asset per release — `x86_64-pc-windows-msvc.zip` — at v2.4.3, v2.5.0
and v2.5.1 alike. Declaring the key anyway would boot a `windows-11-arm` runner
that resolves no asset and reports success having tested nothing.

Upstream also ships `armv7-gnueabihf`, `i686`, `powerpc64le`, `s390x`,
`riscv64gc` (new at v2.5.1) and `x86_64-unknown-freebsd` (new at v2.5.1) builds.
None is expressible: OCX's architecture enum is amd64 and arm64, over linux,
darwin and windows. There is nothing to declare and nothing to gate.

The 112-asset release listing is **package-format** fan-out, not platform
fan-out: every Linux target ships `.tar.xz` *and* `.deb` *and* `.rpm`, each with
`.b3`, `.sha256` and `.sha512` sidecars — up to twelve files for one platform.
The declared regexes are anchored `^…\.tar\.xz$` / `^…\.zip$` precisely so that
no sidecar and no distro package can match one.

Upstream ships **both** `-gnu` and `-musl` Linux assets for amd64 and arm64.
This mirror carries the **musl** ones, and both Linux keys are **bare** — no
`+libc.*` suffix. That is a measurement, not an inference: on v2.5.1 *and* on
the v2.4.3 floor, on x86-64 and aarch64 alike, the musl binaries have no
`PT_INTERP` and no `DT_NEEDED` — musl is linked *in*, not linked *against* —
and they carry zero UPX markers with non-zero section-header offsets, so the
packer artefact that defeats this gate elsewhere is absent. The gnu binaries by
contrast name `/lib64/ld-linux-x86-64.so.2` (resp.
`/lib/ld-linux-aarch64.so.1`) and need `libc.so.6`, `libm.so.6` and
`libgcc_s.so.1`, so they would require `+libc.glibc`. `os.features` states what
an artifact requires *of the host*, and a static binary requires nothing —
tagging it `+libc.musl` would be a false requirement that hid the package from
every glibc host it in fact runs on. The second, gnu-keyed platform is not
carried because watchexec watches the filesystem and spawns child processes: it
makes no name-resolution calls, so the usual reason to ship one (musl's
resolver ignores `nsswitch.conf`) does not apply. The `alpine:3.20` container
leg in `mirror-base.yml` is what turns the universality claim into evidence;
the measurement itself is recorded above the `assets:` block in
`watchexec/mirror.yml`.

## The smoke test

`watchexec/tests/smoke.star` has to solve the problem every watcher poses: the
tool's normal mode blocks forever. There is no `--once` flag in the 2.x line;
the bounded mechanism is `--stdin-quit` (exit on stdin EOF) paired with
`ocx.run(..., stdin="")`, which lets watchexec perform its single startup run
and then exit.

The assertion is the side effect, not the output: the child command writes a
token file, and the test reads that file back. That proves watchexec really
initialised the platform watcher and really forked and executed a child —
which no `--version` probe can. A negative control (a watch path that does not
exist) must exit non-zero *and* leave no token behind, so the positive result
cannot be satisfied by a build that ignores its arguments. Nothing asserts on
watchexec's `[Running: …]` status banners.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `watchexec/mirror.yml` | hand | yes — see below |
| `watchexec/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `watchexec/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec watchexec/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`watchexec/metadata.json` declares `binaries: ["watchexec"]` by hand, and
`watchexec/mirror.yml` sets `bin_scan: "off"` — forced, not preferred. Every
upstream archive wraps its payload in one directory named after the asset
itself (`watchexec-2.5.1-x86_64-unknown-linux-musl/`), whose name embeds both
the version and the target triple and so cannot be named in a static PATH.
`strip_components: 1` removes it, which lands `watchexec` at the content root
with no subdirectory left for the scan to inspect — and with nothing to
inspect, `auto` and `verify` both fail spec load at exit 65 rather than offer a
hollow check. The hand-written list is what the error message itself directs,
and it is short and stable: the binary is the only mode-0755 entry, while
`LICENSE`, `README.md`, `logo.svg`, the `watchexec.1` man page, `watchexec.1.md`
and everything under `completions/` are 0644 data.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; each
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
