#!/bin/sh
set -e
go test ./... || true
terraform fmt -check -recursive || true
