#!/bin/bash
. /etc/environment

exec nomad agent -config /var/nomad/config >>/var/log/nomad.log 2>&1
