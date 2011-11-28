# API and Site Map

## Overview

## API Methods

### Sessions

* POST /login
* GET /logout

### Accounts

* GET /accounts/add
* POST /accounts/add
* GET /accounts/:id
* PUT /accounts/:id
* DELETE /accounts/:id

### Users

* GET /signup -> /users/add
* GET /users/add -> /accounts/vellup/users/add
* GET /users/:id -> /accounts/vellup/users/:id
* GET /accounts/:id/users/add
* POST /accounts/:id/users/add
* GET /accounts/:id/users/:id
* PUT /accounts/:id/users/:id
* GET /accounts/:id/users/:id/confirm
* POST /accounts/:id/users/:id/confirm
* GET /accounts/:id/users/:id/confirm/:token

