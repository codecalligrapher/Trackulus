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

longest_current_streak() {
  source ./db.env
  sqlcmd  -S localhost -U $DB_USER -P $DB_PASSWORD -m 1 -Q """
  USE habits;
  WITH DateSequence AS (
    -- Group consecutive dates and assign a sequence number
    SELECT 
        habit_id,
        log_date,
        DATEDIFF(DAY, 
            LAG(log_date, 1) OVER (PARTITION BY habit_id ORDER BY log_date), 
            log_date
        ) AS days_diff
    FROM (
        SELECT DISTINCT habit_id, log_date 
        FROM habit_logs 
    ) AS UniqueHabitDates
),
StreakGroups AS (
    -- Identify continuous streaks
    SELECT 
        habit_id,
        log_date,
        days_diff,
        SUM(CASE WHEN days_diff > 1 OR days_diff IS NULL THEN 1 ELSE 0 END) 
            OVER (PARTITION BY habit_id ORDER BY log_date) AS streak_group
    FROM DateSequence
),
Streaks AS (
    -- Calculate streak lengths
    SELECT 
        habit_id,
        streak_group,
        COUNT(*) AS current_streak,
        MAX(log_date) AS last_date
    FROM StreakGroups
    GROUP BY habit_id, streak_group
),
LongestCurrentStreak AS (
    -- Find the longest current streak for each habit
    SELECT 
        s.habit_id,
        d.title,
        MAX(current_streak) AS longest_current_streak
    FROM Streaks s
    left join directory d ON d.habit_id = s.habit_id
    WHERE s.last_date = (
        SELECT MAX(log_date) 
        FROM habit_logs ht 
        WHERE ht.habit_id = s.habit_id
    )
    GROUP BY s.habit_id, d.title
)
SELECT 
    habit_id, 
    longest_current_streak,
    title
FROM LongestCurrentStreak;
  """
}

progress() {
  source ./db.env
  sqlcmd -m 1 -S localhost -U $DB_USER -P $DB_PASSWORD -Q """
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
  count(*) as Number_of_Times_Actual
  from filtered_cte group by habit_id, title, times, period;
"""
longest_current_streak


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

  source ./db.env
  local HABITNAME=$(sqlcmd -S localhost -U $DB_USER -P $DB_PASSWORD -Q """SET NoCount ON; DECLARE @result varchar(max); USE habits; SELECT @result=title FROM directory WHERE habit_id= $HABITID; PRINT @result;""")

  log_to_notion $HABITID "${HABITNAME:38}";
}

log_to_notion() {
  local habitid=$1;
  local habitname=$2;

  echo $habitname;

  curl -X POST 'https://api.notion.com/v1/pages' \
  -H 'Authorization: Bearer '"$NOTION_API_KEY"'' \
  -H 'Notion-Version: 2022-06-28' \
  -H "Content-Type: application/json" \
  --data '{
    "parent": {
        "type": "database_id",
        "database_id": "1470dc796a3980cf991cda608caecb13"
    },
    "properties": {
        "HabitID": {
            "type": "title",
            "title": [
                {
                    "type": "text",
                    "text": {
                        "content": "'$habitid'"
                    }
                }
            ]
        },        
        "Habit Name": {
            "type": "rich_text",
            "rich_text": [
                {
                    "type": "text",
                    "text": {
                        "content": "'"$habitname"'"
                    }
                }
            ]
        }

    }
 }'
}

"$@"
