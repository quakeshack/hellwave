# Hellwave Meta Repository

This repository ties together the pieces required to build one distributable Hellwave game package on top of QuakeShack and LibreQuake.

It is a meta-repository that:

- installs the engine dependencies
- links the external game and data repositories into the engine layout QuakeShack expects
- builds the browser client
- compiles Hellwave maps with ericw-tools
- generates navigation meshes with the dedicated server
- assembles a curated runtime `dist/` tree
- optionally uploads that build with `aws s3 sync`

## Repository Layout

The important submodules and directories are:

- `engine/`: QuakeShack engine
- `game/`: Quake game code used by the engine's `id1` submodule lineage
- `hellwave-game/`: Hellwave game code
- `hellwave-data/`: Hellwave maps, textures, shaders, configs, and WADs
- `librequake-data/`: LibreQuake runtime assets used as the base game data
- `tools/ericw-tools/`: map compiler toolchain used by the Hellwave map Makefile

The top-level `Makefile` is the intended entrypoint for local builds and CI.

## Prerequisites

- Git submodules initialized
- Node.js and npm available
- `rsync` available
- `aws` CLI available if you want to use `make upload`

Typical initial checkout:

```sh
git submodule update --init --recursive
```

To update submodules to their tracked upstream revisions:

```sh
git submodule update --init --remote --recursive
```

## Build Targets

### `make all`

This is the main CI target and the intended Jenkins entrypoint.

It currently expands to:

1. `deps`: run `npm ci` in `engine/`
2. `link`: symlink Hellwave and LibreQuake data into the engine tree
3. `engine`: build the browser client in `engine/dist/browser/`
4. `maps`: compile BSPs and navigation files for Hellwave maps
5. `assets`: assemble the final distributable tree in `dist/`

In Jenkins, the simplest pipeline step should just be:

```sh
make all
```

### Other useful targets

- `make deps`: install engine npm dependencies
- `make link`: refresh the engine symlinks for game and data repos
- `make engine`: build the browser client only
- `make maps`: rebuild Hellwave BSP and NAV files
- `make assets`: rebuild the distributable `dist/` tree
- `make clean`: remove `dist/`
- `make upload`: rebuild `dist/` if necessary and upload it with the AWS CLI

## Build-Time Environment Configuration

The top-level `Makefile` exposes the browser-facing build URLs as overridable variables so you can split staging and production builds without editing files.

The relevant variables are:

- `VITE_CDN_URL_PATTERN`: defaults to `https://hw-assets-{shard}.quakeshack.dev/assets/{filename}`
- `VITE_SIGNALING_URL`: defaults to `wss://master.quakeshack.dev/signaling`

Examples:

```sh
make all \
  VITE_CDN_URL_PATTERN="https://staging-cdn.example.com/assets/{filename}" \
  VITE_SIGNALING_URL="wss://staging-master.example.com/signaling"
```

```sh
make all \
  VITE_CDN_URL_PATTERN="https://cdn.example.com/assets/{filename}" \
  VITE_SIGNALING_URL="wss://master.example.com/signaling"
```

For Jenkins, these can be injected as job or pipeline environment variables and passed through to `make all`.

## What `dist/` Contains

The packaged output is intentionally curated for runtime use.

It includes:

- browser build output from `engine/dist/browser/`
- LibreQuake runtime assets: `gfx`, `progs`, `sound`, `gfx.wad`, and base item BSPs
- Quake base config files from `engine/data/id1/*.cfg`
- Hellwave runtime configs
- Hellwave `gfx`, `shaders`, and `textures`
- Hellwave map runtime artifacts only:
  - `*.bsp`
  - `*.nav`
  - `*.lit`
  - `*.qsmat.json`

It intentionally excludes build junk and source-only files such as:

- `.git`
- map compiler logs
- `.prt`
- `.content.json`
- `.texinfo.json`
- source `.map` files
- arbitrary WAD copies from the Hellwave data tree

## Upload Configuration

The upload step is environment-driven so it can be fed by Jenkins.

The `upload` target uses these variables:

- `S3_BUCKET`: required
- `S3_ENDPOINT_URL`: optional
- `S3_PREFIX`: optional
- `AWS_PROFILE`: optional, handled by the AWS CLI itself

`Makefile` no longer hardcodes an AWS profile. If Jenkins wants a profile, export `AWS_PROFILE` before calling `make upload`.

Example:

```sh
export AWS_PROFILE=hellwave-r2
export S3_BUCKET=hellwave-production
export S3_ENDPOINT_URL=https://example.r2.cloudflarestorage.com
export S3_PREFIX=hellwave

make upload
```

If `S3_PREFIX` is empty, the upload goes to the bucket root.

## Notes About Map Builds

Hellwave map compilation is delegated to `hellwave-data/Makefile`, but the top-level repository overrides the important runtime paths:

- `BASEDIR=../librequake`
- `TOOLS_DIR=../tools/ericw-tools`
- `DEDICATED="node --preserve-symlinks --preserve-symlinks-main ../engine/dedicated.mjs"`

Those overrides matter because:

- the dedicated server needs symlink preservation to load `hellwave-game/` correctly
- nav generation must boot with the requested map
- nav generation must resolve LibreQuake assets as the base game data

## Recommended Jenkins Flow

A minimal Jenkins job can do:

```sh
git submodule update --init --remote --recursive
make all
make upload
```

If upload credentials and destination are injected by Jenkins, set at least:

```sh
export S3_BUCKET=your-bucket
export S3_ENDPOINT_URL=https://your-endpoint
export S3_PREFIX=optional/path
export AWS_PROFILE=optional-profile
export VITE_CDN_URL_PATTERN=https://cdn.example.com/assets/{filename}
export VITE_SIGNALING_URL=wss://master.example.com/signaling
```

Then invoke:

```sh
make all \
  VITE_CDN_URL_PATTERN="$VITE_CDN_URL_PATTERN" \
  VITE_SIGNALING_URL="$VITE_SIGNALING_URL"

make upload
```

## Related Repositories

- `engine/README.md`: QuakeShack engine details
- `hellwave-data/Makefile`: map compilation details
- top-level `Makefile`: CI and packaging orchestration
