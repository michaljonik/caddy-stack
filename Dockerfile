# syntax=docker/dockerfile:1
# Caddy version: keep both FROM lines equal (Renovate bumps them together).
# Release = git tag v<caddy version>-<build>, e.g. v2.11.7-1 (the workflow checks the prefix).

# Runs on the build machine's own architecture and cross-compiles: no QEMU for the Go build.
FROM --platform=$BUILDPLATFORM caddy:2.11.7-builder-alpine AS builder
ARG TARGETOS
ARG TARGETARCH
# Plugins are pinned, so rebuilding a tag gives the same modules.
#   cloudflare        ACME DNS-01 challenge (wildcard certificates)
#   crowdsec-bouncer  `crowdsec` + `appsec` handlers (pulls in caddy-l4)
#   ratelimit         `rate_limit`
# Transitive dependencies forced up for security fixes (drop once Caddy/plugins require them):
#   x/net             GO-2026-6612 and others, fixed in v0.60.0
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 \
    xcaddy build --output /caddy \
        --with github.com/caddy-dns/cloudflare@v0.2.4 \
        --with github.com/hslatman/caddy-crowdsec-bouncer@v0.14.1 \
        --with github.com/mholt/caddy-ratelimit@v0.1.0 \
        --replace golang.org/x/net=golang.org/x/net@v0.60.0

FROM caddy:2.11.7-alpine
# Alpine security fixes released after the official image was built (e.g. zlib). Caddy and the
# plugins stay pinned; only the base packages move, and only when a tag is built.
RUN apk upgrade --no-cache
COPY --from=builder /caddy /usr/bin/caddy
# COPY drops the file capability the official image sets; without it Caddy can't bind :80/:443
# as a non-root user. The module check fails the build if a plugin silently went missing.
RUN setcap cap_net_bind_service=+ep /usr/bin/caddy \
    && caddy version \
    && for m in dns.providers.cloudflare http.handlers.crowdsec http.handlers.appsec http.handlers.rate_limit; do \
           caddy list-modules | grep -qx "$m" || { echo "missing module: $m" >&2; exit 1; }; \
       done
