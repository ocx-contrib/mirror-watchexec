# NOTICE

This repository packages and redistributes upstream software published by the
[watchexec](https://github.com/watchexec/watchexec) project. The Apache-2.0
license in [`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It
does **not** cover any upstream-derived asset — each package's redistributed
bytes carry their own license, recorded below.

Each package's logo is reproduced for catalog identification only, under
nominative fair use. The marks remain the property of their respective owners
and no endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `watchexec` | `ghcr.io/ocx-contrib/watchexec/watchexec` | `Apache-2.0` |

---

## `watchexec`

Upstream: <https://github.com/watchexec/watchexec>
Published to `ghcr.io/ocx-contrib/watchexec/watchexec`.

| Component | SPDX | Holder |
|---|---|---|
| watchexec CLI (`watchexec`) | **Apache-2.0** | Félix Saparelli \<felix@passcod.name\>, Matt Green \<mattgreenrocks@gmail.com\> and the watchexec contributors |

License gate evidence (Phase 1.5):

```
$ gh api repos/watchexec/watchexec/license --jq '{spdx,name,path}'
{"name":"Apache License 2.0","path":"LICENSE","spdx":"Apache-2.0"}
```

The `LICENSE` file at the upstream repository root is the verbatim Apache
License 2.0 text, and `crates/cli/Cargo.toml` declares `license = "Apache-2.0"`
for the `watchexec-cli` crate that produces the mirrored binary.

Apache License 2.0 grants redistribution of the binary form (§4) on condition
that recipients receive a copy of the license, that existing copyright, patent,
trademark and attribution notices are retained, and that modified files are
marked as changed. All three conditions are met without further action here:
the mirrored archives each ship upstream's own `LICENSE` file at their root,
republished unmodified, and nothing in any archive is altered. The published
binaries statically link third-party Rust crates under permissive licenses,
enumerated in upstream's `Cargo.lock`.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
