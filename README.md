# caddy-stack

[![Build & Push Docker Image](https://github.com/michaljonik/caddy-stack/actions/workflows/docker-image.yml/badge.svg)](https://github.com/michaljonik/caddy-stack/actions/workflows/docker-image.yml)

A [Caddy](https://caddyserver.com) image with the plugins I need on a self-hosted reverse
proxy: wildcard certificates through the Cloudflare DNS challenge, CrowdSec blocking and rate
limiting. Built with [xcaddy](https://github.com/caddyserver/xcaddy) on top of the official
`caddy` image, for `linux/amd64` and `linux/arm64`.

```sh
docker pull ghcr.io/michaljonik/caddy-stack:2.10.2
```

## What's inside

| Plugin | Adds | Used for |
|---|---|---|
| [caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare) | `dns cloudflare` | ACME DNS-01 challenge, so wildcard certificates work without opening port 80 |
| [hslatman/caddy-crowdsec-bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer) | `crowdsec`, `appsec` | dropping requests from IPs banned by [CrowdSec](https://www.crowdsec.net); optional WAF through the AppSec component |
| [mholt/caddy-ratelimit](https://github.com/mholt/caddy-ratelimit) | `rate_limit` | per-client request limits |
| [sablierapp/sablier-caddy-plugin](https://github.com/sablierapp/sablier-caddy-plugin) | `sablier` | starting containers on demand |
| [caddyserver/transform-encoder](https://github.com/caddyserver/transform-encoder) | `transform` log encoder | access logs in a custom text format |

Everything else is the stock image: same entrypoint, same `/data` and `/config` volumes, same
default Caddyfile location. It is a drop-in replacement for `caddy:<version>-alpine`.

## Usage

`compose.yml`:

```yaml
services:
  caddy:
    image: ghcr.io/michaljonik/caddy-stack:2.10.2
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
| `2.10.2` | built from Caddy 2.10.2 |
| `latest` | the most recent build |

The image tag is the Caddy version it was built from.

## Building

```sh
docker build -t caddy-stack .
docker build --build-arg CADDY_VERSION=2.10.2 -t caddy-stack:2.10.2 .
docker run --rm caddy-stack caddy list-modules --versions
```

To add or remove a plugin, edit the `--with` lines in the [Dockerfile](Dockerfile).

## Releasing

Pushing a tag `v<caddy version>` builds both architectures and publishes the image to GHCR
([workflow](.github/workflows/docker-image.yml)):

```sh
git tag v2.10.2 && git push origin v2.10.2
```

## License

[Apache 2.0](LICENSE), the same as Caddy. The plugins keep their own licenses.
