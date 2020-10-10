#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ${SCRIPT_NAME} 
#%
#% DESCRIPTION
#%    Bu script AD tarafta disable olan kullanicilari  
#%    gunluk olarak ldapsearch bulup EBS tarafında da disable 
#%    etmek icin hazirlanmistir.
#% OPTIONS
#%    NA
#%
#% EXAMPLES
#%    ${SCRIPT_NAME} 
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} (https://www.dekamedia.com/) 1.0.4
#-    author          dekamedia
#-    copyright       Copyright (c) https://www.dekamedia.com/
#-    license         GNU General Public License
#-    script_id       6501
#-
#================================================================
#  HISTORY
#     2015/12/01 : dekamedia : Script olusturuldu
#     2019/12/12 : dekamedia : test asamasi
#     2019/12/20 : dekamedia : prod asamasi
#================================================================
#  DEBUG OPTION
#    set -n  # Uncomment to check your syntax, without execution.
#    set -x  # Uncomment to debug this shell script
#
#================================================================
# END_OF_HEADER
#================================================================
. $HOME/oid.env
l_scr_home=/u01/scripts
l_diabled_acc_file=${l_scr_home}/ad_dis_acc.ldif
l_log_file=${l_scr_home}/ad_dis_acc.log
l_log_dis_file=${l_scr_home}/ad_dis_acc_diag.log
ldap_host="IP of AD"
ldap_port=389
ldap_user="CN=OIMUser,CN=Users,DC=company,DC=local"
ldap_pass="sifre"
ldap_ou="OU=company,DC=company,DC=local"
l_whenChanged=$(date +"%Y%m%d%H%M%S" -d "1 days ago")".0Z"
ldap_filter="(&(&(objectclass=user)(&(&(userPrincipalName=AVS*)(whenChanged>=${l_whenChanged})))(UserAccountControl=514))(!(objectclass=computer)))"   #find disabled acccount
##ldap_filter="(&(&(objectclass=user)(&(&(userPrincipalName=AVS*)(whenCreated>=${l_whenChanged})))(UserAccountControl=512))((objectCategory=person)))" #find created account
##ldapsearch -h dc.example.com -p 389 -D "EXAMPLE\admin" -x -w "password" -b "DC=example,DC=com" -s sub "(&(objectCategory=person)(objectClass=user)(sAMAccountName=*)(memberOf=CN=Developers,OU=Role_Groups,OU=Groups,DC=example,DC=com))" mail \


#================================================================
# Find disabled users on AD daily
# based on timestamp whenChanged on AD
#================================================================

$ORACLE_HOME/bin/ldapsearch -h ${ldap_host} -p ${ldap_port} -D ${ldap_user} -b ${ldap_ou} ${ldap_filter} -w ${ldap_pass} | grep sAMAccountName | awk -F\= '{print $2}' > ${l_diabled_acc_file}

echo "==================" >> ${l_log_file}
echo ${l_whenChanged}     >> ${l_log_file}
cat ${l_diabled_acc_file} >> ${l_log_file}

#================================================================
# Check number of users
# 0   : Do nothing
# >20 : Do nothing raise error
# 0 < # of user < 20 then run
#================================================================

l_user_count=$(wc -l ${l_diabled_acc_file} | awk '{print $1}')

if [ ${l_user_count} == 0 ]
then
 echo "AD tarafında disable olmus yeni kullanici bulunamadi" >> ${l_log_dis_file}
 exit

elif [ ${l_user_count} -gt 20 ]
then
 echo "AD tarafında disable olmus yeni kullanici sayisi 20 den fazla: ${l_user_count}" >> ${l_log_dis_file}
 echo "Bu yuzden disable islemi yapilmadi" ${l_log_dis_file}
 exit

else
 echo "****************************************" >> ${l_log_dis_file}
 echo "disable olacak user sayisi: ${l_user_count}" >> ${l_log_dis_file}
fi

l_user_list=$(cat ${l_diabled_acc_file} | awk '{print}' ORS=',')
echo "Disable User List : "${l_user_list} >> ${l_log_dis_file}

#================================================================
# Disable user on EBS
#================================================================

$ORACLE_HOME/bin/sqlplus -s user/pass@TNS << EOF >> ${l_log_dis_file}
set serverout on
set verify off termout off feedback off echo off
var v_user_list varchar2(512);
exec :v_user_list :='${l_user_list}';
begin
 dbms_output.put_line(to_char(sysdate,'YYYY:MM:DD HH24:MI:SS')||' [INFO] Script Begins');
end;
/
DECLARE
  cursor c1 is
with disabled_users as (
    SELECT regexp_substr(:v_user_list, '[^,]+', 1, LEVEL) user_name
    FROM dual
    CONNECT BY LEVEL <= length(:v_user_list) - length(REPLACE(:v_user_list, ',', '')))
select u.user_name
from fnd_user u, disabled_users d
where u.user_name = d.user_name
 and (u.end_date is null or u.end_date > sysdate) ;
BEGIN
  for c in c1 loop
    fnd_user_pkg.disableuser(c.user_name);
    dbms_output.put_line(c.user_name||' : Disabled Succesfully');
  end loop;
  commit;
END;
/
begin
 dbms_output.put_line(to_char(sysdate,'YYYY:MM:DD HH24:MI:SS')||' [INFO] Script Ends');
end;
/
EOF

#================================================================
# End of script
#================================================================

