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

1. Copy paste `./etc/traefik.toml.sample` to `./etc/traefik.toml` 
1. add your email in the `acme` section around [line 21](https://github.com/ebreton/prod-stack/blob/master/etc/traefik.toml.sample#L21). This will allow Traefik to register certificates for you on Let's Encrypt.
1. as an optionnal step, if you wish to make use of Basic Authentication for some services (like traefik `dashboard` or  `phpmemcachedadmin`, you need to set your user and hashed password around [line 15](https://github.com/ebreton/prod-stack/blob/master/etc/traefik.toml.sample#L15))
1. With this, you will have everything set with a one-word single line: `make`

        $ make
        cp etc/db.sample.env etc/db.env
        sed -i s/password/ul73I0PHnsQN8pW1eetFq1NVR67StMWg/g etc/db.env
        Generated etc/db.env
        docker-compose pull
        ...

### Sanity checks

You will be able to check that everything went ok either through the logs, or by running `docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'`

    $ docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'
    NAMES               IMAGE                           STATUS ago
    nginx-entrypoint    nginx                           Up 14 minutes ago
    traefik             traefik:latest                  Up 14 minutes ago
    db-shared           mariadb:latest                  Up 14 minutes ago
    phpmyadmin          phpmyadmin/phpmyadmin           Up 14 minutes ago
    memcached           memcached                       Up 14 minutes ago
    phpmemcacheadmin    jacksoncage/phpmemcachedadmin   Up 14 minutes ago

You should also be able to:

* connect to traefik dashboard on <http://localhost:8081/dashboard/>
* connect to phpmyadmin on <http://localhost/phpmyadmin/>
* connect to phpmemcachedamdin on <http://localhost:8081/phpmemcacheadmin/>

## Components

### Web service

#### in common words...

The web service used `nginx` as gateway on port 80. It is responsible for HTTPs redirection, and for any redirections you see fit. Most of the traffic will probably be redirected to `traefik`, the container gateway, which also handles the HTTPs encryption.

    NAMES               IMAGE                           STATUS ago
    nginx-entrypoint    nginx                           Up 14 minutes ago
    traefik             traefik:latest                  Up 14 minutes ago

#### step by step

* Nginx redirects http to https
    * allowing you to define exceptions in an nginx conf
* Nginx proxies to traeffik

* Traefik manages the certificates through Let's Encrypt
* Traefik set up routes automatically to new containers thanks to labels
    * based on host
    * or on path
* Traefik proxies to the appropriate container

#### Basic Authentication

Note that you might need Basic Authentication for some services. An entrypoint (`httpBA`) is nearly setup for you on the `./etc/traefik.toml`, you will just need to update your user and password in the config file, around line 15.

### Database

    NAMES               IMAGE                           STATUS ago
    db-shared           mariadb:latest                  Up 14 minutes ago
    phpmyadmin          phpmyadmin/phpmyadmin           Up 14 minutes ago

### Caching

    NAMES               IMAGE                           STATUS ago
    memcached           memcached                       Up 14 minutes ago
    phpmemcacheadmin    jacksoncage/phpmemcachedadmin   Up 14 minutes ago
