# Overview

Vellup is a web service and API for easily integrating user accounts
into web applications without the hassle of managing it yourself.

# Local Development

When running the app locally, make sure to set the following environment
variables for any shells you start processes from:

```bash
$ source .env
```

Optionally, `unset DATABASE_URL` if you want to run against a local PostgreSQL server.

## Migrations

Supported tasks are <tt>:reset</tt>, <tt>:up</tt>, <tt>:down</tt> and <tt>:to<tt> (used with <tt>VERSION</tt>).

```bash
$ bundle exec run rake db:migrate:reset
Running rake db:migrate:reset attached to terminal... up, run.3
(in /app)
<= sq:migrate:reset executed
```

## Starting the web processes

```bash
$ ruby bin/vellup-web
Cannot find or read /Users/jdixon/Projects/vellup/config/newrelic.yml
== Sinatra/1.3.1 has taken the stage on 4567 for development with backup from Thin
>> Thin web server (v1.2.11 codename Bat-Shit Crazy)
>> Maximum connections set to 1024
>> Listening on 0.0.0.0:4567, CTRL+C to stop
```
```bash
$ ruby bin/vellup-api 
== Sinatra/1.3.1 has taken the stage on 4568 for development with backup from Thin
>> Thin web server (v1.2.11 codename Bat-Shit Crazy)
>> Maximum connections set to 1024
>> Listening on 0.0.0.0:4568, CTRL+C to stop
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
$ bundle exec rake queue:work QUEUE=*
```

## Running Tests

```bash
$ bundle exec rake test --trace
```
