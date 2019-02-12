
--http://logic.edchen.org/a-script-to-delete-log-files-automatically-in-oracle/

-----------listener log

#!/bin/bash
. /home/grid/.bash_profile

# For deleting obsolete trace files
keep_time=10080                                          # 7 days
adump_dir=/u01/app/oracle/admin/${ORACLE_SID}/adump      # 7 days
listenerlog_dir=/u01/app/oracle/diag/????                # listener log 

for f in $( adrci exec="show homes" | grep listener | grep -v "ADR Homes:" );
do
  echo "Start Purging ${f} at $(date)"; >> ${log_file}
  adrci exec="set home ${f}; purge -age ${keep_time} ;" ;
done

# For deleting obsolete audit files
find ${adump_dir} -type f -mtime +7 -name '*.aud' -exec rm -f {} \;


------- diğer trace files

#!/bin/bash
. /home/oracle/.bash_profile

# For deleting obsolete trace files
log_file=/home/oracle/script/purge_trc.log
keep_time=10080                                          # 7 days
adump_dir=/u01/app/oracle/admin/${ORACLE_SID}/adump      # 7 days
alertlog_dir=/u01/app/oracle/diag/????                   # alert log last 50000 line

for f in $( adrci exec="show homes" | grep -v "ADR Homes:" );
do
  echo "Start Purging ${f} at $(date)"; >> ${log_file}
  adrci exec="set home ${f}; purge -age ${keep_time} ;" ;
done

# For deleting obsolete audit files
find ${adump_dir} -type f -mtime +7 -name '*.aud' -exec rm -f {} \;

# For trimming alert log
tail -50000 ${alertlog_dir}/alert_${ORACLE_SID}.log > ${alertlog_dir}/alert_${ORACLE_SID}.log.copy; 
cp -f ${alertlog_dir}/alert_${ORACLE_SID}.log.copy ${alertlog_dir}/alert_${ORACLE_SID}.log; 
cat /dev/null > ${alertlog_dir}/alert_${ORACLE_SID}.log.copy
