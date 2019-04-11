#!/bin/bash
export AIRFLOW__CORE__SQL_ALCHEMY_CONN=$1
export AIRFLOW__CELERY__BROKER_URL=$2
export AIRFLOW__CELERY__CELERY_RESULT_BACKEND=$2
while [ True ]
do
	airflow scheduler -r 2900 >> $AIRFLOW_HOME/startup_log/airflow-scheduler.log 2>&1 &
	sleep 5m
done