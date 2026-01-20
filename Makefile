.PHONY: all clean link link-hellwave link-librequake deps engine maps assets upload

all: deps link engine

# install dependencies
deps:
	cd engine && npm ci

# make sure we link everything into the right place
link: link-hellwave link-librequake

link-hellwave:
	cd engine/source/game && ln -sfv ../../../hellwave-game hellwave
	cd engine/data && ln -sfv ../../hellwave-data hellwave

link-librequake:
	cd engine/data && ln -sfv ../../librequake-data librequake

# build the engine (games need to be linked first)
engine:
	cd engine && \
		VITE_GAME_DIR=hellwave \
		VITE_CDN_URL_PATTERN="https://hellwave.quakeshack.dev/assets/{filename}" \
		VITE_SIGNALING_URL="wss://master.quakeshack.dev/signaling" \
		VITE_PRESERVE_SYMLINKS=true \
		npm run build:production

# bake hellwave maps
maps:
	make -w -C engine/data/hellwave \
		DEDICATED=../engine/dedicated.mjs \
		TOOLS_DIR=../tools/ericw-tools \
		BASEDIR=../librequake \
		all

# clean up built files
clean:
	rm -rf dist/

# merge all assets together with the compiled engine into dist/
assets:
	mkdir -p dist/assets/
	rsync -av engine/dist/ dist/
	rsync -av engine/data/id1/shaders dist/assets/
	rsync -av engine/data/librequake/gfx dist/assets/
	rsync -av engine/data/librequake/progs dist/assets/
	rsync -av engine/data/librequake/sound dist/assets/
	rsync -av engine/data/librequake/gfx.wad dist/assets/
	rsync -av engine/data/librequake/maps/b_*.bsp dist/assets/maps/
	rsync -av engine/data/id1/*.cfg dist/assets/
	rsync -av engine/data/hellwave/ --exclude='*.wad' dist/assets/

# upload to R2
upload:
	aws s3 sync \
		--exclude '*.git*' \
		--exclude '*.log' \
		--profile hellwave-r2 \
		--delete \
		--endpoint-url https://59f59a22d0766e70438162eac7fc2513.r2.cloudflarestorage.com/ \
		dist/ s3://hellwave-production/
