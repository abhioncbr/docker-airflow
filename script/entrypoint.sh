#!/usr/bin/env bash

AIRFLOW_HOME="/usr/local/airflow"
CMD="airflow"

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
parse_args(){
for I in "$@"
do
case ${I} in
    -m=*|--mode=*)
    MODE="${I#*=}"
    shift # past argument=value
    ;;
    -t=*|--node_type=*)
    NODE_TYPE="${I#*=}"
    shift # past argument=value
    ;;
    -d=*|--mysql_url=*)
    MYSQL_URL="${I#*=}"
    shift # past argument=value
    ;;
    -r=*|--redis_url=*)
    REDIS_URL="${I#*=}"
    shift # past argument=value
    ;;
    -a=*|--rbac_auth=*)
    RBAC_AUTH="${I#*=}"
    shift # past argument=value
    ;;
    -s=*|--s3_path=*)
    S3_PATH="${I#*=}"
    shift # past argument=value
    ;;
    -p=*|--gcp_project=*)
    GCP_PROJECT="${I#*=}"
    shift # past argument=value
    ;;
    -u=*|--gcp_service_user=*)
    GCP_USER_NAME="${I#*=}"
    shift # past argument=value
    ;;
    *)
    echo "Unknown option: '${I}'"
    help
    exit -1
    ;;
esac
done
}

help_note(){
  echo
  echo "###########################################################################################################################################################################"
  echo "##***************************************************** Please provide required arguments as per below information. *****************************************************##"
  echo "##                                                                                                                                                                       ##"
  echo "##************************************************************************* Required arguments- *************************************************************************##"
  echo "## 1) '-m' or '--mode', should be either 'standalone' or 'cluster' for eg, -m|--mode=standalone or -m|--mode=cluster                                                     ##"
  echo "## If mode is 'cluster' than 2)'-t' or '--node_type', should be either 'server' or 'worker' for eg, -t|--node_type=server or -t|--node_type=worker                       ##"
  echo "## If mode is 'cluster' than 3)'-d' or '--mysql_url' for eg, -d|--mysql_url=mysql://user:pswrd@db_host:port/db_name                                                      ##"
  echo "## If mode is 'cluster' & node_type is 'worker' than 4)'-r' or '--redis_url', should be server node host url, for eg, -r|--redis_url=redis://server_container_ip:6379/0  ##"
  echo "##                                                                                                                                                                       ##"
  echo "##************************************************************************* Optional arguments- *************************************************************************##"
  echo "## For S3 as dags log directory, '-s' or '--s3_path'. for eg, -s|--s3_path=s3://bucket-name/directory                                                                    ##"
  echo "## For RBAC based authorization, '-a' or '--rbac_auth'. Should be either 'true' or 'false. 'for eg, -a|--rbac_auth=true. Default username- 'airflow', pswrd- 'airflow'   ##"
  echo "## For Google Cloud platform, 1) '-p' or '--gcp_project', name of google project & 2) '-u' or '--gcp_service_user', google service account user                          ##"
  echo "###########################################################################################################################################################################"
  echo
}

print(){
  echo
  echo "###########################################################################################################################################################################"
  echo MODE = "${MODE}"
  print_node_type
  print_mysql_url
  print_redis_url
  echo RBAC_AUTH = "${RBAC_AUTH}"
  echo S3_PATH = "${S3_PATH}"
  echo GCP_PROJECT = "${GCP_PROJECT}"
  echo GCP_USER_NAME = "${GCP_USER_NAME}"
  echo "###########################################################################################################################################################################"
  echo
}

print_mysql_url(){
       if [[ -v MYSQL_URL ]] && [[ "$MODE" = "standalone" ]]; then
       temp="  [Ignoring, since 'mode' is 'standalone']"
       fi
       echo "MYSQL_URL = ${MYSQL_URL} $temp"
}

print_node_type(){
       if [[ -v NODE_TYPE ]] &&  [[ "$MODE" = "standalone" ]]; then
       temp="  [Ignoring, since 'mode' is 'standalone']"
       fi
       echo "NODE_TYPE = ${NODE_TYPE} $temp"
}

print_redis_url(){
       if [[ -v REDIS_URL ]] && [[ "$MODE" = "standalone" ]]; then
       temp="[Ignoring, since 'mode' is 'standalone']"
       elif [[ -v REDIS_URL ]] && [[ "$NODE_TYPE" = "server" ]]; then
       temp="[Ignoring, since 'node_type' is 'server']"
       fi
       echo "REDIS_URL = ${REDIS_URL}  $temp"
}

validate_args(){
    if [[ "$MODE" != "cluster" ]] && [[ "$MODE" != "standalone" ]]; then
        echo "Unknown Mode: '${MODE}'"
        help
        exit -1
    elif ([[ "$MODE" = "cluster" ]] && [[ "$NODE_TYPE" != "server" ]] && [[ "$NODE_TYPE" != "worker" ]]); then
        echo "Unknown node_type: '${NODE_TYPE}'"
        help
        exit -1
    elif ([[ "$MODE" = "cluster" ]] && [[ "$MYSQL_URL" != mysql://* ]]); then
        echo "Unknown mysql_url: '${MYSQL_URL}'"
        help
        exit -1
    elif ([[ "$MODE" = "cluster" ]] && [[ "$NODE_TYPE" = "worker" ]] && [[ "$REDIS_URL" != redis://* ]]); then
        echo "Unknown REDIS_URL: '${REDIS_URL}'"
        help
        exit -1
    elif [[ -v RBAC_AUTH ]] && [[ "$RBAC_AUTH" != "true" ]] && [[ "$RBAC_AUTH" != "false" ]]; then
        echo "Unknown RBAC_AUTH: '${RBAC_AUTH}'"
        help
        exit -1
    else
        print
    fi
}

set_airflow_s3_params(){
    echo "setting s3 log directory ..."
    echo "Setting AIRFLOW__CORE__S3_LOG_FOLDER=${S3_PATH}"
    export AIRFLOW__CORE__S3_LOG_FOLDER=${S3_PATH}
    echo "export AIRFLOW__CORE__S3_LOG_FOLDER="${S3_PATH}>>~/.bashrc
    echo "AIRFLOW__CORE__S3_LOG_FOLDER="${S3_PATH}>>~/.profile

    S3_LOGGING_CLASS='airflow.config_templates.s3_logger.LOGGING_CONFIG'
    AIRFLOW__CORE__LOGGING_CONFIG_CLASS=${S3_LOGGING_CLASS}
    export AIRFLOW__CORE__LOGGING_CONFIG_CLASS=${S3_LOGGING_CLASS}
    echo "export AIRFLOW__CORE__LOGGING_CONFIG_CLASS="${S3_LOGGING_CLASS}>>~/.bashrc
    echo "AIRFLOW__CORE__LOGGING_CONFIG_CLASS="${S3_LOGGING_CLASS}>>~/.profile

    S3_TASK='s3.task'
    AIRFLOW__CORE__TASK_LOG_READER=${S3_TASK}
    export AIRFLOW__CORE__S3_LOG_FOLDER=${S3_TASK}
    echo "export AIRFLOW__CORE__TASK_LOG_READER="${S3_TASK}>>~/.bashrc
    echo "AIRFLOW__CORE__TASK_LOG_READER="${S3_TASK}>>~/.profile
}

set_gcp_params(){
    #google client platform authentication
    echo "setting up google cloud platform ..."
    gcloud auth activate-service-account ${GCP_USER_NAME} --key-file=/usr/local/airflow/.gcp/gcp-credentials.json --project=${GCP_PROJECT}
    # exporting google application credentials.
    export GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json
    echo "export GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json">>~/.bashrc
    echo "GOOGLE_APPLICATION_CREDENTIALS=/usr/local/airflow/.gcp/gcp-credentials.json">>~/.profile
}

set_celery_executor(){
	echo "setting 'Celery' as scheduler type..."
    echo "Setting AIRFLOW__CORE__EXECUTOR=CeleryExecutor"
    export AIRFLOW__CORE__EXECUTOR=CeleryExecutor
    echo "export AIRFLOW__CORE__EXECUTOR=CeleryExecutor">>~/.bashrc
    echo "AIRFLOW__CORE__EXECUTOR=CeleryExecutor">>~/.profile
}

set_mysql(){
	# Configure airflow with mysql connection string.

    echo "setting mysql database connection string ..."
    echo "Setting AIRFLOW__CORE__SQL_ALCHEMY_CONN=${MYSQL_URL}"
    export AIRFLOW__CORE__SQL_ALCHEMY_CONN=${MYSQL_URL}

    echo "export AIRFLOW__CORE__SQL_ALCHEMY_CONN="${MYSQL_URL}>>~/.bashrc
    echo "AIRFLOW__CORE__SQL_ALCHEMY_CONN="${MYSQL_URL}>>~/.profile
}

set_celery_redis(){
	echo "Setting AIRFLOW__CELERY__BROKER_URL=${REDIS_URL}"
    export AIRFLOW__CELERY__BROKER_URL=${REDIS_URL}
    echo "Setting AIRFLOW__CELERY__CELERY_RESULT_BACKEND=${REDIS_URL}"
    export AIRFLOW__CELERY__CELERY_RESULT_BACKEND=${REDIS_URL}

    echo "export AIRFLOW__CELERY__BROKER_URL="${REDIS_URL}>>~/.bashrc
    echo "AIRFLOW__CELERY__BROKER_URL="${REDIS_URL}>>~/.profile
	echo "export AIRFLOW__CELERY__CELERY_RESULT_BACKEND="${REDIS_URL}>>~/.bashrc
    echo "AIRFLOW__CELERY__CELERY_RESULT_BACKEND="${REDIS_URL}>>~/.profile
}

#only support password based or rbac based
set_web_authentication(){
    if [[ "$RBAC_AUTH" = "true" ]]; then
        echo "setting 'rbac web-authentication' of airflow webserver..."
        echo "Setting AIRFLOW__WEBSERVER__RBAC=True"
        export AIRFLOW__WEBSERVER__RBAC=True
        echo "export AIRFLOW__WEBSERVER__RBAC=True">>~/.bashrc
        echo "AIRFLOW__WEBSERVER__RBAC=True">>~/.profile
    fi
    echo "setting 'web-authentication' of airflow webserver..."
    echo "Setting AIRFLOW__WEBSERVER__AUTHENTICATE=True"
    export AIRFLOW__WEBSERVER__AUTHENTICATE=True
    echo "export AIRFLOW__WEBSERVER__AUTHENTICATE=True">>~/.bashrc
    echo "AIRFLOW__WEBSERVER__AUTHENTICATE=True">>~/.profile
}

set_optional_param(){
    set_web_authentication
    if [[ -v S3_PATH ]]; then
      set_airflow_s3_params
    fi

    if [[ -v GCP_PROJECT ]] && [[ -v GCP_USER_NAME ]]; then
      set_gcp_params
    fi
}

#intialize airflow metadata db & create admin user
set_airflow_metadataDB(){
	# Initialising airflow database.
    echo "initialising airfow db"
	${CMD} initdb
	sleep 2
    echo "Done with airfow db"

    #executing python script for adding user in-case if user is not present
    echo "Running user_add python script in-case 'airflow' user is not present. Password is: 'airflow'"
    sleep 1
    python user_add.py

    if [[ "$RBAC_AUTH" = "true" ]]; then
        echo "Running rbac_user_add python script in-case 'airflow' rbac_user is not present. Password is: 'airflow'"
        sleep 1
        python rbac_user_add.py
    fi
}

parse_args "$@"
validate_args

# Starting airflow container in standalone mode.
# Steps are : initialising airflow database, starting airflow scheduler & airflow webserver.
if [[ "$MODE" = "standalone" ]]; then
    set_optional_param
    set_airflow_metadataDB

	# Starting airflow scheduler and writing scheduler log in file 'startup_log/airflow-scheduler.log'.
	echo starting airflow scheduler
	exec -a airflow-scheduler ${CMD} scheduler > ${AIRFLOW_HOME}/startup_log/airflow-scheduler.log 2>&1 &
	sleep 5
	case "$(pidof /usr/local/bin/python /usr/local/bin/airflow scheduler | wc -w)" in
		0)  echo "airflow scheduler is not started .. exiting."
    		exit 1
    		;;
		1)  echo "airflow scheduler is up & running, having pid:" $!
    		;;
	esac

	# Starting airflow web-server and writing log in to the file 'startup_log/airflow-server.log'.
	echo "starting airflow web-server"
	exec -a airflow-webserver ${CMD} webserver -p 2222 > ${AIRFLOW_HOME}/startup_log/airflow-server.log 2>&1

# Starting airflow server.
# Steps are : initialising airflow database, starting redis server, starting airflow scheduler, starting airflow webserver
elif [[ "$MODE" = "cluster" ]] && [[ "$NODE_TYPE" = "server" ]]; then
   set_mysql
   set_celery_executor
   set_optional_param
   set_airflow_metadataDB

    # ============= Starting server processes =====================

	# Starting redis first as redis connection string is required for airflow.
	echo starting redis
	exec -a redis-server redis-server --protected-mode no > ${AIRFLOW_HOME}/startup_log/redis-server.log 2>&1 &
	sleep 5
	case "$(pidof redis-server | wc -w)" in
		0)  echo "redis is not started .. exiting."
    		exit 1
    		;;
		1)  echo "redis-server is up & running, having pid:" $!
    		;;
	esac

	REDIS_URL=redis://localhost:6379/0
	set_celery_redis

	# Starting airflow scheduler and writing scheduler log in file 'startup_log/airflow-scheduler.log'.
	echo starting airflow scheduler
	exec -a airflow-scheduler ${CMD} scheduler > ${AIRFLOW_HOME}/startup_log/airflow-scheduler.log 2>&1 &
	sleep 5
	case "$(pidof /usr/local/bin/python/usr/local/bin/airflow scheduler | wc -w)" in
		0)  echo "airflow scheduler is not started .. exiting."
    		exit 1
    		;;
		1)  echo "airflow scheduler is up & running, having pid:" $!
    		;;
	esac

	#running shell script to restart airflow scheduler in every 5 minutes.
	echo "Running shell script to restart airflow scheduler in every 5 minutes."
	sh ./execute_continous_scheduler.sh ${MYSQL_URL} ${REDIS_URL} &

	# Starting airflow web-server and writing log in to the file 'startup_log/airflow-server.log'.
	echo "starting airflow web-server"
	exec -a airflow-webserver ${CMD} webserver > ${AIRFLOW_HOME}/startup_log/airflow-server.log 2>&1

# Starting airflow worker.
elif [[ "$MODE" = "cluster" ]] && [[ "$NODE_TYPE" = "worker" ]]; then
   set_mysql
   set_celery_executor
   set_celery_redis
   set_optional_param

	# Starting worker processes.
	echo "starting airflow celery flower"
    exec ${CMD} flower > ${AIRFLOW_HOME}/startup_log/airflow-celery-flower.log 2>&1 &
    sleep 5
    case "$(pidof /usr/local/bin/python/usr/local/bin/flower | wc -w)" in
		0)  echo "airflow flower is not started .. exiting."
    		exit 1
    		;;
		1)  echo "airflow flower is up & running, having pid:" $!
    		;;
	esac

	echo "starting airflow worker"
	QUEUE="default,$(hostname)"
	exec ${CMD} worker -q ${QUEUE} > ${AIRFLOW_HOME}/startup_log/airflow-worker.log 2>&1

# arguments is not in order
else
help_note
fi