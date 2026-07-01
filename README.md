# Claude Desktop Nix Flake

This packages Anthropic's official Linux `claude-desktop` Debian package for NixOS.

## Build

```sh
nix build
```

## Run

```sh
nix run
```

## Install into your profile

```sh
nix profile install .
```

To remove the older third-party profile entry:

```sh
nix profile remove claude-desktop-debian
```

## Update the pinned `.deb`

```sh
./update.sh
nix build
```
