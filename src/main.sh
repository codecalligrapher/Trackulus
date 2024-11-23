#!/usr/bin/bash

init_database() {
  source ./db.env

  sqlcmd -S localhost -U $DB_USER -P $DB_PASSWORD -Q "IF NOT EXISTS(SELECT * FROM sys.databases WHERE name = 'habits') BEGIN CREATE DATABASE habits END" 
  sqlcmd -S localhost -U $DB_USER -P $DB_PASSWORD -Q """
    USE habits;
    IF NOT EXISTS(SELECT * FROM sysobjects WHERE name = 'directory') 
      BEGIN CREATE TABLE directory (
        habit_id INT NOT NULL IDENTITY PRIMARY KEY, 
        title VARCHAR(32) NOT NULL, 
        times INT,
        period INT);
      END;
      """

   sqlcmd -S localhost -U $DB_USER -P $DB_PASSWORD -Q """
    USE habits;
    IF NOT EXISTS(SELECT * FROM sysobjects WHERE name = 'habit_logs') 
      BEGIN CREATE TABLE habit_logs(
        log_id INT NOT NULL IDENTITY PRIMARY KEY,
        habit_id INT NOT NULL, 
        log_date DATE,
        CONSTRAINT FK_habits FOREIGN KEY (habit_id) REFERENCES directory(habit_id) ON UPDATE CASCADE
        )
      END;
        """
}

list() {
  source ./db.env
  sqlcmd -S localhost -U $DB_USER -P $DB_PASSWORD -Q """USE habits; SELECT * FROM directory"""
}

progress() {
  source ./db.env
  sqlcmd -S localhost -U $DB_USER -P $DB_PASSWORD -Q """
USE habits; 
with filtered_cte AS (
  SELECT 
    d.habit_id habit_id,
    d.title title,
    d.times times,
    d.period period,
    l.log_date log_date
  FROM 
    directory d LEFT JOIN habit_logs l 
    ON d.habit_id = l.habit_id
  WHERE 
    log_date >= dateadd(day, -(d.period + 1), GETDATE()))
  SELECT 
  habit_id Habit_ID,
  title Habit_Title,
  times Number_of_Times_Expected,
  period Period_Expected,
  count(*) as Number_of_Times_Actual,
  from filtered_cte group by habit_id, title, times, period;

"""


}

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
  while getopts 'i:c:' param; do
    case "${param}" in
      i) HABITID=${OPTARG} ;;
      c) COMMENT=${OPTARG}
    esac
  done;
  source ./db.env
  sqlcmd -S localhost -U $DB_USER -P $DB_PASSWORD -Q """
USE habits; 
INSERT INTO habit_logs (habit_id, log_date)
VALUES ($HABITID, GETDATE())
"""
  sqlcmd -S localhost -U $DB_USER -P $DB_PASSWORD -Q """
USE habits;
SELECT top 10 * from habit_logs WHERE habit_id = $HABITID ORDER BY log_date DESC;
  """
}

"$@"
