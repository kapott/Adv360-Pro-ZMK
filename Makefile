DOCKER := $(shell { command -v podman || command -v docker; })
TIMESTAMP := $(shell date -u +"%Y%m%d%H%M")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null)
# ZMK Studio saves per-key bindings to NVS and replays them over the compiled
# keymap at boot, so a key remapped in Clique survives a firmware update and
# overrides config/adv360.keymap. BUILD_STUDIO=false compiles that out.
BUILD_STUDIO ?= true
ifeq ($(shell uname),Darwin)
SELINUX1 :=
SELINUX2 :=
else
SELINUX1 := :z
SELINUX2 := ,z
endif

.PHONY: all left clean_firmware clean_image clean

all:
	$(shell bin/get_version_local.sh clique >> /dev/null)
	$(DOCKER) build --tag zmk --file Dockerfile .
	$(DOCKER) run --rm -it --name zmk \
		-v $(PWD)/firmware:/app/firmware$(SELINUX1) \
		-v $(PWD)/config:/app/config:ro$(SELINUX2) \
		-e TIMESTAMP=$(TIMESTAMP) \
		-e COMMIT=$(COMMIT) \
		-e BUILD_RIGHT=true \
		-e BUILD_STUDIO=$(BUILD_STUDIO) \
		zmk
	git checkout config/version.dtsi

left:
	$(shell bin/get_version_local.sh clique >> /dev/null)
	$(DOCKER) build --tag zmk --file Dockerfile .
	$(DOCKER) run --rm -it --name zmk \
		-v $(PWD)/firmware:/app/firmware$(SELINUX1) \
		-v $(PWD)/config:/app/config:ro$(SELINUX2) \
		-e TIMESTAMP=$(TIMESTAMP) \
		-e COMMIT=$(COMMIT) \
		-e BUILD_RIGHT=false \
		-e BUILD_STUDIO=$(BUILD_STUDIO) \
		zmk
	git checkout config/version.dtsi

clean_firmware:
	rm -f firmware/*.uf2

clean_image:
	$(DOCKER) image rm zmk docker.io/zmkfirmware/zmk-build-arm:stable

clean: clean_firmware clean_image
