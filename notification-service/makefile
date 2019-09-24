TEST?=$$(go list ./... |grep -v 'vendor' |grep -v 'utils')
GOFMT_FILES?=$$(find . -name '*.go' |grep -v vendor)
SHELL := /bin/bash

test: 
	go test $(TEST) -timeout=30s -v
	
testacc: 
	# source bin/env
	TF_ACC=1 go test $(TEST) -v $(TESTARGS) -timeout 120m -coverprofile c.out
	go tool cover -html=c.out

