# Overview

Vellup is a web service and API for easily integrating user accounts
into web applications without the hassle of managing it yourself.

# Development

When running the app locally, make sure to set the following environment
variables for any shells you start processes from:

```bash
$ export MAILGUN_API_URL=...
$ export HEROKU_SHARED_POSTGRESQL_URL=...
$ export REDISTOGO_URL=...
```

## Starting the web process

```bash
$ ruby bin/vellup
Cannot find or read /Users/jdixon/Projects/vellup/config/newrelic.yml
== Sinatra/1.3.1 has taken the stage on 4567 for development with backup from Thin
>> Thin web server (v1.2.11 codename Bat-Shit Crazy)
>> Maximum connections set to 1024
>> Listening on 0.0.0.0:4567, CTRL+C to stop
```

## Monitoring the Redis queue

```bash
$ redis-cli -h <host>.redistogo.com -p <port> -a <key>
redis viperfish.redistogo.com:9MONITOR
OK
1323175440.891197 "MONITOR"
```

## Starting the worker process

```bash
$ QUEUE=* rake queue:work
```
