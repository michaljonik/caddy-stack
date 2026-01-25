ARG CADDY_VERSION=2.10.2

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/caddyserver/caddy/v2/modules/standard \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/hslatman/caddy-crowdsec-bouncer \
    --with github.com/sablierapp/sablier-caddy-plugin \
    --with github.com/mholt/caddy-ratelimit \
    --with github.com/caddyserver/transform-encoder

FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
