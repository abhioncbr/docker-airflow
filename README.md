[<img src="https://github.com/abhioncbr/docker-airflow/raw/master/airflow-logo.png" align="right">](https://airflow.apache.org/)
# docker-airflow [repo for building docker based airflow container]
This is a repository for building [Docker](https://www.docker.com/) container of [Apache Airflow](https://airflow.apache.org/) ([incubating](https://incubator.apache.org/)).

* For understanding & knowing more about Airflow, please follow [curated list of resources](https://raw.githubusercontent.com/jghoman/awesome-apache-airflow).
* Similarly, for Docker follow [curated list of resources](https://github.com/veggiemonk/awesome-docker).

## Airflow components stack
- Airflow version: 1.9.0
- Backend database: Mysql
- Scheduler: Celery
- Task queue: Redis
- Log location: local file system or AWS S3
- User authentication: Password based & support for multiple users with `superuser` privilege.
- Docker base image: debian
- Code enhancement: password based multiple users supporting super-user(can see all dags of all owner) feature. Currently, Airflow is working on the password based multi user feature.
- Other features: support for google cloud platform packages in container.
- Multiple `entrypoint.sh` for various supports like writing logs to s3 & initializing gcp in airflow container. 

## Airflow ports
- airflow portal port: 2222
- airflow celery flower: 5555
- redis port: 6379
- log files exchange port: 8793

## Airflow services information
- In server container: redis, airflow webserver & scheduler is running.
- In worker container: airflow worker & celery flower ui service is running.

## General information about airflow docker image
* There are two docker files in the folder `docker-files`.
* Base image(DockerFile-Base1.9.0) - file for building base image which consist of packages of airflow, java, redis and other basic components.
* Working image(DockerFile-1.9.0) - Depend on the base image. Build image with patches of airflow, creating user, installing gcp packages and setting up the working environment.
* Airflow scheduler needs a restart after sometime for properly scheduling of the task. Shell script for restarting scheduler is present in folder `config`
* Airflow container by default is configured for writing logs on AWS S3. AWS credentials needs to be updated in `credentials` file in folder `config`.

## How to build images
* for base image - There are two options
  * build image, if you want to do some customization - `docker build -t airflow-base1.9.0:latest --file=~/docker-airflow/DockerFile-Base1.9.0 . --rm`
  * download image - `docker pull abhioncbr/airflow-base1.9.0` and tag image as `airflow-base1.9.0`
* for working image -`docker build -t airflow-1.9.0:latest --file=~/docker-airflow/DockerFile1.9.0 . --rm`

## How to run
* General commands -
    * starting airflow image as a `airflow-server` service container -
    `docker run --net=host -p 2222:2222 -p 6379:6379 --name=airflow-server
    abhioncbr/airflow-1.9.0
    server mysql://user:password@host:3306/db-name &`

    * starting airflow image as a service container -
    `docker run --net=host -p 5555:5555 -p 8739:8739 --name=airflow-worker
    abhioncbr/airflow-1.9.0
    worker mysql://user:password@host:3306/db-name redis://<airflow-server-host>:6379/0 &`

* In Mac using [docker for mac](https://docs.docker.com/docker-for-mac/install/) -
    * starting airflow image as a service container & mounting dags, code-artifacts & logs folder to host machine -
    `docker run -p 2222:2222 -p 6379:6379 --name=airflow-server
     -v ~/airflow-data/code-artifacts:/code-artifacts 
     -v ~/airflow-data/logs:/usr/local/airflow/logs 
     -v ~/airflow-data/dags:/usr/local/airflow/dags 
     abhioncbr/airflow-1.9.0 
     server mysql://user:password@host.docker.internal:3306:3306/<airflow-db-name> &`  
     
    * starting airflow image as a service container & mounting dags, code-artifacts & logs folder to host machine - 
    `docker run -p 5555:5555 -p 8739:8739 --name=airflow-worker
     -v ~/airflow-data/code-artifacts:/code-artifacts 
     -v ~/airflow-data/logs:/usr/local/airflow/logs 
     -v ~/airflow-data/dags:/usr/local/airflow/dags 
     abhioncbr/airflow-1.9.0 
     worker mysql://user:password@host.docker.internal:3306:3306/<airflow-db-name> redis://host.docker.internal:6379/0 &` 
     
## Setting up Google Cloud Platform environment
* Update gcp-credentials.json file with Google credentials.
* In `entrypoint.sh` file uncomment commands related to setting up google cloud platform.