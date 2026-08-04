# watchexec/tests/smoke.star — stable across upstream watchexec releases.
# Asserts the contract (exit code, version shape, a real child process's side
# effect), never help/version prose. See ocx.mirror testing-practices.md.
#
# ⚠ watchexec is a WATCHER: `watchexec <cmd>` runs <cmd> once at startup and
# then blocks forever waiting for filesystem events. A naive smoke would hang
# for the whole job timeout and burn a runner slot. There is no `--once` /
# `-1` flag in the 2.x line (grepped `--help` on BOTH ends of the mirrored
# range, v2.4.3 and v2.5.1 — no such option exists). The bounded mechanism
# upstream does provide is `--stdin-quit`:
#
#   --stdin-quit
#       Exit when stdin closes
#       This watches the stdin file descriptor for EOF, and exits Watchexec
#       gracefully when it is closed.
#
# Paired with `stdin=""` below — ocx.run feeds the empty string and closes the
# pipe, so EOF is immediate — every invocation here is bounded: watchexec
# performs its one startup run and then exits. Measured on v2.4.3 and v2.5.1:
# exit 0, the child ran, wall time well under a second.
#
# ⚠ watchexec also writes its own status banners to stdout
# (`[Running: …]`, `[Command was successful]`). Nothing below asserts on that
# text — the proof that the child really ran is the TOKEN FILE the child
# itself writes, which no version probe and no banner could fake.

WATCHEXEC = "watchexec.exe" if ocx.target_platform.os == ocx.os.Windows else "watchexec"

# The shell watchexec hands the command to. Pinned explicitly rather than left
# to the default, which is `$SHELL` when set and only otherwise `sh` on
# unix-likes / `pwsh`|`powershell`|`cmd` on Windows — i.e. the default makes
# the test depend on the runner's environment. `cmd` and `sh` are the two that
# are always present on their platform.
SHELL = "cmd" if ocx.target_platform.os == ocx.os.Windows else "sh"

# One command string, handed to that shell (`sh -c` / `cmd /C`). `printf` has
# no trailing newline; cmd's `echo` appends CRLF and there is no space before
# the `>` so it appends no trailing space either — both are matched with
# `contains`, so neither detail is load-bearing.
WRITE_OK = (
    "echo OCXSMOKE-OK> token.txt"
    if ocx.target_platform.os == ocx.os.Windows
    else "printf OCXSMOKE-OK > token.txt"
)
WRITE_NEG = (
    "echo OCXSMOKE-NEG> neg-token.txt"
    if ocx.target_platform.os == ocx.os.Windows
    else "printf OCXSMOKE-NEG > neg-token.txt"
)

# HOME points at scratch so a stray user config (watchexec reads a config file
# and honours XDG paths) can never reach this run, and so the tool has a
# writable home in container legs where HOME is unset.
ENV = {"HOME": ocx.scratch_root}

# Tier 1 + 2: liveness on the composed PATH + version SHAPE (not the vendor
# banner, not the exact version — the digits are the contract).
r_version = ocx.run(WATCHEXEC, "--version", env = ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# Hermetic input: the directory watchexec is pointed at. `ocx.run`'s cwd IS the
# scratch root, so "watched" and the token files below all resolve here.
ocx.mkdir("watched")

# Tier 3a: the core contract — watchexec SPAWNS THE CHILD. It initialises the
# platform watcher (inotify / FSEvents / ReadDirectoryChangesW), performs its
# startup run, and exits on stdin EOF. The child writes a token file, and the
# token is read back from disk: that is the one thing no `--version` probe can
# establish, and it reds against a binary that starts but cannot fork/exec,
# against a watcher that fails to initialise on this platform, and against a
# truncated or wrong-flavour archive that still managed to exec.
r_run = ocx.run(
    WATCHEXEC, "--stdin-quit", "--shell", SHELL, "-w", "watched", "--", WRITE_OK,
    stdin = "",
    env = ENV,
)
expect.ok(r_run)
expect.contains(ocx.read_file("token.txt"), "OCXSMOKE-OK")

# Tier 3b: NEGATIVE CONTROL. Same invocation, one bad argument: a watch path
# that does not exist. watchexec must fail its own setup and NOT reach the
# child — so a non-zero exit AND no token file. Without this, "the child ran"
# above could be satisfied by a build that ignores its arguments and runs the
# command unconditionally, and a later edit could "fix" a red by relaxing the
# assert above into a bare expect.ok. Verified reachable on v2.4.3 and v2.5.1:
#   Error:   × No such file or directory (os error 2)   → exit 1, no file
r_neg = ocx.run(
    WATCHEXEC, "--stdin-quit", "--shell", SHELL, "-w", "no-such-dir", "--", WRITE_NEG,
    stdin = "",
    env = ENV,
)
expect.ne(r_neg.exit_code, 0)
expect.false(ocx.exists("neg-token.txt"))

# No Tier 4: metadata.json declares PATH only (proven by Tier 1 liveness).
