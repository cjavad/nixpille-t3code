# nixpille-t3code

Nix flake packaging the [T3 Code](https://github.com/pingdotgg/t3code) desktop
app, built from an **arbitrary upstream branch** rather than a release.

## Why a branch

T3 Code ships the CLI to npm and the desktop app through its own updater.
Neither helps if you want a branch — and branches are exactly what you want here,
because some of them change the wire protocol. PR #2829 (`t3code/codex-turn-mapping`)
renames `TurnId` → `RunId`, replaces `OrchestrationWsMethods` with V2 variants,
and moves `ProviderInstance.adapter` to `orchestrationAdapter`.

A released client cannot talk to a server built from that branch, and this
client cannot talk to a released server. **The client and the server have to come
from the same commit.** This flake exists to make the client half of that pinnable.

## Use it

```nix
{
  inputs.nixpille-t3code.url = "github:cjavad/nixpille-t3code";

  # in your NixOS config
  imports = [ inputs.nixpille-t3code.nixosModules.default ];
  programs.t3code.enable = true;
}
```

Or without installing anything:

```sh
nix run github:cjavad/nixpille-t3code
```

## Pinning a different build

`sources.json` records one artifact. To point at another — one you built
yourself, or a different branch — override it:

```nix
programs.t3code = {
  enable  = true;
  branch  = "t3code/some-branch";
  version = "0.0.40";
  url     = "https://github.com/you/your-repo/releases/download/.../T3-Code-0.0.40-x86_64.AppImage";
  hash    = "sha256-...";
};
```

`url` and `hash` must be set together; the module asserts on it. Setting one
alone either fetches something unpinned or checks a hash against the wrong file.

The package takes the same arguments, if you would rather not use the module:

```nix
pkgs.t3code.override { version = "0.0.40"; url = "..."; hash = "..."; }
```

## Producing a new artifact

```sh
./update.sh                            # rebuild the branch in sources.json
./update.sh t3code/some-other-branch   # switch branches
```

It builds on a remote host (`stuff` by default, override with `T3CODE_BUILDER`),
attaches the AppImage to a release here, and rewrites `sources.json`. The build
needs Node 24, pnpm, vite-plus **and** a Rust toolchain — the desktop artifact
compiles `native/resource-monitor` before electron-builder runs, and without
cargo it fails with a bare `spawn cargo ENOENT`.

## Why the AppImage, and not a source build

Upstream is a pnpm + vite-plus monorepo. `vp` is installed by a shell script
rather than published to nixpkgs, the desktop target shells out to
electron-builder, and that in turn wants `fakeroot`, `file` and
`desktop-file-utils` at build time. Reproducing that inside a Nix sandbox is a
project in itself; wrapping the artifact is a file.

The consequence is honest: this is not a from-source build, so it is only as
trustworthy as the machine that produced the AppImage.

## Repository visibility

Private, deliberately. The release assets are builds of someone else's
unreleased branch, which is a different thing from the other `nixpille-*` flakes
— those fetch from upstream's own published releases and redistribute nothing.
