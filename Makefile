.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: build clean exec logs new restart start status stop

## ------

## Build Dockerfiles
build:
	@docker-compose build

## Remove containers
clean:
	@docker-compose rm -vf

## Exec a shell into hexo container
exec:
	@docker-compose exec hexo bash

## View logs
logs:
	@docker-compose logs -f

## Build, stop, remove and start containers
new: build stop clean start

## Restart containers
restart: stop start

## Start containers
start:
	@docker-compose up -d

## View containers states
status:
	@docker-compose ps

## Stop containers
stop:
	@docker-compose stop

## ------

# APPLICATION
APPLICATION := "Keepitsimple Blog"

# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

TARGET_MAX_CHAR_NUM=20
## Show this help
help:
	@echo '# ${YELLOW}${APPLICATION}${RESET} / ${GREEN}${ENV}${RESET}'
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			gsub(":", " ", helpCommand); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST) | sort

