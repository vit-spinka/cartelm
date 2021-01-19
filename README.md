# cartelm
Download and send a cartoon every day. Manage subscriptions.


## AWS

* Host a domain
* DynamoDB - one table, on-demand
* Lambda scheduled to download the comics, based on DynamoDB query/scan
* Lambda REST API: list all; update; create; get; delete
* API gateway
* S3 static hosting
* S3 terraform state

## Authentication

* Auth0
* ?? authenticate vs REST API?

## Elm App

* Auth0
* call REST API
* S3 static hosting HTML/JS

## Terraform

* S3 backend
* DynamoDB locking

# v0

Terraform

* S3 bucket for static contents
* Lambda REST API for list all
* API gateway
* Elm app show all subscriptions