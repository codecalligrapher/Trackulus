#!/usr/bin/bash

create() {
  while getopts 'n:p:' param; do
    case "${param}" in 
      n) NAME=${OPTARG} ;;
      p) PERIODICITY=${OPTARG} ;;
    esac
  done;

  if [[ -z "${NAME}" ]]; then 
    echo "Habit creation failed, please specify habit name using -n";
    exit 1;
  fi;

  if [[ -z "${PERIODICITY}" ]]; then 
    PERIODICITY=0; # assume set to zero
  fi;

  echo "${NAME}" "${PERIODICITY}";
  if [[ ! -e ~/.config/Trackulus/.conf ]]; then
    mkdir -p ${HOME}/.config/Trackulus
    touch ${HOME}/.config/Trackulus/habits.conf 
  fi


  printf "name=${NAME}\nperiodicity=${PERIODICITY}\n\n" >> "${HOME}/.config/Trackulus/habits.conf"
}

"$@"