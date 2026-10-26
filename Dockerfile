# GitHub Actions runner, built from upstream actions/runner source with the
# patches in patches/, laid over the stock runner image of the same version.
#
# The stock image tag below is the single version pin (Dependabot bumps it).
# The build compiles exactly the upstream commit stamped into that image's
# Runner.Sdk.dll, using the .NET SDK version from upstream's global.json, and
# fails if a patch no longer applies or NuGet reports a vulnerable package.
FROM ghcr.io/actions/actions-runner:2.338.1 AS runner-stock

FROM ubuntu:24.04 AS runner-build
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl git libicu74 && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY --from=runner-stock /home/runner/bin/Runner.Sdk.dll /stock/
COPY patches/ /patches/
RUN COMMIT="$(LC_ALL=C grep -aoP '(?:[0-9a-f]\x00){40}' /stock/Runner.Sdk.dll | tr -d '\0' | sort -u)" && \
    echo "stock runner commit: ${COMMIT}" && \
    [ "${#COMMIT}" -eq 40 ] && \
    git init -q . && \
    git fetch -q --depth 1 https://github.com/actions/runner "${COMMIT}" && \
    git checkout -q FETCH_HEAD && \
    git apply /patches/*.patch && \
    cd src && \
    bash ./Misc/dotnet-install.sh --no-path --install-dir /dotnet \
      --version "$(grep -oP '"version":\s*"\K[^"]+' global.json)" && \
    /dotnet/dotnet msbuild -t:Build -nologo -v:minimal \
      -p:PackageRuntime=linux-x64 -p:BUILDCONFIG=Release -p:RunnerVersion="$(cat runnerversion)" ./dir.proj && \
    rm -f /src/_layout/bin/*.pdb

FROM runner-stock

LABEL org.opencontainers.image.source="https://github.com/labrats-work/infra.actions-runner"
LABEL org.opencontainers.image.description="GitHub Actions runner built from upstream source with a runner-level ACTIONS_RESULTS_URL override"
LABEL org.opencontainers.image.licenses="MIT"

COPY --from=runner-build --chown=runner:docker /src/_layout/bin/ /home/runner/bin/
