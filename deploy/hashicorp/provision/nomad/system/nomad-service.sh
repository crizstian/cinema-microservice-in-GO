#!/bin/bash

exec nomad agent -dev-connect -config /var/nomad/config >>/var/log/nomad.log 2>&1
