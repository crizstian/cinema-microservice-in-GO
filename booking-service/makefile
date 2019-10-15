TEST?=$$(go list ./... |grep -v 'vendor' |grep -v 'utils')
GOFMT_FILES?=$$(find . -name '*.go' |grep -v vendor)
SHELL := /bin/bash

test: 
	go test $(TEST) -timeout=30s -v

integrationTest:
	go test -v -timeout 30s ./integration_test -run TestBookingEndpoint -count=1 | sed ''/PASS/s//$(printf "\033[32mPASS\033[0m")/'' | sed ''/FAIL/s//$(printf "\033[31mFAIL\033[0m")/''
	
testacc: 
	# source bin/env
	TF_ACC=1 go test $(TEST) -v $(TESTARGS) -timeout 120m -coverprofile c.out
	go tool cover -html=c.out

