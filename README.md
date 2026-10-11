# caddy-stack

[![Build & Push Docker Image](https://github.com/michaljonik/caddy-stack/actions/workflows/docker-image.yml/badge.svg)](https://github.com/michaljonik/caddy-stack/actions/workflows/docker-image.yml)

A [Caddy](https://caddyserver.com) image with the plugins I need on a self-hosted reverse
proxy: wildcard certificates through the Cloudflare DNS challenge, CrowdSec blocking and rate
limiting. Built with [xcaddy](https://github.com/caddyserver/xcaddy) on top of the official
`caddy` image, for `linux/amd64` and `linux/arm64`.

```sh
docker pull ghcr.io/michaljonik/caddy-stack:2.11.7-1
```

## What's inside

| Plugin | Version | Adds | Used for |
|---|---|---|---|
| [caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare) | v0.2.4 | `dns cloudflare` | ACME DNS-01 challenge, so wildcard certificates work without opening port 80 |
| [hslatman/caddy-crowdsec-bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer) | v0.14.1 | `crowdsec`, `appsec` | dropping requests from IPs banned by [CrowdSec](https://www.crowdsec.net); optional WAF through the AppSec component |
| [mholt/caddy-ratelimit](https://github.com/mholt/caddy-ratelimit) | v0.1.0 | `rate_limit` | per-client request limits |

Plugin versions are pinned in the [Dockerfile](Dockerfile), so rebuilding a tag gives the same
modules. The build fails if one of them is missing from the binary.

Everything else is the stock image: same entrypoint, same `/data` and `/config` volumes, same
default Caddyfile location. It is a drop-in replacement for `caddy:<version>-alpine`, including
the `cap_net_bind_service` file capability, so it can bind 80/443 when run as a non-root user.

## Usage

`compose.yml`:

```yaml
services:
  caddy:
    image: ghcr.io/michaljonik/caddy-stack:2.11.7-1
    restart: unless-stopped
    environment:
      CLOUDFLARE_API_TOKEN: ${CLOUDFLARE_API_TOKEN}   # Zone:Read + DNS:Edit on the zone
      CROWDSEC_API_KEY: ${CROWDSEC_API_KEY}           # cscli bouncers add caddy
    ports:
      - 80:80
      - 443:443
      - 443:443/udp
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
```

`Caddyfile`:

```caddyfile
{
	# plugin directives have no default position in the handler chain
	order crowdsec before reverse_proxy
	order rate_limit before crowdsec

	crowdsec {
		api_url http://crowdsec:8080
		api_key {env.CROWDSEC_API_KEY}
	}
}

*.example.com {
	tls {
		dns cloudflare {env.CLOUDFLARE_API_TOKEN}
	}

	@app host app.example.com
	handle @app {
		rate_limit {
			zone per_client {
				key {client_ip}
				events 100
				window 1m
			}
		}
		crowdsec
		reverse_proxy app:8080
	}

	# unknown hostnames get no answer at all
	handle {
		abort
	}
}
```

If Caddy sits behind another proxy or a tunnel, set `trusted_proxies` in the global `servers`
block. Otherwise `{client_ip}` is the proxy's address, and both the bouncer and the rate
limiter act on the wrong client.

## Tags

| Tag | Meaning |
|---|---|
| `2.11.7-1` | Caddy 2.11.7, build 1. Never moves: use this one in compose files |
| `2.11.7` | the latest build of Caddy 2.11.7 |
| `latest` | the most recent build |

The build number goes up when only the plugins change.

## Building

```sh
docker build -t caddy-stack .
docker run --rm caddy-stack caddy list-modules --versions
```

The Go build runs on the build machine's own architecture and cross-compiles for the target,
so a multi-arch build doesn't compile under emulation.

To change the Caddy version, edit both `FROM` lines in the [Dockerfile](Dockerfile); to add,
remove or bump a plugin, edit the `--with` lines.

## Releasing

Pushing a tag `v<caddy version>-<build>` builds both architectures and publishes the image to
GHCR with an SBOM and provenance attestation ([workflow](.github/workflows/docker-image.yml)).
The workflow refuses a tag that doesn't match the Caddy version in the Dockerfile.

```sh
git tag v2.11.7-1 && git push origin v2.11.7-1
```

Pull requests build both architectures without publishing. Dependabot proposes new Caddy
versions and action updates.

## License

[Apache 2.0](LICENSE), the same as Caddy. The plugins keep their own licenses.
