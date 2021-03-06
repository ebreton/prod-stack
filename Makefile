ps:
	# A lightly formatted version of docker ps
	docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}} ago'

init: check-env check-db pull

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

proxy-swarm: check-env
	docker-compose \
		-f docker-compose.networks.yml \
		-f docker-compose.proxy.yml \
		-f docker-compose.proxy.deploy.yml \
	config > docker-stack.yml

proxy: check-env
	docker-compose \
		-f docker-compose.networks.yml \
		-f docker-compose.proxy.yml \
		-f docker-compose.proxy.local.yml \
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
	@echo "  \033[31m>> Check its default values\033[0m"
	@exit 1
endif

db: check-db
	docker-compose \
		-f docker-compose.networks.yml \
		-f docker-compose.db.yml \
		-f docker-compose.proxy.yml \
		-f docker-compose.proxy.local.yml \
	config > docker-stack.yml


###
# Run memcache

PHPMEMCACHEDADMIN_DOMAIN?=phpmemcachedadmin
PHPMEMCACHEDADMIN_PATH?=phpmemcachedadmin

cache:
	docker-compose \
		-f docker-compose.networks.yml \
		-f docker-compose.cache.yml \
		-f docker-compose.proxy.yml \
	config > docker-stack.yml


###
# Run proxy, DB and memcache

all: check-env check-db
	docker-compose \
		-f docker-compose.networks.yml \
		-f docker-compose.db.yml \
		-f docker-compose.cache.yml \
		-f docker-compose.proxy.yml \
		-f docker-compose.proxy.local.yml \
	config > docker-stack.yml


###
# Add an extra container (for the sake of another example)

HELLO_DOMAIN?=hello.localhost

hello: check-env
	docker kill hello-world || true
	docker run -d --name hello-world --rm \
		--network=$(TRAEFIK_PUBLIC_NETWORK) \
		--label "traefik.enable=true" \
		--label "traefik.docker.network=$(TRAEFIK_PUBLIC_NETWORK)" \
		--label "traefik.http.routers.plain-hello.entrypoints=web" \
		--label "traefik.http.routers.plain-hello.rule=Host(\`$(HELLO_DOMAIN)\`)" \
		--label "traefik.http.routers.plain-hello.middlewares=redirect-to-https" \
		--label "traefik.http.routers.hello.entrypoints=websecure" \
		--label "traefik.http.routers.hello.tls.certresolver=dns-ovh" \
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

pull: proxy check-stack
	docker network create $(TRAEFIK_PUBLIC_NETWORK) || true
	docker-compose -f docker-stack.yml pull $(services)

# used for local developement
build: proxy check-stack
	docker-compose -f docker-stack.yml build $(services)

up: check-stack
	docker-compose -f docker-stack.yml up -d $(services) 

down: check-stack
	docker-compose -f docker-stack.yml down

stop: check-stack
	docker-compose -f docker-stack.yml stop $(services)

logs: check-stack
	docker-compose -f docker-stack.yml logs --tail 10 -f $(services)
