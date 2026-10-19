# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub:
[Security → Report a vulnerability](https://github.com/michaljonik/caddy-stack/security/advisories/new).
Do not open a public issue for them.

## Scope

This repository builds a Caddy image with a fixed set of plugins. In scope: the `Dockerfile`,
the build workflow and the published image `ghcr.io/michaljonik/caddy-stack`. Bugs in Caddy or
in a plugin belong to their own projects; tell me here too if the image ships an affected version.

## Supply chain

- Plugins and forced transitive modules are pinned in the `Dockerfile` and bumped by Renovate.
- GitHub Actions are pinned by digest.
- Images are published only from `v<caddy version>-<n>` tags, multi-arch, with provenance and SBOM.
