# infra.actions-runner

The stock [GitHub Actions runner image](https://github.com/actions/runner/pkgs/container/actions-runner) with its runner binaries rebuilt from upstream source plus a few small patches. Nothing else is added — layer your own tools on top.

```
ghcr.io/labrats-work/infra.actions-runner:<version>
```

## Purpose

Self-hosted [actions/cache servers](https://github.com/falcondev-oss/github-actions-cache-server) work by pointing `ACTIONS_RESULTS_URL` at the server, but the stock runner overwrites that variable for every action with the URL GitHub sends. The usual workaround is a byte-level rename inside `Runner.Worker.dll`, which leaves actions in `container:` jobs with no results URL at all (their environment comes from the runner, not the host).

This image instead compiles the runner with a patch that makes a runner-level `ACTIONS_RESULTS_URL` take precedence for every action, including in job containers. Unset, the runner behaves exactly like the stock one.

## Patches

| Patch | What it does |
|---|---|
| `0001-results-url-override` | If the runner's environment sets `ACTIONS_RESULTS_URL`, both action handlers (node and container) pass that to the action instead of GitHub's results URL. |
| `0002-pkcs-asn1-10.0.13` | Bumps `System.Security.Cryptography.Pkcs` / `System.Formats.Asn1` to 10.0.13 (CVE-2026-70162, CVE-2026-84008); upstream's own build fails its NuGet audit without it. |

## Quick Start

Use it as the runner image, e.g. in an [actions-runner-controller](https://github.com/actions/actions-runner-controller) scale set, and set the cache server URL (trailing slash required) on the runner container:

```yaml
containers:
  - name: runner
    image: ghcr.io/labrats-work/infra.actions-runner:<version>
    command: ["/home/runner/run.sh"]
    env:
      - name: ACTIONS_RESULTS_URL
        value: http://actions-cache.example.svc.cluster.local:3000/
```

Your cache server must proxy non-cache traffic (artifacts, job summaries) to GitHub's results service.

## How it's built

- The stock image tag in the `Dockerfile` is the only version pin; Dependabot bumps it.
- The build reads the upstream commit stamped into that image's `Runner.Sdk.dll`, fetches exactly that commit, applies `patches/`, installs the .NET SDK pinned in upstream's `global.json`, and compiles. The result replaces the stock `bin/`; `externals/` and scripts stay as shipped.
- It fails if a patch stops applying or NuGet audit reports a vulnerable package. Pull requests build without publishing; each merge to `main` publishes the next semver tag (no `latest`).

GitHub stops sending jobs to runners that fall too far behind the latest release, so keep consumers on a recent tag.

## Structure

```
Dockerfile                 build stage (source + patches) over the stock image
patches/                   patches applied to upstream actions/runner
.github/workflows/image.yml  PR build; release + push on main
.github/dependabot.yml     stock image and action bumps
```

## License

MIT. The runner itself is [actions/runner](https://github.com/actions/runner) (MIT).
