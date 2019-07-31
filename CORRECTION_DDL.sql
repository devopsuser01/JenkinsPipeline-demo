-- Correction script to bring schema CRPOOL03020200_3361@db09 to validate at version 
whenever sqlerror exit 1
set echo on
set serveroutput on
spool CORRECTION_DDL.lst

------ADDITIONS-------

-- PRE
exec LANDA_CONVERSION.CREATE_TABLE ('SCD_SCH_DETAILS','MAX2_ELA_TS','SCD_UID','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_SCH_ID','NUMBER','(15,5)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_SEQUENCE','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_STATUS','VARCHAR2','(8)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_ACTION','VARCHAR2','(8)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_OBJECT','VARCHAR2','(32)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_NAME','VARCHAR2','(64)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_TIME_START','TIMESTAMP','(6)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_TIME_STOP','TIMESTAMP','(6)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_RECORD_VERSION','NUMBER','(10,0)','0');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_USR_UID_CREATED_BY','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_CREATE_DATE','DATE','');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_USR_UID_UPDATED_BY','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCD_SCH_DETAILS','SCD_LAST_UPDATE_DATE','DATE','');
exec LANDA_CONVERSION.CREATE_TABLE ('SCH_CHANGE_HISTORY','MAX2_ELA_TS','SCH_UID','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_SHS_SCRIPT','VARCHAR2','(32)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_ID','NUMBER','(15,5)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_REVISION','NUMBER','(10,0)','0');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_SCH_ID_PARENT','NUMBER','(15,5)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_STATUS','VARCHAR2','(8)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_CUSTOM_YN','VARCHAR2','(1)','N');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_TIME_START','TIMESTAMP','(6)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_TIME_STOP','TIMESTAMP','(6)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_RECORD_STATUS','VARCHAR2','(1)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_RECORD_VERSION','NUMBER','(10,0)','0');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_USR_UID_CREATED_BY','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_CREATE_DATE','DATE','');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_USR_UID_UPDATED_BY','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCH_CHANGE_HISTORY','SCH_LAST_UPDATE_DATE','DATE','');
exec LANDA_CONVERSION.CREATE_TABLE ('SCL_CONVERSION_LOG','MAX2_ELA_TS','SCL_UID','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_TIME','TIMESTAMP','(6)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_SCH_ITEM','NUMBER','(15,5)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_SEQUENCE','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_STATUS','VARCHAR2','(8)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_TEXT','VARCHAR2','(200)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_SHS_SCRIPT_NAME','VARCHAR2','(24)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_RECORD_VERSION','NUMBER','(10,0)','0');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_USR_UID_CREATED_BY','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_CREATE_DATE','DATE','');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_USR_UID_UPDATED_BY','NUMBER','(10,0)');
exec LANDA_CONVERSION.ADD_COLUMN ('SCL_CONVERSION_LOG','SCL_LAST_UPDATE_DATE','DATE','');
exec LANDA_CONVERSION.ADD_INDEX ('SCD_PRIMARY_KEY','SCD_SCH_DETAILS','SCD_UID','MAX2_INDEX_E_TS');
exec LANDA_CONVERSION.ADD_INDEX ('SCH_INDEX_01','SCH_CHANGE_HISTORY','SCH_SCH_ID_PARENT','MAX2_INDEX_E_TS');
exec LANDA_CONVERSION.ADD_INDEX ('SCH_PRIMARY_KEY','SCH_CHANGE_HISTORY','SCH_UID','MAX2_INDEX_E_TS');
exec LANDA_CONVERSION.ADD_INDEX ('SCH_UNIQUE_01','SCH_CHANGE_HISTORY','SCH_ID,SCH_REVISION','MAX2_INDEX_E_TS');
exec LANDA_CONVERSION.ADD_INDEX ('SCL_PRIMARY_KEY','SCL_CONVERSION_LOG','SCL_UID','MAX2_INDEX_E_TS');

------MAPPING-------

-- MAP

------CONSTRAINTS-------

-- POST
exec LANDA_CONVERSION.ADD_NOT_NULL ('SCD_SCH_DETAILS','SCD_UID','SCD_NOT_NULL_01');
exec LANDA_CONVERSION.ADD_NOT_NULL ('SCH_CHANGE_HISTORY','SCH_UID','SCH_NOT_NULL_01');
exec LANDA_CONVERSION.ADD_NOT_NULL ('SCH_CHANGE_HISTORY','SCH_ID','SCH_NOT_NULL_02');
exec LANDA_CONVERSION.ADD_NOT_NULL ('SCH_CHANGE_HISTORY','SCH_REVISION','SCH_NOT_NULL_03');
exec LANDA_CONVERSION.ADD_NOT_NULL ('SCL_CONVERSION_LOG','SCL_UID','SCL_NOT_NULL_01');
exec LANDA_CONVERSION.ADD_PRIMARY_KEY ('SCD_SCH_DETAILS','SCD_PRIMARY_KEY','SCD_UID');
exec LANDA_CONVERSION.ADD_PRIMARY_KEY ('SCH_CHANGE_HISTORY','SCH_PRIMARY_KEY','SCH_UID');
exec LANDA_CONVERSION.ADD_PRIMARY_KEY ('SCL_CONVERSION_LOG','SCL_PRIMARY_KEY','SCL_UID');
exec LANDA_CONVERSION.ADD_UNIQUE ('SCH_CHANGE_HISTORY','SCH_UNIQUE_01','SCH_ID,SCH_REVISION');
exec LANDA_CONVERSION.CREATE_TRIGGER ('SCD_TGRB_U_01 BEFORE UPDATE ON SCD_SCH_DETAILS FOR EACH ROW','','BEGIN IF(:new.SCD_RECORD_VERSION >= 0) THEN :new.SCD_RECORD_VERSION := :old.SCD_RECORD_VERSION +1; ELSE :new.SCD_RECORD_VERSION := :old.SCD_RECORD_VERSION ; END IF; END;');
exec LANDA_CONVERSION.CREATE_TRIGGER ('SCH_TGRB_U_01 BEFORE UPDATE ON SCH_CHANGE_HISTORY FOR EACH ROW','','BEGIN IF(:new.SCH_RECORD_VERSION >= 0) THEN :new.SCH_RECORD_VERSION := :old.SCH_RECORD_VERSION +1; ELSE :new.SCH_RECORD_VERSION := :old.SCH_RECORD_VERSION ; END IF; END;');
exec LANDA_CONVERSION.CREATE_TRIGGER ('SCL_TGRB_U_01 BEFORE UPDATE ON SCL_CONVERSION_LOG FOR EACH ROW','','BEGIN IF(:new.SCL_RECORD_VERSION >= 0) THEN :new.SCL_RECORD_VERSION := :old.SCL_RECORD_VERSION +1; ELSE :new.SCL_RECORD_VERSION := :old.SCL_RECORD_VERSION ; END IF; END;');

------DROPS-------

-- DROP
spool off
exit
