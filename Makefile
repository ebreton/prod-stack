ps:
	# A lightly formatted version of docker ps
	docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}} ago'


check-env:
ifeq ($(wildcard .env),)
	cp .sample.env .env
	@echo "Generated \033[32m.env\033[0m"
	@echo "  \033[31m>> Check its default values\033[0m"
	@exit 1
else
include .env
export
endif

###
# Run traefik

TRAEFIK_DOMAIN?=localhost
WHOAMI_DOMAIN?=whoami.localhost
BASIC_AUTH?='test:$$apr1$$H6uskkkW$$IgXLP6ewTrSuBkTrqE8wj/'
LETSENCRYPT_EMAIL?=admin@domain.com
CLOUDFLARE_EMAIL?=admin@domain.com
CLOUDFLARE_API_KEY?=api-key

proxy: check-env
	LETSENCRYPT_EMAIL=$(LETSENCRYPT_EMAIL) \
		CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL} \
		CLOUDFLARE_API_KEY=${CLOUDFLARE_API_KEY} \
		TRAEFIK_DOMAIN=$(TRAEFIK_DOMAIN) \
		BASIC_AUTH=$(BASIC_AUTH) \
		SSH_PORT=$(SSH_PORT) \
		PG_PORT=$(PG_PORT) \
		docker-compose \
			-f docker-compose.networks.yml \
			-f docker-compose.proxy.yml \
			-f docker-compose.proxy.deploy.yml \
		config > docker-stack.yml

proxy-dev: check-env
	LETSENCRYPT_EMAIL=$(LETSENCRYPT_EMAIL) \
		CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL} \
		CLOUDFLARE_API_KEY=${CLOUDFLARE_API_KEY} \
		TRAEFIK_DOMAIN=$(TRAEFIK_DOMAIN) \
		BASIC_AUTH=$(BASIC_AUTH) \
		SSH_PORT=$(SSH_PORT) \
		PG_PORT=$(PG_PORT) \
		WHOAMI_DOMAIN=$(WHOAMI_DOMAIN) \
		docker-compose \
			-f docker-compose.networks.yml \
			-f docker-compose.proxy.yml \
			-f docker-compose.proxy.dev.yml \
		config > docker-stack.yml


###
# Run mariaDB

SECRET_ROOT:=$(shell cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
SECRET_USER:=$(shell cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

DEFAULT_PROTOCOL?=http
PHPMYADMIN_DOMAIN?=localhost
PHPMYADMIN_PATH?=phpmyadmin

check-db: check-env
ifeq ($(wildcard etc/db.env),)
	cp etc/db.sample.env etc/db.env
	sed -i s/password_root/$(SECRET_ROOT)/g etc/db.env
	sed -i s/password_user/$(SECRET_USER)/g etc/db.env
	@echo "Generated etc/db.env"
	@echo ">> Check values"
	@exit 1
endif

db: check-db
	DEFAULT_PROTOCOL=$(DEFAULT_PROTOCOL) \
		PHPMYADMIN_DOMAIN=$(PHPMYADMIN_DOMAIN) \
		PHPMYADMIN_PATH=$(PHPMYADMIN_PATH) \
		SSH_PORT=$(SSH_PORT) \
		PG_PORT=$(PG_PORT) \
		docker-compose \
			-f docker-compose.networks.yml \
			-f docker-compose.db.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml


###
# Run memcache

PHPMEMCACHEDADMIN_DOMAIN?=phpmemcachedadmin
PHPMEMCACHEDADMIN_PATH?=phpmemcachedadmin

cache:
	DEFAULT_PROTOCOL=$(DEFAULT_PROTOCOL) \
		PHPMEMCACHEDADMIN_DOMAIN=$(PHPMEMCACHEDADMIN_DOMAIN) \
		PHPMEMCACHEDADMIN_PATH=$(PHPMEMCACHEDADMIN_PATH) \
		SSH_PORT=$(SSH_PORT) \
		PG_PORT=$(PG_PORT) \
		docker-compose \
			-f docker-compose.networks.yml \
			-f docker-compose.cache.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml


###
# Run proxy, DB and memcache

all: check-env check-db
	DEFAULT_PROTOCOL=$(DEFAULT_PROTOCOL) \
		PHPMYADMIN_DOMAIN=$(PHPMYADMIN_DOMAIN) \
		PHPMYADMIN_PATH=$(PHPMYADMIN_PATH) \
		PHPMEMCACHEDADMIN_DOMAIN=$(PHPMEMCACHEDADMIN_DOMAIN) \
		PHPMEMCACHEDADMIN_PATH=$(PHPMEMCACHEDADMIN_PATH) \
		SSH_PORT=$(SSH_PORT) \
		PG_PORT=$(PG_PORT) \
		docker-compose \
			-f docker-compose.networks.yml \
			-f docker-compose.db.yml \
			-f docker-compose.cache.yml \
			-f docker-compose.proxy.yml \
			-f docker-compose.proxy.dev.yml \
		config > docker-stack.yml


###
# Add an extra container (for the sake of another example)

HELLO_DOMAIN?=hello.localhost

hello: check-env
	docker kill hello-world || true
	HELLO_DOMAIN=$(HELLO_DOMAIN) \
		docker run -d --name hello-world --rm \
			--network=$(TRAEFIK_PUBLIC_NETWORK) \
			--label "traefik.enable=true" \
			--label "traefik.docker.network=$(TRAEFIK_PUBLIC_NETWORK)" \
			--label "traefik.http.routers.hello.entrypoints=websecure" \
			--label "traefik.http.routers.hello.tls.certresolver=cloudflare" \
			--label "traefik.http.routers.hello.rule=Host(\`$(HELLO_DOMAIN)\`)" \
		dockercloud/hello-world

###
# Operational commands

check-stack:
ifeq ($(wildcard docker-stack.yml),)
	@echo "docker-stack.yml file is missing"
	@echo ">> use 'make proxy|db|cache|all'"
	@exit 1
endif

pull: check-stack
	docker network create $(TRAEFIK_PUBLIC_NETWORK)
	docker-compose -f docker-stack.yml pull

# used for local developement
build: check-stack proxy-dev
	docker-compose -f docker-stack.yml build

up: check-stack
	docker-compose -f docker-stack.yml up -d

down: check-stack
	docker-compose -f docker-stack.yml down

stop: check-stack
	docker-compose -f docker-stack.yml stop

logs: check-stack
	docker-compose -f docker-stack.yml logs --tail 10 -f
