ps:
	# A lightly formatted version of docker ps
	docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'


###
# Run NGiny and traefik
check-traefik:
ifeq ($(wildcard etc/traefik.toml),)
	cp etc/traefik.toml.sample etc/traefik.toml
	@echo "Generated etc/traefik.toml"
endif

proxy: check-traefik
	docker-compose \
		-f docker-compose.proxy.yml \
	config > docker-stack.yml
	make pull


###
# Run mariaDB

SECRET_ROOT:=$(shell cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
SECRET_USER:=$(shell cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

DEFAULT_PROTOCOL?=http
PHPMYADMIN_DOMAIN?=localhost
PHPMYADMIN_PATH?=phpmyadmin

db:
ifeq ($(wildcard etc/db.env),)
	cp etc/db.sample.env etc/db.env
	sed -i s/password_root/$(SECRET_ROOT)/g etc/db.env
	sed -i s/password_user/$(SECRET_USER)/g etc/db.env
	@echo "Generated etc/db.env"
else
	DEFAULT_PROTOCOL=$(DEFAULT_PROTOCOL) \
		PHPMYADMIN_DOMAIN=$(PHPMYADMIN_DOMAIN) \
		PHPMYADMIN_PATH=$(PHPMYADMIN_PATH) \
		docker-compose \
			-f docker-compose.db.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml
	make pull
endif


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
	make pull


###
# Run proxy, DB and memcache

all: check-traefik
ifeq ($(wildcard etc/db.env),)
	cp etc/db.sample.env etc/db.env
	sed -i s/password_root/$(SECRET_ROOT)/g etc/db.env
	sed -i s/password_user/$(SECRET_USER)/g etc/db.env
	@echo "Generated etc/db.env"
else
	DEFAULT_PROTOCOL=$(DEFAULT_PROTOCOL) \
		PHPMYADMIN_DOMAIN=$(PHPMYADMIN_DOMAIN) \
		PHPMYADMIN_PATH=$(PHPMYADMIN_PATH) \
		PHPMEMCACHEDADMIN_DOMAIN=$(PHPMEMCACHEDADMIN_DOMAIN) \
		PHPMEMCACHEDADMIN_PATH=$(PHPMEMCACHEDADMIN_PATH) \
		docker-compose \
			-f docker-compose.db.yml \
			-f docker-compose.cache.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml
	make pull
endif


###
# Operational commands

check-stack:
ifeq ($(wildcard docker-stack.yml),)
	@echo "docker-stack.yml file is missing"
	@exit 1
endif

pull: check-stack
	docker-compose -f docker-stack.yml pull

build: check-stack
	docker-compose -f docker-stack.yml build

up: check-stack
	docker-compose -f docker-stack.yml up -d

down: check-stack
	docker-compose -f docker-stack.yml down

stop: check-stack
	docker-compose -f docker-stack.yml stop

logs: check-stack up
	docker-compose -f docker-stack.yml logs --tail 10 -f
