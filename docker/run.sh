#!/usr/bin/env bash

usage () {
    cat << EOF | sed "s/^    //"
    Usage: $program [COMMAND] [PARAM]

    Commands:
      up                 Create and start web and db containers
      admin              Create and Start web, db, phpmyadmin services
      down               Stop and remove containers
      start              Start web and db services
      stop               Stop all services
      restart            Restart services
      ps                 List containers
      logs               View log of web service
      log                View log of web service
      clean              Stop and remove containers, networks, images, and volumes
      init               Start web and db services, then restoring data from dump file
      export             Dumping structure and contents of MySQL databases and tables
      dump               Dumping structure and contents of MySQL databases and tables
      import file        Restoring data from dump file
      restore file       Restoring data from dump file
EOF
}

wait_mysql_ready () {
  docker-compose exec -T db sh -c 'while ! mysqladmin --silent ping status -h"localhost" -uroot -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null ; do sleep 2; echo "Waiting for DB to come up ..."; done'
}

handleError() {
  if [ "$1" != "0" ]; then
    echo Failed.
    exit 1
  fi
}

cd $(dirname $0)

docker_compose_1="docker-compose -f docker-compose.yml"
docker_compose_2="docker-compose -f docker-compose.yml -f docker-compose.admin.yml"
program=$(basename $0)
command=$1

# Create the nginx-proxy-compose_default network to prevent error.
docker network create nginx-proxy-compose_default 2>/dev/null || echo >/dev/null

if [ -z "${command}" ] || [ "${command}" == "up" ]; then
  if [ -f .env ]; then
    source .env
  fi
  ${docker_compose_1} up -d --scale web=${NUM_WEB_SERVICE:-2}
elif [ "${command}" == "admin" ]; then
  if [ -f .env ]; then
    source .env
  fi
  ${docker_compose_2} up -d --scale web=${NUM_WEB_SERVICE:-2}
elif [ "${command}" == "ps" ]; then
  ${docker_compose_2} ps -a
  exit 0
elif [ "${command}" == "start" ]; then
  if [ -n "$(${docker_compose_2} ps | grep phpmyadmin)" ]; then
    ${docker_compose_2} start
  else
    ${docker_compose_1} start
  fi
elif [ "${command}" == "restart" ] || [ "${command}" == "stop" ]; then
  ${docker_compose_2} ${command}
elif [ "${command}" == "down" ]; then
  ${docker_compose_2} down --remove-orphans
elif [ "${command}" == "clean" ]; then
  ${docker_compose_2} down --remove-orphans --volumes
elif [ "${command}" == "init" ]; then
  echo "This action will clear the data in the database. Do you really want to do it?"
  read -p "Press enter to continue" something

  # About `-u10` see
  # https://unix.stackexchange.com/questions/107800/using-while-loop-to-ssh-to-multiple-servers/107801#107801
  while read -u10 data; do
    if [ -n "${data}" ]; then
      DATA_FILE_PATH=$(realpath $(pwd)/../../dbdumps/${data})
      if [ -z ${DATA_FILE_PATH} ] || [ ! -f ${DATA_FILE_PATH} ]; then
        echo Skip a file. No such file: \'../../dbdumps/${data}\'
      else
        ./$program import ${data}
        handleError $?
      fi
    fi
  # Delete CR characters and delete lines starts with #
  done 10< <(sed 's/\r$//' db-init-file-list.txt | grep '^[^#]')

  handleError $?

  rm -rf ../../src/file/cache/
  handleError $?

  ./$program up
  exit 0
# elif [ "${command}" == "restart" ]; then
#   ${docker_compose_2} down && \
#   ${docker_compose_1} up -d
elif [ "${command}" == "log" ] || [ "${command}" == "logs" ]; then
  docker-compose logs -f --tail 20 web
elif [ "${command}" == "export" ] || [ "${command}" == "dump" ]; then
  if [ -f .env ]; then
    source .env
  fi
  ENV=${ENV:-development}
  NEW_VERSION=`date '+%Y%m%d%H%M'`
  DUMP_CMD="docker-compose exec -T db sh -c 'exec mysqldump \$MYSQL_DATABASE -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \
    --complete-insert --order-by-primary \
    --ignore-table=\$MYSQL_DATABASE.xxx_tablename \
    2>/dev/null'"

  docker-compose start db || docker-compose up -d db && \
    wait_mysql_ready && \
    sh -c "${DUMP_CMD}" | sed 's$VALUES ($VALUES\n($g' | sed 's$),($),\n($g' | gzip -9 > ../../dbdumps/${ENV}_${NEW_VERSION}.sql.gz && echo Done!

  echo Dumping data to file: $(realpath $(pwd)/../../dbdumps/${ENV}_${NEW_VERSION}.sql.gz)
  # sh -c "${DUMP_CMD}" > ../../dbdumps/${ENV}_${NEW_VERSION}.sql && echo Done!
  # docker-compose exec db sh -c 'exec mysqldump $MYSQL_DATABASE -uroot -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null' > ../../dbdumps/${ENV}_${NEW_VERSION}.sql && echo Done!
  # docker-compose exec db sh -c 'exec mysqldump $MYSQL_DATABASE -uroot -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null' | gzip -9 > ../../dbdumps/${ENV}_${NEW_VERSION}.sql.gz && echo Done!
elif [ "${command}" == "import" ] || [ "${command}" == "restore" ]; then
  LATEST_FILE=$(/bin/ls ../../dbdumps/ -t | grep -E "\.gz$" | head -1)
  if [ -n "$2" ]; then
    LATEST_FILE=$2
  else
    echo "Usage: $program import FILENAME"
    exit 1
  fi
  DATA_FILE_PATH=$(realpath $(pwd)/../../dbdumps/${LATEST_FILE})
  EXT="${LATEST_FILE##*.}"
  RESTORE_CMD="docker-compose exec -T db sh -c 'exec mysql \$MYSQL_DATABASE -uroot -p\"\$MYSQL_ROOT_PASSWORD\" 2>/dev/null'"

  if [ -z ${DATA_FILE_PATH} ] || [ ! -f ${DATA_FILE_PATH} ]; then
    echo No such file: \'../../dbdumps/${LATEST_FILE}\'
    exit 1
  fi
  echo Restoring data from dump file: ${DATA_FILE_PATH}
  echo "    check db status"

  docker-compose start db 2>/dev/null || docker-compose up -d db && wait_mysql_ready
  handleError $?
  echo "    db is ready"

  if [ "${EXT}" == "gz"  ]; then
    echo "    unzip file"
    gunzip < ${DATA_FILE_PATH} | sh -c "${RESTORE_CMD}"
  else
    sh -c "${RESTORE_CMD}" < ${DATA_FILE_PATH}
  fi
  handleError $?

  rm -rf ../../src/file/cache/
  handleError $?

  echo Done!
  # docker-compose exec -T db sh -c 'exec mysql $MYSQL_DATABASE -uroot -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null' < ./maitao.sql
  # gunzip < maitao.sql.gz | docker-compose exec -T db sh -c 'exec mysql $MYSQL_DATABASE -uroot -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null'
  exit 0
else
  usage
fi

# Alway show containers
echo
echo
${docker_compose_2} ps -a
