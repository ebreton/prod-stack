ps:
	# A lightly formatted version of docker ps
	docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}} ago'


###
# Run NGiny and traefik

TRAEFIK_DOMAIN?=localhost
TRAEFIK_WEBMIN?=traefik.localhost
LETSENCRYPT_EMAIL?=admin@domain.com
CLOUDFLARE_EMAIL?=admin@domain.com
CLOUDFLARE_API_KEY?=api-key

check-traefik:
ifeq ($(wildcard etc/traefik.toml),)
	cp etc/traefik.toml.sample etc/traefik.toml
	@echo "Generated etc/traefik.toml"
	@echo ">> Check values"
	@exit 1
endif

proxy: check-traefik
	LETSENCRYPT_EMAIL=$(LETSENCRYPT_EMAIL) \
		CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL} \
		CLOUDFLARE_API_KEY=${CLOUDFLARE_API_KEY} \
		TRAEFIK_DOMAIN=$(TRAEFIK_DOMAIN) \
		TRAEFIK_WEBMIN=$(TRAEFIK_WEBMIN) \
		docker-compose \
			-f docker-compose.proxy.deploy.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml

proxy-dev: check-traefik
	LETSENCRYPT_EMAIL=$(LETSENCRYPT_EMAIL) \
		CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL} \
		CLOUDFLARE_API_KEY=${CLOUDFLARE_API_KEY} \
		TRAEFIK_DOMAIN=$(TRAEFIK_DOMAIN) \
		TRAEFIK_WEBMIN=$(TRAEFIK_WEBMIN) \
		docker-compose \
			-f docker-compose.proxy.dev.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml


###
# Run mariaDB

SECRET_ROOT:=$(shell cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
SECRET_USER:=$(shell cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

DEFAULT_PROTOCOL?=http
PHPMYADMIN_DOMAIN?=localhost
PHPMYADMIN_PATH?=phpmyadmin

check-db:
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
		docker-compose \
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
		docker-compose \
			-f docker-compose.cache.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml


###
# Run proxy, DB and memcache

all: check-traefik check-db
	DEFAULT_PROTOCOL=$(DEFAULT_PROTOCOL) \
		PHPMYADMIN_DOMAIN=$(PHPMYADMIN_DOMAIN) \
		PHPMYADMIN_PATH=$(PHPMYADMIN_PATH) \
		PHPMEMCACHEDADMIN_DOMAIN=$(PHPMEMCACHEDADMIN_DOMAIN) \
		PHPMEMCACHEDADMIN_PATH=$(PHPMEMCACHEDADMIN_PATH) \
		docker-compose \
			-f docker-compose.db.yml \
			-f docker-compose.cache.yml \
			-f docker-compose.proxy.dev.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml


###
# Operational commands

check-stack:
ifeq ($(wildcard docker-stack.yml),)
	@echo "docker-stack.yml file is missing"
	@echo ">> use 'make proxy|db|cache|all'"
	@exit 1
endif

pull: check-stack
	docker-compose -f docker-stack.yml pull

up: check-stack
	docker-compose -f docker-stack.yml up -d

down: check-stack
	docker-compose -f docker-stack.yml down

stop: check-stack
	docker-compose -f docker-stack.yml stop

logs: check-stack up
	docker-compose -f docker-stack.yml logs --tail 10 -f
