define filename=date
column filename new_value filename
select 'scriptname_'||to_char(sysdate, 'yyyymmdd') filename from dual;
spool '&filename'
spool off