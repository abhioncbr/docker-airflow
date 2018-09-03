#!/usr/bin/env bash

AIRFLOW_HOME="/usr/local/airflow"
CMD="airflow"

# Starting airflow container in standalone mode.
# Steps are : initialising airflow database, starting airflow scheduler & airflow webserver.
if [ "$#" -eq 3 ] && [ "$1" = "standalone" ]; then
	GCP_SERVICE_ACCOUNT_USER=$2
	GCP_PROJECT_NAME=$3

    #google client platform authentication
    echo "setting up google cloud platform ..."
    gcloud auth activate-service-account ${GCP_SERVICE_ACCOUNT_USER} --key-file=/usr/local/airflow/.gcp/gcp-credentials.json --project=${GCP_PROJECT_NAME}
    # exporting google application credentials.
    export GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json
    echo "export GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json">>~/.bashrc
    echo "GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json">>~/.profile

	# Initialising airflow database.
    echo "initialising airfow db"
	$CMD initdb
	sleep 2
    echo "Done with airfow db"

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

	# Starting airflow webserver and writing log in to the file 'startup_log/airflow-server.log'.
	echo "starting airflow webserver"
	exec -a airflow-webserver $CMD webserver -p 2222 > $AIRFLOW_HOME/startup_log/airflow-server.log 2>&1

# Starting airflow server.
# Steps are : initialising airflow database, starting redis server, starting airflow scheduler, starting airflow webserver
elif [ "$#" -eq 5 ] && [ "$1" = "cluster" ]  && [ "$2" = "server" ]; then
	# setting up the arguments.
	MYSQL_CONNECTION=$3
	GCP_SERVICE_ACCOUNT_USER=$4
	GCP_PROJECT_NAME=$5

    #google client platform authentication
    echo "setting up google cloud platform ..."
    gcloud auth activate-service-account ${GCP_SERVICE_ACCOUNT_USER} --key-file=/usr/local/airflow/.gcp/gcp-credentials.json --project=${GCP_PROJECT_NAME}
    # exporting google application credentials.
    export GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json
    echo "export GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json">>~/.bashrc
    echo "GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json">>~/.profile

	echo "setting 'Celery' as scheduler type..."
    echo "Setting AIRFLOW__CORE__EXECUTOR=CeleryExecutor"
    export AIRFLOW__CORE__EXECUTOR=CeleryExecutor
    echo "export AIRFLOW__CORE__EXECUTOR=CeleryExecutor">>~/.bashrc
    echo "AIRFLOW__CORE__EXECUTOR=CeleryExecutor">>~/.profile

    echo "setting 'web-authentication' of airflow webserver..."
    echo "Setting AIRFLOW__WEBSERVER__AUTHENTICATE=True"
    export AIRFLOW__WEBSERVER__AUTHENTICATE=True
    echo "export AIRFLOW__WEBSERVER__AUTHENTICATE=True">>~/.bashrc
    echo "AIRFLOW__WEBSERVER__AUTHENTICATE=True">>~/.profile

	# Configure airflow with mysql connection string.
	if [ -v MYSQL_CONNECTION ]; then
    	echo "setting mysql database connection string ..."
    	echo "Setting AIRFLOW__CORE__SQL_ALCHEMY_CONN=${MYSQL_CONNECTION}"
    	export AIRFLOW__CORE__SQL_ALCHEMY_CONN=$MYSQL_CONNECTION

    	echo "export AIRFLOW__CORE__SQL_ALCHEMY_CONN="$MYSQL_CONNECTION>>~/.bashrc
        echo "AIRFLOW__CORE__SQL_ALCHEMY_CONN="$MYSQL_CONNECTION>>~/.profile
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
elif [ "$#" -eq 6 ] && [ "$1" = "cluster" ]  && [ "$2" = "worker" ]; then
	# setting up the arguments.
	MYSQL_CONNECTION=$3
	REDIS_CONNECTION=$4
	GCP_SERVICE_ACCOUNT_USER=$5
	GCP_PROJECT_NAME=$6

    #google client platform authentication
    echo "setting up google cloud platform ..."
    gcloud auth activate-service-account ${GCP_SERVICE_ACCOUNT_USER} --key-file=/usr/local/airflow/.gcp/gcp-credentials.json --project=${GCP_PROJECT_NAME}
    # exporting google application credentials.
    export GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json
    echo "export GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json">>~/.bashrc
    echo "GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json">>~/.profile

    echo "setting 'Celery' as scheduler type..."
    echo "Setting AIRFLOW__CORE__EXECUTOR=CeleryExecutor"
    export AIRFLOW__CORE__EXECUTOR=CeleryExecutor
    echo "export AIRFLOW__CORE__EXECUTOR=CeleryExecutor">>~/.bashrc
    echo "AIRFLOW__CORE__EXECUTOR=CeleryExecutor">>~/.profile

    echo "setting 'web-authentication' of airflow webserver..."
    echo "Setting AIRFLOW__WEBSERVER__AUTHENTICATE=True"
    export AIRFLOW__WEBSERVER__AUTHENTICATE=True
    echo "export AIRFLOW__WEBSERVER__AUTHENTICATE=True">>~/.bashrc
    echo "AIRFLOW__WEBSERVER__AUTHENTICATE=True">>~/.profile

	# Configure airflow with mysql connection string.
	if [ -v MYSQL_CONNECTION ]; then
    	echo "setting mysql database connection string ..."
    	echo "Setting AIRFLOW__CORE__SQL_ALCHEMY_CONN=${MYSQL_CONNECTION}"
    	export AIRFLOW__CORE__SQL_ALCHEMY_CONN=$MYSQL_CONNECTION

    	echo "export AIRFLOW__CORE__SQL_ALCHEMY_CONN="$MYSQL_CONNECTION>>~/.bashrc
        echo "AIRFLOW__CORE__SQL_ALCHEMY_CONN="$MYSQL_CONNECTION>>~/.profile
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
  echo "== Please provide required arguments as per below information. =="
  echo "For starting airflow-container as standalone, arguments are:: 1): 'standalone' 2): GCP Service Account User 3): GCP Project Name"
  echo "For starting server arguments are::  1): 'cluster' 2): 'server' 3): mysql connection string e.g (mysql://airflow:airflow@localhost:3306/airflow) 4): GCP Service Account User 5): GCP Project Name"
  echo "For starting worker arguments are::  1): 'cluster' 2): 'worker' 3): mysql connection string e.g (mysql://airflow:airflow@localhost:3306/airflow) 4): redis connection string e.g (redis://localhost:6379/0) 5): GCP Service Account User 6): GCP Project Name"
fi