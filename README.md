[<img src="https://github.com/abhioncbr/docker-airflow/raw/master/airflow-logo.png" align="right">](https://airflow.apache.org/)
# docker-airflow
[![CircleCI](https://circleci.com/gh/abhioncbr/docker-airflow/tree/master.svg?style=svg)](https://circleci.com/gh/abhioncbr/docker-airflow/tree/master)
[![License](http://img.shields.io/:license-Apache%202-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.txt)
[![Code Climate](https://codeclimate.com/github/codeclimate/codeclimate/badges/gpa.svg)](https://codeclimate.com/github/abhioncbr/docker-airflow)

This is a repository for building [Docker](https://www.docker.com/) container of [Apache Airflow](https://airflow.apache.org/) ([incubating](https://incubator.apache.org/)).

* For understanding & knowing more about Airflow, please follow [curated list of resources](https://github.com/jghoman/awesome-apache-airflow).
* Similarly, for Docker follow [curated list of resources](https://github.com/veggiemonk/awesome-docker).

## Images

|Image|Pulls|Tags|
|:---|:---:|:---:|
|abhioncbr/docker-airflow|[![Docker Pulls](https://img.shields.io/docker/pulls/abhioncbr/docker-airflow.svg)](https://cloud.docker.com/u/abhioncbr/repository/docker/abhioncbr/docker-airflow)|[tags](https://cloud.docker.com/repository/docker/abhioncbr/docker-airflow/tags)|

## Airflow components stack
- Airflow version: Notation for representing version `XX.YY.ZZ`
- Execution Mode: `standalone`(simple container for exploration purpose, based on sqlite as airflow metadata db & SequentialExecutor ) or `prod`(single node based, LocalExecutor amd mysql as airflow metadata db) and `cluster` (for distributed production long run use-cases, container runs as either `server` or `worker` )
- Backend database: standalone- Sqlite, prod & cluster- Mysql
- Scheduler: standalone- Sequential, prod- LocalExecutor and Cluster- Celery
- Task queue: cluster- Redis
- Log location: local file system (Default) or AWS S3 (through `entrypoint-s3.sh`)
- User authentication: Password based & support for multiple users with `superuser` privilege.
- Code enhancement: password based multiple users supporting super-user(can see all dags of all owner) feature. Currently, Airflow is working on the password based multi user feature.
- Other features: support for google cloud platform packages in container.

## Airflow ports
- airflow portal port: 2222
- airflow celery flower: 5555
- redis port: 6379
- log files exchange port: 8793

## Airflow services information
- In server container: redis, airflow webserver & scheduler is running.
- In worker container: airflow worker & celery flower ui service is running.

## How to build images
* [DockerFile](docker-files/Dockerfile) uses `airflow-version` as a `build-arg`.
* build image, if you want to do some customization - 
    ```shell 
       docker build -t abhioncbr/docker-airflow:$IMAGE_VERSION --build-arg AIRFLOW_VERSION=$AIRFLOW_VERSION
                  --build-arg AIRFLOW_PATCH_VERSION=$AIRFLOW_PATCH_VERSION -f ~/docker-airflow/docker-files/DockerFile .
    ```
    * Arg IMAGE_VERSION value should be airflow version for example, 1.10.3 or 1.10.2
    * Arg AIRFLOW_PATCH_VERSION value should be the major release version of airflow for example for 1.10.2 it should be 1.10.

## How to run using Kitmatic
* Simplest way for exploration purpose, using [Kitematic](https://kitematic.com)(Run containers through a simple, yet powerful graphical user interface.) 
    * Search abhioncbr/docker-airflow Image on [docker-hub](https://hub.docker.com/r/abhioncbr/docker-airflow/) 
        [<img src="search-docker-airflow-Kitematic.png" alt="search-docker-airflow-Kitematic">](search-docker-airflow-Kitematic.png)
    
    * Start a container through Kitematic UI.
        [<img src="run-docker-airflow-Kitematic.png" alt="run-docker-airflow-Kitematic">](run-docker-airflow-Kitematic.png)

## How to run
* General commands -
    * starting airflow image as a `airflow-standalone` container in a standalone mode-
        ```shell
        docker run --net=host -p 2222:2222 --name=airflow-standalone abhioncbr/airflow-XX.YY.ZZ -m=standalone &
        ```
    
    * Starting airflow image as a `airflow-server` container in a cluster mode-
        ```shell
        docker run --net=host -p 2222:2222 -p 6379:6379 --name=airflow-server \
        abhioncbr/airflow-XX.YY.ZZ -m=cluster -t=server -d=mysql://user:password@host:3306/db-name &
        ```

    * Starting airflow image as a `airflow-worker` container in a cluster mode-
        ```shell
        docker run --net=host -p 5555:5555 -p 8739:8739 --name=airflow-worker \
        abhioncbr/airflow-XX.YY.ZZ -m=cluster -t=worker -d=mysql://user:password@host:3306/db-name -r=redis://<airflow-server-host>:6379/0 &
        ```

* In Mac using [docker for mac](https://docs.docker.com/docker-for-mac/install/) -
    * Standalone Mode - starting airflow image in a standalone mode & mounting dags, code-artifacts & logs folder to host machine -
        ```shell
        docker run -p 2222:2222 --name=airflow-standalone \
        -v ~/airflow-data/code-artifacts:/code-artifacts \
        -v ~/airflow-data/logs:/usr/local/airflow/logs \
        -v ~/airflow-data/dags:/usr/local/airflow/dags \
        abhioncbr/airflow-XX.YY.ZZ -m=standalone &
        ```     
    
    * Cluster Mode
        * starting airflow image as a server container & mounting dags, code-artifacts & logs folder to host machine -
            ```shell
            docker run -p 2222:2222 -p 6379:6379 --name=airflow-server \
            -v ~/airflow-data/code-artifacts:/code-artifacts \
            -v ~/airflow-data/logs:/usr/local/airflow/logs \
            -v ~/airflow-data/dags:/usr/local/airflow/dags \
            abhioncbr/airflow-XX.YY.ZZ \
            -m=cluster -t=server -d=mysql://user:password@host.docker.internal:3306:3306/<airflow-db-name> &
            ```
     
        * starting airflow image as a worker container & mounting dags, code-artifacts & logs folder to host machine - 
            ```shell
            docker run -p 5555:5555 -p 8739:8739 --name=airflow-worker \
            -v ~/airflow-data/code-artifacts:/code-artifacts \
            -v ~/airflow-data/logs:/usr/local/airflow/logs \
            -v ~/airflow-data/dags:/usr/local/airflow/dags \
            abhioncbr/airflow-XX.YY.ZZ \
            -m=cluster -t=worker -d=mysql://user:password@host.docker.internal:3306:3306/<airflow-db-name> -r=redis://host.docker.internal:6379/0 &   
            ``` 
<<<<<<< HEAD
    [<img src="docker-airflow-entrypoint-args.png" alt="Airflow">](docker-airflow-entrypoint-args.png)      
    
## Distributed execution of airflow
* As mentioned above, docker image of airflow can be leveraged to run in complete distributed run
    * single docker-airflow container in `server` mode for serving the UI of the airflow, redis for celery task & scheduler.
    * multiple docker-airflow containers in `worker` mode for executing tasks using celery executor.
    * centralised airflow metadata database.
* Image below depicts the docker-airflow distributed platform:
    [<img src="airflow-aws-deployment.png" alt="Distributed-Airflow">](airflow-aws-deployment.png)   
             
=======
    
>>>>>>> 925808aefcc6012e9d16a2f0eb23014bbe5de263
