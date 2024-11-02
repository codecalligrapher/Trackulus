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
    PERIODICITY=0; # assume set to zero (daily)
    # TODO: start supporting weekly/monthly periodicities
  fi;

  echo "${NAME}" "${PERIODICITY}";
  if [[ ! -e ~/.config/Trackulus/.conf ]]; then
    echo "Configuration not found, creating in ${HOME}/.config/Trackulus"
    mkdir -p ${HOME}/.config/Trackulus
    mkdir -p ${HOME}/.config/Trackulus/habits
    touch ${HOME}/.config/Trackulus/habits.conf 
  fi

  touch ${HOME}/.config/Trackulus/habits/${NAME}.txt
  printf "! name=${NAME}\nperiodicity=${PERIODICITY}\n\n" >> "${HOME}/.config/Trackulus/habits/${NAME}.txt"
}



log() {
  while getopts 'n:a:c:' param; do 
    case "${param}" in 
      n) NAME=${OPTARG} ;;
      a) AMOUNT=${OPTARG} ;;
      c) COMMENT=${OPTARG}
    esac
  done;
  printf "$NAME\n"
  printf "$(date +%F) : $AMOUNT : ${COMMENT:\t}\n"
}

"$@"