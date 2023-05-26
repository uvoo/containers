#!/bin/bash
set -eu
envtpl --keep-template /etc/rsyslog.conf.tpl
/usr/sbin/rsyslogd -n
