.PHONY: all clean link link-hellwave link-librequake deps engine maps assets upload update

VITE_CDN_URL_PATTERN ?= https://hw-assets-{shard}.quakeshack.dev/assets/{filename}
VITE_SIGNALING_URL ?= wss://master.quakeshack.dev/signaling

S3_BUCKET ?=
S3_ENDPOINT_URL ?=
S3_PREFIX ?=

all: assets

# install dependencies
deps:
	cd engine && npm ci

# make sure we link everything into the right place
link: link-hellwave link-librequake

link-hellwave:
	cd engine/source/game && ln -sfnv ../../../hellwave-game hellwave
	cd engine/data && ln -sfnv ../../hellwave-data hellwave

link-librequake:
	cd engine/data && ln -sfnv ../../librequake-data librequake

# build the engine (games need to be linked first)
engine: deps link
	cd engine && \
		VITE_GAME_DIR=hellwave \
		VITE_CDN_URL_PATTERN="$(VITE_CDN_URL_PATTERN)" \
		VITE_SIGNALING_URL="$(VITE_SIGNALING_URL)" \
		VITE_PRESERVE_SYMLINKS=true \
		npm run build:production

# bake hellwave maps
maps: link
	make -w -C engine/data/hellwave \
		DEDICATED="node --preserve-symlinks --preserve-symlinks-main ../engine/dedicated.mjs" \
		TOOLS_DIR=../tools/ericw-tools \
		BASEDIR=../librequake \
		all

# clean up built files
clean:
	rm -rf dist/

# merge all assets together with the compiled engine into dist/
assets: engine maps
	rm -rf dist/assets/
	mkdir -p dist/assets/maps/
	rsync -av --delete engine/dist/browser/ dist/
	rsync -av engine/data/librequake/gfx dist/assets/
	rsync -av engine/data/librequake/progs dist/assets/
	rsync -av engine/data/librequake/sound dist/assets/
	rsync -av engine/data/librequake/gfx.wad dist/assets/
	rsync -av engine/data/librequake/maps/b_*.bsp dist/assets/maps/
	rsync -av engine/data/id1/*.cfg dist/assets/
	rsync -av engine/data/hellwave/autoexec.cfg dist/assets/
	rsync -av engine/data/hellwave/better-quake.rc dist/assets/
	rsync -av engine/data/hellwave/client.cfg dist/assets/
	rsync -av engine/data/hellwave/default.cfg dist/assets/
	rsync -av engine/data/hellwave/server.cfg dist/assets/
	rsync -av engine/data/hellwave/gfx dist/assets/
	rsync -av engine/data/hellwave/textures dist/assets/
	rsync -av \
		--include='*.bsp' \
		--include='*.nav' \
		--include='*.lit' \
		--include='*.qsmat.json' \
		--exclude='*' \
		engine/data/hellwave/maps/ dist/assets/maps/

# upload to R2
upload:
	@test -n "$(S3_BUCKET)" || (echo "S3_BUCKET is required" >&2; exit 1)
	aws s3 sync \
		--exclude '*.git*' \
		--exclude '*.log' \
		--delete \
		$(if $(strip $(S3_ENDPOINT_URL)),--endpoint-url "$(S3_ENDPOINT_URL)") \
		dist/ s3://$(S3_BUCKET)$(if $(strip $(S3_PREFIX)),/$(S3_PREFIX))/

update:
	git submodule update --init --recursive --remote
	git add -A
