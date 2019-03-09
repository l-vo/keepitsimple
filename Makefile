.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: build clean exec start status stop

## ------

## Build Dockerfiles
build:
	@if [ -z ${ENV_PROD} ];\
	then\
		docker-compose build;\
	fi

## Remove containers
clean:
	@if [ -z ${ENV_PROD} ];\
    	then\
    		docker-compose rm -vf;\
    	else\
    		docker rm -vf keepitsimple;\
    	fi

## Exec a shell into hexo container
exec:
	@if [ -z ${ENV_PROD} ];\
	then\
		docker-compose exec hexo bash;\
	fi

## Start containers
start:
	@if [ -z ${ENV_PROD} ];\
	then\
		docker-compose up -d;\
	else\
		docker run -d --name keepitsimple -v `pwd`/generated/public/:/usr/share/nginx/html/ --restart always nginx;\
	fi

## View containers states
status:
	@if [ -z ${ENV_PROD} ];\
	then\
		docker-compose ps;\
	else\
		docker ps --filter name=^keepitsimple$$;\
	fi

## Stop containers
stop:
	@if [ -z ${ENV_PROD} ];\
	then\
		docker-compose stop;\
	else\
		docker stop keepitsimple;\
	fi

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

