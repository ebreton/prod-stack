SECRET:=$(shell cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

ps:
	# A lightly formatted version of docker ps
	docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'

proxy:
ifeq ($(wildcard etc/traefik.toml),)
	cp etc/traefik.toml.sample etc/traefik.toml
	@echo "Generated etc/traefik.toml"
else
	docker-compose \
		-f docker-compose.proxy.yml \
	config > docker-stack.yml
	make all
endif

db:
ifeq ($(wildcard etc/db.env),)
	cp etc/db.sample.env etc/db.env
	sed -i s/password/$(SECRET)/g etc/db.env
	@echo "Generated etc/db.env"
else
	DEFAULT_PROTOCOL=http \
		PHPMYADMIN_DOMAIN=localhost \
		PHPMYADMIN_PATH=phpmyadmin \
		docker-compose \
			-f docker-compose.db.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml
	make all
endif

cache:
	PHPMEMCACHEDADMIN_DOMAIN=phpmemcachedadmin \
		docker-compose \
			-f docker-compose.cache.yml \
			-f docker-compose.proxy.yml \
		config > docker-stack.yml
	make all

check-stack:
ifeq ($(wildcard docker-stack.yml),)
	@echo "docker-stack.yml file is missing"
	@exit 1
endif

all: check-stack
	docker-compose -f docker-stack.yml build 
	docker-compose -f docker-stack.yml up -d
	docker-compose -f docker-stack.yml logs --tail 20 -f

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
