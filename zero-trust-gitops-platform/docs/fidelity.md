# Fidelity gaps

Where this repo's own build/dev environment can't faithfully reproduce what a real cloud
deployment or a contributor's machine can do, that gap is recorded here as it's discovered — not
glossed over. Started in Phase 1 (the sample workload's build); BRIEF.md's later phases (the local
`kind` demo, keyless signing, AWS identity) will add their own rows here as they land.

| Capability | Cloud / CI / contributor-machine implementation | This build environment | What is lost here |
|---|---|---|---|
| Container image build & run | `docker build` produces the real multi-stage image; `docker run` as UID 65532 serves `/healthz`; `docker run --entrypoint sh` fails for lack of a shell | No Docker daemon is reachable at all (`docker info` fails). `apps/demo-api/Dockerfile` is written and its two base images are digest-pinned via a live registry lookup (see `docs/versions.md`), but the image itself has never actually been built or run here | The three container-level checks BRIEF.md's Phase 1 gate asks for (non-root run, no-shell, and the image builds at all) are unverified in this environment. `make image` was run once to confirm it fails at exactly "cannot connect to the Docker daemon" and not from a bug in the Dockerfile or the `Makefile` invocation — that's the most this environment can prove |
| Build reproducibility | Two `docker build`s of the same commit produce the same image digest | Two `go build -trimpath` runs of the same commit, with the same `-ldflags`, produce byte-identical binaries (verified: matching `sha256sum`) | This proves the Go compiler output is deterministic for this program. It does not prove the *image* is reproducible — that also depends on deterministic layer/tar construction, which needs an actual `docker build` (BuildKit is deterministic for this Dockerfile's simple `COPY`-only layers in practice, but that's an expectation, not something checked here) |

Every row above will be checked for real in `.github/workflows/e2e-kind.yml` (a GitHub-hosted
runner, which does have Docker) once that workflow exists (Phase 4+), and can be checked by any
contributor with Docker installed by running `make image` themselves.
