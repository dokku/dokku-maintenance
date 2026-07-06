DOKKU_VERSION ?= latest

# Optional path or filename relative to /plugin-src/tests passed to bats, e.g.
# `make unit-tests UNIT_TESTS=maintenance_enable.bats`. Defaults to the whole
# tests directory.
UNIT_TESTS ?= .
# Optional regex passed to bats --filter to scope down to a single test name.
UNIT_TESTS_FILTER ?=
BATS_FLAGS := --timing --print-output-on-failure
ifneq ($(UNIT_TESTS_FILTER),)
BATS_FLAGS += --filter '$(UNIT_TESTS_FILTER)'
endif

COMPOSE := DOKKU_VERSION=$(DOKKU_VERSION) docker compose -f tests/docker-compose.yml
COMPOSE_COMPOSE_MODE := $(COMPOSE) --profile compose-mode
COMPOSE_EXEC_DOKKU := $(COMPOSE) exec -T dokku

PLUGIN_BASH_FILES := command-functions commands config help-functions internal-functions report \
	$(wildcard subcommands/*) \
	tests/setup.sh tests/setup-native.sh tests/test_helper.bash

.PHONY: setup build-stack wait-stack install-plugin test lint unit-tests clean logs \
	setup-native install-plugin-native unit-tests-native clean-native

setup: build-stack wait-stack install-plugin

build-stack:
	$(COMPOSE_COMPOSE_MODE) build
	$(COMPOSE_COMPOSE_MODE) up -d

wait-stack:
	$(COMPOSE_COMPOSE_MODE) up -d --wait

install-plugin:
	$(COMPOSE_EXEC_DOKKU) bash /plugin-src/tests/setup.sh

lint:
	$(COMPOSE_EXEC_DOKKU) shellcheck $(addprefix /plugin-src/, $(PLUGIN_BASH_FILES))

unit-tests:
	$(COMPOSE_EXEC_DOKKU) bats $(BATS_FLAGS) /plugin-src/tests/$(UNIT_TESTS)

test: lint unit-tests

logs:
	$(COMPOSE) logs --no-color --tail=200

clean:
	$(COMPOSE_COMPOSE_MODE) down -v --remove-orphans

# --- Native mode: dokku installed on the host ---

setup-native: install-plugin-native

install-plugin-native:
	bash tests/setup-native.sh

unit-tests-native:
	SUDO=sudo bats $(BATS_FLAGS) tests/$(UNIT_TESTS)

clean-native:
	$(COMPOSE_COMPOSE_MODE) down -v --remove-orphans
