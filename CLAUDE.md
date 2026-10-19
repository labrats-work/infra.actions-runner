# CLAUDE.md

Public repo: the stock GitHub Actions runner image with its runner binaries rebuilt from upstream source plus `patches/`. See `README.md`.

- Keep it to the stock runner plus patches. Tools belong in images built on top of this one, not here.
- Public: no internal hostnames, infrastructure details, or references that need context outside this repo.
- CI runs on GitHub-hosted runners only; pull requests build without publishing.
- A patch change: regenerate it against the upstream commit named in the build log (`stock runner commit:`), and keep it minimal.
