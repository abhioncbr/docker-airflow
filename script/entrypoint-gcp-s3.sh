#!/usr/bin/env bash

AIRFLOW_HOME="/usr/local/airflow"
CMD="airflow"

#google client platform authentication
echo "setting up google cloud platform ..."
gcloud auth activate-service-account <gcp-service-account-user> --key-file=/usr/local/airflow/.gcp/gcp-credentials.json--project=<project-name>

# exporting google application credentials.
export GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json

# Starting airflow server.
# Steps are : initialising airflow database, starting redis server, starting airflow scheduler, starting airflow webserver
if [ "$#" -eq 3 ] && [ "$1" = "server" ]; then
	# setting up the arguments.
    COMMAND=$1
	MYSQL_CONNECTION=$2
	S3_LOG_DIRECTORY=$3

	# Configure airflow with mysql connection string.
	if [ -v MYSQL_CONNECTION ]; then
    	echo "setting mysql database connection string ..."
    	echo "Setting AIRFLOW__CORE__SQL_ALCHEMY_CONN=${MYSQL_CONNECTION}"
    	export AIRFLOW__CORE__SQL_ALCHEMY_CONN=$MYSQL_CONNECTION

    	echo "export AIRFLOW__CORE__SQL_ALCHEMY_CONN="$MYSQL_CONNECTION>>~/.bashrc
        echo "AIRFLOW__CORE__SQL_ALCHEMY_CONN="$MYSQL_CONNECTION>>~/.profile
	fi

	# Configure airflow with s3 log directory.
	if [ -v S3_LOG_DIRECTORY ]; then
    	echo "setting s3 log directory ..."
    	echo "Setting AIRFLOW__CORE__S3_LOG_FOLDER=${S3_LOG_DIRECTORY}"
    	export AIRFLOW__CORE__S3_LOG_FOLDER=$S3_LOG_DIRECTORY
    	echo "export AIRFLOW__CORE__S3_LOG_FOLDER="$S3_LOG_DIRECTORY>>~/.bashrc
        echo "AIRFLOW__CORE__S3_LOG_FOLDER="$S3_LOG_DIRECTORY>>~/.profile

        S3_TASK='s3.task'
        AIRFLOW__CORE__TASK_LOG_READER=$S3_TASK
        export AIRFLOW__CORE__S3_LOG_FOLDER=$S3_TASK
        echo "export AIRFLOW__CORE__TASK_LOG_READER="$S3_TASK>>~/.bashrc
        echo "AIRFLOW__CORE__TASK_LOG_READER="$S3_TASK>>~/.profile

        S3_LOGGING_CLASS='airflow.config_templates.s3_logger.LOGGING_CONFIG'
        AIRFLOW__CORE__LOGGING_CONFIG_CLASS=$S3_LOGGING_CLASS
        export AIRFLOW__CORE__LOGGING_CONFIG_CLASS=$S3_TASK
        echo "export AIRFLOW__CORE__LOGGING_CONFIG_CLASS="$S3_TASK>>~/.bashrc
        echo "AIRFLOW__CORE__LOGGING_CONFIG_CLASS="$S3_TASK>>~/.profile
	fi

# ============= Starting server processes =====================

	# Starting redis first as redis connection string is required for airflow.
	echo starting redis
	exec -a redis-server redis-server --protected-mode no > $AIRFLOW_HOME/startup_log/redis-server.log 2>&1 &
	sleep 5
	case "$(pidof redis-server | wc -w)" in
		0)  echo "redis is not started .. exiting."
    		exit 1
    		;;
		1)  echo "redis-server is up & running, having pid:" $!
    		;;
	esac
	REDIS_CONNECTION=redis://localhost:6379/0
	echo "Setting AIRFLOW__CELERY__BROKER_URL=${REDIS_CONNECTION}"
    export AIRFLOW__CELERY__BROKER_URL=$REDIS_CONNECTION
    echo "Setting AIRFLOW__CELERY__CELERY_RESULT_BACKEND=${REDIS_CONNECTION}"
    export AIRFLOW__CELERY__CELERY_RESULT_BACKEND=$REDIS_CONNECTION

    echo "export AIRFLOW__CELERY__BROKER_URL="$REDIS_CONNECTION>>~/.bashrc
    echo "AIRFLOW__CELERY__BROKER_URL="$REDIS_CONNECTION>>~/.profile
	echo "export AIRFLOW__CELERY__CELERY_RESULT_BACKEND="$REDIS_CONNECTION>>~/.bashrc
    echo "AIRFLOW__CELERY__CELERY_RESULT_BACKEND="$REDIS_CONNECTION>>~/.profile

	# Initialising airflow database.
	echo "initialising airfow db"
	$CMD initdb
	if [ "$?" -ne 0 ]; then
		echo "airflow initdb command is not successful. Exiting."
		exit 1
	fi

	#executing python script for adding user in-case if user is not present
	#echo "executing user_add python script for adding user, if not present"
	echo "Running user_add script in-case user is not present."
	python user_add.py

	# Starting airflow scheduler and writing scheduler log in file 'startup_log/airflow-scheduler.log'.
	echo starting airflow scheduler
	exec -a airflow-scheduler $CMD scheduler > $AIRFLOW_HOME/startup_log/airflow-scheduler.log 2>&1 &
	sleep 5
	case "$(pidof /usr/bin/python /usr/local/bin/airflow scheduler | wc -w)" in
		0)  echo "airflow scheduler is not started .. exiting."
    		exit 1
    		;;
		1)  echo "airflow scheduler is up & running, having pid:" $!
    		;;
	esac

	#running shell script to restart airflow scheduler in every 5 minutes.
	echo "Running shell script to restart airflow scheduler in every 5 minutes."
	sh ./execute_continous_scheduler.sh $MYSQL_CONNECTION $REDIS_CONNECTION &

	# Starting airflow webserver and writing log in to the file 'startup_log/airflow-server.log'.
	echo "starting airflow webserver"
	exec -a airflow-webserver $CMD webserver > $AIRFLOW_HOME/startup_log/airflow-server.log 2>&1

# Starting airflow worker.
elif [ "$#" -eq 4 ] && [ "$1" = "worker" ]; then
	# setting up the arguments.
	COMMAND=$1
	MYSQL_CONNECTION=$2
	REDIS_CONNECTION=$3
	S3_LOG_DIRECTORY=$4

	# Configure airflow with mysql connection string.
	if [ -v MYSQL_CONNECTION ]; then
    	echo "setting mysql database connection string ..."
    	echo "Setting AIRFLOW__CORE__SQL_ALCHEMY_CONN=${MYSQL_CONNECTION}"
    	export AIRFLOW__CORE__SQL_ALCHEMY_CONN=$MYSQL_CONNECTION

    	echo "export AIRFLOW__CORE__SQL_ALCHEMY_CONN="$MYSQL_CONNECTION>>~/.bashrc
        echo "AIRFLOW__CORE__SQL_ALCHEMY_CONN="$MYSQL_CONNECTION>>~/.profile
	fi

	# Configure airflow with s3 log directory.
	if [ -v S3_LOG_DIRECTORY ]; then
    	echo "setting s3 log directory ..."
    	echo "Setting AIRFLOW__CORE__S3_LOG_FOLDER=${S3_LOG_DIRECTORY}"
    	export AIRFLOW__CORE__S3_LOG_FOLDER=$S3_LOG_DIRECTORY
    	echo "export AIRFLOW__CORE__S3_LOG_FOLDER="$S3_LOG_DIRECTORY>>~/.bashrc
        echo "AIRFLOW__CORE__S3_LOG_FOLDER="$S3_LOG_DIRECTORY>>~/.profile

        S3_TASK='s3.task'
        AIRFLOW__CORE__TASK_LOG_READER=$S3_TASK
        export AIRFLOW__CORE__S3_LOG_FOLDER=$S3_TASK
        echo "export AIRFLOW__CORE__TASK_LOG_READER="$S3_TASK>>~/.bashrc
        echo "AIRFLOW__CORE__TASK_LOG_READER="$S3_TASK>>~/.profile

        S3_LOGGING_CLASS='airflow.config_templates.s3_logger.LOGGING_CONFIG'
        AIRFLOW__CORE__LOGGING_CONFIG_CLASS=$S3_LOGGING_CLASS
        export AIRFLOW__CORE__LOGGING_CONFIG_CLASS=$S3_TASK
        echo "export AIRFLOW__CORE__LOGGING_CONFIG_CLASS="$S3_TASK>>~/.bashrc
        echo "AIRFLOW__CORE__LOGGING_CONFIG_CLASS="$S3_TASK>>~/.profile
	fi

	# Configure airflow with redis string for celery executor.
	if [ -v REDIS_CONNECTION ]; then
    	echo "setting redis connection string ..."

    	echo "Setting AIRFLOW__CELERY__BROKER_URL=${REDIS_CONNECTION}"
    	export AIRFLOW__CELERY__BROKER_URL=$REDIS_CONNECTION

    	echo "Setting AIRFLOW__CELERY__CELERY_RESULT_BACKEND=${REDIS_CONNECTION}"
    	export AIRFLOW__CELERY__CELERY_RESULT_BACKEND=$REDIS_CONNECTION

    	echo "export AIRFLOW__CELERY__BROKER_URL="$REDIS_CONNECTION>>~/.bashrc
        echo "AIRFLOW__CELERY__BROKER_URL="$REDIS_CONNECTION>>~/.profile
        echo "export AIRFLOW__CELERY__CELERY_RESULT_BACKEND="$REDIS_CONNECTION>>~/.bashrc
        echo "AIRFLOW__CELERY__CELERY_RESULT_BACKEND="$REDIS_CONNECTION>>~/.profile
	fi

	# Starting worker processes.
	echo "starting airflow celery flower"
    exec $CMD flower > $AIRFLOW_HOME/startup_log/airflow-celery-flower.log 2>&1 &
    sleep 5
    case "$(pidof /usr/bin/python /usr/local/bin/flower | wc -w)" in
		0)  echo "airflow flower is not started .. exiting."
    		exit 1
    		;;
		1)  echo "airflow flower is up & running, having pid:" $!
    		;;
	esac

	echo "starting airflow worker"
	QUEUE="default,$(hostname)"
	exec $CMD worker -q ${QUEUE} > $AIRFLOW_HOME/startup_log/airflow-worker.log 2>&1

# arguments is not in order
else
  echo "Please provide required arguments as per below information."
  echo "For starting server arguments are::  1): 'server' & 2): mysql connection string e.g (mysql://airflow:airflow@localhost:3306/airflow) 3): s3 log directory path"
  echo "For starting worker arguments are::  1): 'worker' , 2): mysql connection string e.g (mysql://airflow:airflow@localhost:3306/airflow) & 3): redis connection string e.g (redis://localhost:6379/0) 4): s3 log directory path"
fi