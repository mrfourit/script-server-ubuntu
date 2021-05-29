#!/bin/bash

log_file() {
  status="INFO"

  if [ "${3}" != "" ]
    then
      status="${3}"
  fi

  folder_log="${1}"

  sudo mkdir -p "${folder_log}"

  date_log="$(date +'%d-%m-%Y %T')"

  content_log="${2}"

  echo "[${date_log}]  [${status}]  ${content_log}" >> "${folder_log}/log.txt"
}

script_run() {
    LOG_FOLDER="/var/log/script_restart_auto"

    if [[ "$(/usr/sbin/service mysql status)" == *"inactive (dead)"* ]]
        then
            /usr/sbin/service mysql start
            log_file "${LOG_FOLDER}" "Mysql die" "ERROR"
    fi
    if [[ "$(/usr/sbin/service apache2 status)" == *"inactive (dead)"* ]]
        then
            /usr/sbin/service apache2 start
            log_file "${LOG_FOLDER}" "Apache2 die" "ERROR"
    fi
}

script_run