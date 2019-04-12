#!/usr/bin/env bash

$(echo "airflow" | sudo -S logrotate -f /etc/logrotate.d/airflow)
if test  $? -eq 0; then
    ls -lsrt /usr/local/airflow/startup_log
    $(rm /usr/local/airflow/startup_log/*.gz)
    exit $?
fi