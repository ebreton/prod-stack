README
==

This repository will provide you with a (not so) basic dockerized web stack :

* a web service based on [traefik](https://traefik.io) and [nginx](https://nginx.org/en/)
* a [mariaDB](https://mariadb.org) (along with a [phpmyadmin](https://www.phpmyadmin.net))
* a [memcached](https://memcached.org) server (along with a [phpmemcachedadmin](https://github.com/elijaa/phpmemcachedadmin))

Table of Content
--

<!-- TOC -->

- [Configuration](#configuration)
    - [Pre-requisites](#pre-requisites)
    - [Setup](#setup)
    - [Sanity checks](#sanity-checks)
    - [Router check](#router-check)
- [Components](#components)
    - [Web service](#web-service)
        - [in common words...](#in-common-words)
        - [step by step](#step-by-step)
        - [Basic Authentication](#basic-authentication)
    - [Database](#database)
    - [Caching](#caching)

<!-- /TOC -->

## Configuration

### Pre-requisites

* make
* [docker](https://www.docker.com/community-edition)
* [docker-compose](https://docs.docker.com/compose/install/)

### Setup

You will have a default runnable stack set with a one-word single line: `make`

        $ make
        cp etc/traefik.toml.sample etc/traefik.toml
        cp etc/db.sample.env etc/db.env
        sed -i s/password/ul73I0PHnsQN8pW1eetFq1NVR67StMWg/g etc/db.env
        Generated etc/db.env
        docker-compose pull
        ...

But you will probably want to customize at least the two following settings:

* set your own email in the `acme` section around [line 21](https://github.com/ebreton/prod-stack/blob/master/etc/traefik.toml.sample#L21). This will allow `traefik` to register certificates for you on Let's Encrypt.
* set your own user for Basic Authentication (used by some services like traefik `dashboard` or `phpmemcachedadmin`). The default is set to _test/test_. Change it to your user and hashed password around [line 15](https://github.com/ebreton/prod-stack/blob/master/etc/traefik.toml.sample#L15). `htpasswd` will help you in this, check [traefic doc](https://docs.traefik.io/configuration/entrypoints/#basic-authentication) for more details

### Sanity checks

You will be able to check that everything went ok either through the logs, or by running `docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'`

    $ docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'
    NAMES               IMAGE                           STATUS ago
    nginx-entrypoint    nginx                           Up 14 minutes ago
    traefik             traefik:latest                  Up 14 minutes ago
    db-shared           mariadb:latest                  Up 14 minutes ago
    phpmyadmin          phpmyadmin/phpmyadmin           Up 14 minutes ago
    memcached           memcached                       Up 14 minutes ago
    phpmemcachedadmin   jacksoncage/phpmemcachedadmin   Up 14 minutes ago

You should also be able to:

* connect to traefik dashboard on <http://localhost:8081/dashboard/> (provided you set up Basic Authentication as described in the [Setup](#setup) section above)
* connect to phpmyadmin on <http://localhost/phpmyadmin/>
* connect to phpmemcachedamdin on <http://localhost:8081/phpmemcachedadmin/>

The URLs above are defined from ./etc/urls.env:

    DEFAULT_PROTOCOL=http
    PHPMYADMIN_DOMAIN=localhost
    PHPMYADMIN_PATH=phpmyadmin
    PHPMEMCACHEDADMIN_DOMAIN=phpmemcachedadmin

### Router check

In order to check that the routing is correctly managed by `nginx` and `traefik`, you can launch a simple [hello-world container](https://github.com/docker/dockercloud-hello-world/blob/master/README.md).

The following command will launch and route this on <http://localhost/hello>. It makes use of labels as described with more details in the following section

    docker run -d --name hello-world --rm \
    	--network=proxy \
		--label "traefik.enable=true" \
		--label "traefik.backend=localhost" \
		--label "traefik.frontend.entryPoints=http" \
		--label "traefik.frontend.rule=Host:localhost;PathPrefix:/hello" \
        dockercloud/hello-world

Check <http://localhost/hello>. You can then stop the container with 

    $ docker stop hello-world
    hello-world

## Components

### Web service

#### in common words...

`nginx` is the your entry point: it acts as gateway on port 80. It is responsible for HTTPs redirection, and for any redirections you see fit (configuration samples are provided in ./etc folder) . Most of the traffic will probably be redirected to `traefik`, the container gateway (which handles the HTTPs encryption by the way).

    NAMES               IMAGE                           STATUS ago
    nginx-entrypoint    nginx                           Up 14 minutes ago
    traefik             traefik:latest                  Up 14 minutes ago

#### step by step

* Nginx serves requests on port 80
* Nginx proxies to traeffik

* Nginx can redirect http to https (see [./etc/002-redirects.conf.sample](https://github.com/ebreton/prod-stack/blob/master/etc/002-redirects.conf.sample))
    * allowing you to define exceptions in an nginx conf, e.g. requests from Let's Encrypt
* Nginx can redirect domain.com to www.domain.com (see [./etc/001-no-https.conf.sample](https://github.com/ebreton/prod-stack/blob/master/etc/001-no-https.conf.sample))

* Traefik serves requests on port 443 
    * and 8081, which is used for Basic Authentication
* Traefik manages the certificates through Let's Encrypt
* Traefik set up routes automatically to new containers thanks to labels (see example in [Router check](#router-check))
* Traefik proxies to the appropriate container

#### Basic Authentication

Note that you might need Basic Authentication for some services. An entrypoint (`httpBA`) is nearly setup for you on the `./etc/traefik.toml` and will be available on port 8081. You will just need to update your user and password in the config file, around line 15.

`htpasswd` will help you in this, check [traefic doc](https://docs.traefik.io/configuration/entrypoints/#basic-authentication) for more details

### Database

    NAMES               IMAGE                           STATUS ago
    db-shared           mariadb:latest                  Up 14 minutes ago
    phpmyadmin          phpmyadmin/phpmyadmin           Up 14 minutes ago

### Caching

    NAMES               IMAGE                           STATUS ago
    memcached           memcached                       Up 14 minutes ago
    phpmemcachedadmin    jacksoncage/phpmemcachedadmin   Up 14 minutes ago
