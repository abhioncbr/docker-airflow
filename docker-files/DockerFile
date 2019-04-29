# VERSION 1.0 (apache-docker)
# AUTHOR: Abhishek Sharma<abhioncbr@yahoo.com>
# DESCRIPTION: docker apache airflow container

FROM python:3.6
MAINTAINER Abhishek Sharma <abhioncbr@yahoo.com>

ARG PYTHON_DEPS="boto3 "
ARG AIRFLOW_VERSION
ARG AIRFLOW_PATCH_VERSION
ARG AIRFLOW_DEPS="all,password"
ARG BUILD_DEPS="freetds-dev libkrb5-dev libsasl2-dev libssl-dev libffi-dev libpq-dev git"
ARG OTHER_DEPS="sshpass openssh-server openssh-client less gcc make wget vim curl rsync netcat logrotate"
ARG APT_DEPS="$BUILD_DEPS $OTHER_DEPS libsasl2-dev freetds-bin build-essential default-libmysqlclient-dev apt-utils locales "

ENV AIRFLOW_HOME /usr/local/airflow
ENV AIRFLOW_GPL_UNIDECODE yes

#install dependencies packages.
RUN set -x \
    && apt-get update \
    && if [ -n "${APT_DEPS}" ]; then apt-get install -y $APT_DEPS; fi

#Install Redis
RUN apt-get update && apt policy redis-server && apt-get install -y redis-server

#Install java for java based application.
RUN apt-get update && apt policy openjdk-8-jdk && apt-get install -y openjdk-8-jdk

#for older versions[1.8.1, 1.8.2] of airflow, pip downgrading is required.
RUN if [ ${AIRFLOW_VERSION} \< "1.8.3" ]; then pip install pip==9.0; \
else python -m pip install --upgrade pip setuptools wheel; fi

#Install python dependencies.
RUN if [ -n "${PYTHON_DEPS}" ]; then pip install --no-cache-dir ${PYTHON_DEPS}; fi

#Install Airflow all packages
RUN pip install apache-airflow[$AIRFLOW_DEPS]==$AIRFLOW_VERSION && apt-get clean

#Install GCloud[GCP] packages.
RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz
RUN mkdir -p /usr/local/gcloud
RUN tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz
RUN /usr/local/gcloud/google-cloud-sdk/install.sh
RUN pip install --upgrade google-api-python-client && pip install google-cloud-storage

#Install aws cli.
RUN pip3 install awscli --upgrade --user

#Adding 'airflow' as group & user.
RUN groupadd -g 5555 airflow \
    && useradd -ms /bin/bash -d ${AIRFLOW_HOME}  -u 5555 -g 5555 -p airflow airflow \
    && echo "airflow:airflow" | chpasswd && adduser airflow sudo

#Creating folder.
RUN mkdir /code-artifacts /data /home/airflow ${AIRFLOW_HOME}/startup_log ${AIRFLOW_HOME}/.ssh ${AIRFLOW_HOME}/.aws ${AIRFLOW_HOME}/.gcp ${AIRFLOW_HOME}/dags ${AIRFLOW_HOME}/logs ${AIRFLOW_HOME}/plugins \
    && mkdir -p /user/airflow \
    && chown -R airflow:airflow ${AIRFLOW_HOME}/* /data /code-artifacts /user/airflow /home/airflow

ADD airflow-config/airflow-${AIRFLOW_VERSION}.cfg ${AIRFLOW_HOME}/airflow.cfg
ADD config/user_add.py ${AIRFLOW_HOME}/user_add.py
ADD config/rbac_user_add.py ${AIRFLOW_HOME}/rbac_user_add.py
ADD config/execute_continous_scheduler.sh ${AIRFLOW_HOME}/execute_continous_scheduler.sh

# airflow patch files present in airflowPatch folder
RUN mkdir /tmp/airflow_patch
ADD airflowPatch1.8/* /tmp/airflow_patch/airflowPatch1.8/
ADD airflowPatch1.9/* /tmp/airflow_patch/airflowPatch1.9/
ADD airflowPatch1.10/* /tmp/airflow_patch/airflowPatch1.10/
RUN if [ ! -z "$AIRFLOW_PATCH_VERSION" ] ; then \
    cp /tmp/airflow_patch/airflowPatch${AIRFLOW_PATCH_VERSION}/models.py /usr/local/lib/python3.6/site-packages/airflow/models.py; \
    cp /tmp/airflow_patch/airflowPatch${AIRFLOW_PATCH_VERSION}/views.py /usr/local/lib/python3.6/site-packages/airflow/www/views.py; \
    cp /tmp/airflow_patch/airflowPatch${AIRFLOW_PATCH_VERSION}/password_auth.py /usr/local/lib/python3.6/site-packages/airflow/contrib/auth/backends/password_auth.py; \
    cp /tmp/airflow_patch/airflowPatch${AIRFLOW_PATCH_VERSION}/e3a246e0dc1_current_schema.py /usr/local/lib/python3.6/site-packages/airflow/migrations/versions/e3a246e0dc1_current_schema.py; \
    chown root:staff /usr/local/lib/python3.6/site-packages/airflow/models.py; \
    chown root:staff /usr/local/lib/python3.6/site-packages/airflow/www/views.py; \
    chown root:staff /usr/local/lib/python3.6/site-packages/airflow/contrib/auth/backends/password_auth.py; \
    chown root:staff /usr/local/lib/python3.6/site-packages/airflow/migrations/versions/e3a246e0dc1_current_schema.py; \
fi
RUN rm -rf /tmp/airflow_patch

#Adding S3 logger.
ADD airflowExtraFeatures/s3_logger.py /usr/local/lib/python3.6/site-packages/airflow/config_templates/s3_logger.py
RUN chown root:staff /usr/local/lib/python3.6/site-packages/airflow/config_templates/s3_logger.py

RUN chown -R airflow:airflow ${AIRFLOW_HOME}/*
VOLUME /usr/hdp
VOLUME /code-artifacts
VOLUME ${AIRFLOW_HOME}/.gcp
VOLUME ${AIRFLOW_HOME}/.aws
VOLUME ${AIRFLOW_HOME}/dags
VOLUME ${AIRFLOW_HOME}/logs

ENV PATH=$PATH::/usr/local/gcloud/google-cloud-sdk/bin/
ENV PYTHONPATH=${PYTHONPATH}:/usr/local/lib/python3.6/

#for airflow processes log rotation.
ADD logrotate/airflow /etc/logrotate.d/airflow
ADD logrotate/run_log_rotate.sh ${AIRFLOW_HOME}/run_log_rotate.sh

#setting up logrotation cron.
RUN echo "30 * * * * /bin/sh ${AIRFLOW_HOME}/run_log_rotate.sh >> ${AIRFLOW_HOME}/logRotate_logs.txt" >> ${AIRFLOW_HOME}/airflow_cron
RUN crontab ${AIRFLOW_HOME}/airflow_cron
RUN rm ${AIRFLOW_HOME}/airflow_cron

#ENV HDP_VERSION=2.6.1.0-129
#export HDP_VERSION=${HDP_VERSION}
#export HADOOP_CONF_DIR=/etc/hadoop/${HDP_VERSION}/0
#export SPARK_CONF_DIR=/etc/spark/${HDP_VERSION}/0
#export HIVE_CONF_DIR=/etc/hive/${HDP_VERSION}/0
#export TEZ_CONF_DIR=/etc/tez/${HDP_VERSION}/0

EXPOSE 5555 8793 2222 6379

COPY script/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN ln -s /usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

WORKDIR ${AIRFLOW_HOME}
USER airflow

#setting default mode of docker-airflow as 'standalone'. Will be helpful when from Kitematic.
ENV MODE standalone

HEALTHCHECK CMD ["curl", "-f", "http://localhost:2222/health"]
ENTRYPOINT ["docker-entrypoint.sh"]
