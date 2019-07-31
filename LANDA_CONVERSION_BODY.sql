set echo off
CREATE or REPLACE 
PACKAGE BODY LANDA_CONVERSION 
AS

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
LC_PACKAGE_VERSION          VARCHAR2(32);
LC_PACKAGE_REVISION         VARCHAR2(32);
LANDA_FAILURE_LEVEL_CODE    INTEGER;
LANDA_DEFAULT_FAILURE_CODE  INTEGER;
LANDA_FAILURE_LEVEL_MAX     INTEGER;
addColumnFailureLevel       INTEGER;
addConstraintFailureLevel   INTEGER;
addFKFailureLevel           INTEGER;
addIndexFailureLevel        INTEGER;
addPrimaryKeyFailureLevel   INTEGER;
addSequenceFailureLevel     INTEGER;
addTableFailureLevel        INTEGER;
addTextIndexFailureLevel    INTEGER;
addTriggerFailureLevel      INTEGER;
addUniqueFailureLevel       INTEGER;
backUpDataFailureLevel      INTEGER;
ConstraintIndexLevel        INTEGER;
CreatePreferenceFailureLevel INTEGER;
CreateTriggerFailureLevel   INTEGER;
CreateSequenceFailureLevel  INTEGER;
CreateTableFailureLevel     INTEGER;
deleteFKchildrenFailureLevel INTEGER;
deleteValueFailureLevel     INTEGER;
disableConstraintFailureLevel INTEGER;
dropColumnFailureLevel      INTEGER;
dropConstraintFailureLevel  INTEGER;
dropFKsFailureLevel         INTEGER;
dropIndexFailureLevel       INTEGER;
dropTableFailureLevel       INTEGER;
dropTabSequenceFailureLevel INTEGER;
dropTriggerFailureLevel     INTEGER;
enableConstraintFailureLevel INTEGER;
insertPKvalsFailureLevel    INTEGER;
insertValsFailureLevel      INTEGER;
landaInsertFailureLevel     INTEGER;
modifyColumnFailureLevel    INTEGER;
moveIndTblspcFailureLevel   INTEGER;
renameColumnFailureLevel    INTEGER;
renameConstraintFailureLevel INTEGER;
renameIndexFailureLevel     INTEGER;
renameTableFailureLevel     INTEGER;
setAttributeFailureLevel    INTEGER;
updateValueFailureLevel     INTEGER;
SCH_TABLE_EXISTS            INTEGER;
LCURRENTITEM                VARCHAR2(32);
LCURRENTSCRIPT              VARCHAR2(32);    -- holds the name of the script current
LCURRENTSCHUID              NUMBER;          -- the current SCH uid for the item --drop this
LCURRENTSCDUID              NUMBER;
LCURRENTDVT                 VARCHAR2(16);   -- the current DVT number (ID)
LCURRENTSEQUENCE            NUMBER(3);     -- the DVT sequence
LCURRENTSTATUS              VARCHAR2(8);     -- the status set but the currently running sql
LCURRENTITERATOR            NUMBER(3);  -- the item number - starts with 1 incremented for each procedure run
LSQL                        VARCHAR2(4000);
EX_CODE                     NUMBER;
EX_TEXT                     VARCHAR2(200);
NUMBER_VAR                  NUMBER;
L_DATA_SEPARATOR varchar2(8);
constList varchar2(256);
L_DATEFORMAT varchar2(32) := 'MM/DD/YYYY';
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- FUNCTION       :  GET_OBJECT_TBLSP
-- DESCRIPTION    :  return saved contraint index tablespace so that it can be recreated in the correct tablespace
--                   The tablespace  should be saved before disabling/or dropping the constraint
-- POST CONDITIONS:  SUCCESS  : tablespace name is found and returned
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : null string returned.

-- NOTES          :  Internal Package function only - there is no output generated
FUNCTION GET_OBJECT_TBLSP (
   objectName IN VARCHAR2
)
   RETURN varchar2

AS
tableSpaceName VARCHAR2(30);
   BEGIN
      LSQL := 'SELECT LANDA_OBJ_TBLSP FROM LANDA_OBJECT_TBLSP where LANDA_OBJ_NAME = ''' || upper(objectName) || ''' and rownum < 2';
      BEGIN
         EXECUTE IMMEDIATE LSQL into tableSpaceName;
         EXCEPTION
            WHEN OTHERS THEN
               tableSpaceName := '';
      END;
   return tableSpaceName;
   END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  SET_OBJECT_TBLSP
-- DESCRIPTION    :  saves contraint/table/index tablespace so that it can be recreated in the correct tablespace
--                   The tablespace  should be saved when disabling/or dropping the constraint
-- POST CONDITIONS:  SUCCESS  : tablespace name is found and stored
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : no value is stored for the tablespace for that object.

-- NOTES          :  Internal Package function only -no output generated.
PROCEDURE SET_OBJECT_TBLSP (
   objectName IN VARCHAR2,
   objectType IN VARCHAR2 default 'INDEX'
)

AS
tableSpaceName VARCHAR2(30);
tableCount number;
selectColumn varchar2(30);
selectTable varchar2(30);
   BEGIN
      tableSpaceName := upper(objectType);
      select count(*) into tableCount from USER_TABLES where TABLE_NAME = 'LANDA_OBJECT_TBLSP';
      IF tableCount = 0 THEN
         LSQL := 'CREATE TABLE LANDA_OBJECT_TBLSP (LANDA_OBJ_NAME VARCHAR2(30), LANDA_OBJ_TBLSP VARCHAR2(30))';
         EXECUTE IMMEDIATE LSQL;
      END IF;
      IF tableSpaceName = 'INDEX' THEN
         selectTable := 'USER_INDEXES';
         selectColumn := 'INDEX_NAME';
      ELSIF tableSpaceName = 'TABLE' THEN
         selectTable := 'USER_TABLES';
         selectColumn := 'TABLE_NAME';
      ELSIF tableSpaceName = 'LOB' THEN
         selectTable := 'USER_LOBS';
         selectColumn := 'COLUMN_NAME';
      END IF;
      LSQL := 'INSERT INTO LANDA_OBJECT_TBLSP (LANDA_OBJ_NAME, LANDA_OBJ_TBLSP) values (''' ||
      upper(objectName) || ''', (select TABLESPACE_NAME from ' ||
      selectTable || ' where ' || selectColumn || ' = ''' ||
      upper(objectName) || '''))';
      EXECUTE IMMEDIATE LSQL;
      commit;
   END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE       :  DELETE_OBJECT_TBLSP
-- DESCRIPTION    :  removes saved contraint index tablespace 
-- POST CONDITIONS:  SUCCESS  : tablespace name is found and removed
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : 

-- NOTES          :  Internal Package function only - there is no output generated
PROCEDURE DELETE_OBJECT_TBLSP (
   objectName        IN    VARCHAR2
)

AS
   BEGIN
      LSQL := 'DELETE FROM LANDA_OBJECT_TBLSP where LANDA_OBJ_NAME = '''|| upper(objectName)||'''';
      BEGIN
         EXECUTE IMMEDIATE LSQL;
         EXCEPTION
            WHEN OTHERS THEN
            null;
      END;
      COMMIT;
   END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- FUNCTION       :  GET_DEFAULT_TBLSP
-- DESCRIPTION    :  return standard index tablespace so that indexes can be recreated in the correct tablespace

-- POST CONDITIONS:  SUCCESS  : tablespace name is found and returned
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : null string returned.

-- NOTES          :  Internal Package function only - there is no output generated
FUNCTION GET_DEFAULT_TBLSP (
   tableName   IN    VARCHAR2,
   bailOnFail  IN    VARCHAR2    default 'N'
)
   RETURN varchar2

AS
tableSpaceName VARCHAR2(30);
   BEGIN
      BEGIN
         SELECT TABLESPACE_NAME into tableSpaceName from USER_TABLES where TABLE_NAME = upper(tableName);
         IF tableSpaceName like '%SHA%' THEN
            tableSpaceName := 'MAX2_INDEX_S_TS';
         ELSIF tableSpaceName like '%ELA%' THEN
            tableSpaceName := 'MAX2_INDEX_E_TS';
         ELSIF tableSpaceName like '%SLA%' THEN
            tableSpaceName := 'MAX2_INDEX_S_TS';
         ELSIF tableSpaceName like '%EHA%' THEN
            tableSpaceName := 'MAX2_INDEX_E_TS';
         ELSIF tableSpaceName like '%DTX%' THEN
            tableSpaceName := tableSpaceName;
         END IF;
         EXCEPTION
            WHEN OTHERS THEN
               tableSpaceName := '';
      END;
   return tableSpaceName;
   END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

FUNCTION GET_FAILURE_LEVEL
   return integer

AS
   BEGIN
      return GET_LANDA_FAILURE_LEVEL();
   END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

FUNCTION GET_LANDA_FAILURE_LEVEL
   return integer

AS
   BEGIN
      IF LANDA_FAILURE_LEVEL_CODE is NULL THEN
         LANDA_FAILURE_LEVEL_CODE := LANDA_DEFAULT_FAILURE_CODE;
      END IF;
      return LANDA_FAILURE_LEVEL_CODE;
   END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE SET_LANDA_FAILURE_LEVEL (
   newLevel integer
)

AS
   BEGIN
      IF newLevel > -1 AND newLevel < 6 THEN
         LANDA_FAILURE_LEVEL_CODE := newLevel;
      ELSE
         dbms_output.put_line('FAILURE CODE LEVEL ' || newLevel || ' is invalid.  Should be 0 to 5');
         if LANDA_FAILURE_LEVEL_CODE is NULL THEN
            LANDA_FAILURE_LEVEL_CODE := LANDA_DEFAULT_FAILURE_CODE;
         END IF;
      END IF;
   END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE HANDLE_ERROR (
    lbail varchar2,
    lfailurelevel integer default 3,
    lerrmessage varchar2 default null
)

AS
    BEGIN
        IF EX_CODE = -20001 THEN
        RETURN;
        ELSE
        POST('ERROR', EX_CODE || ': ' ||  translate(LSQL,chr(13)||chr(10), ' '));
        IF lbail = 'Y' OR (GET_FAILURE_LEVEL() >= lfailurelevel) THEN
--             POST('ERROR', EX_CODE || ': ' ||  translate(LSQL,chr(13)||chr(10), ' '));
            raise_application_error (-20001, lerrmessage);
        END IF;
        END IF;
        -- POST('WARNING', EX_CODE || ': ' ||  translate(LSQL,chr(13)||chr(10), ' '));
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- Function         :   GET_VERSION
-- DESCRIPTION      :   gets the version number from script Name
-- INPUT            :   Script Name like CR02040500.sql
-- Return:          :   Return Version 8 digit nnumber like 02.04.05.00

FUNCTION GET_VERSION (scriptName IN varchar2)
RETURN varchar2
AS
version varchar(20);
versions varchar(20);
num varchar(2) := 'N';
   BEGIN
    versions := REGEXP_SUBSTR(scriptName,'\d{8}');
    if versions is not null then
        version := SUBSTR(versions,1,2) || '.' || SUBSTR(versions,3,2) || '.' || SUBSTR(versions,5,2) || '.' || SUBSTR(versions,7,2);
    else
        version := '';
    end if;
    return version;
    END; 

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- Function         :   GET_FAILED_SCRIPT
-- DESCRIPTION      :   return name of failed script
-- INPUT            :   N/A
-- Return:          :   Return script name or null if no script was found
FUNCTION GET_FAILED_SCRIPT
RETURN varchar2
AS
    failedScript varchar2(25) := null;
BEGIN
    EXECUTE IMMEDIATE 'SELECT SHS_SQL_SCRIPT_NAME
      FROM (SELECT SHS_SQL_SCRIPT_NAME 
              FROM SHS_SCHEMA_HISTORY
             WHERE SHS_UID = (SELECT MAX(SHS_UID) 
                                FROM SHS_SCHEMA_HISTORY 
                               WHERE SHS_TYPE = ''UPDATE''
                                 AND SHS_RESULTS <> ''Successful'' 
                                 AND SHS_VERSION_NEW is not null))' into failedScript;
    return failedScript;
    Exception
        when no_data_found then
        failedScript := null;
        return failedScript;
END;

   -- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE        :   SHS_ENTRY
-- DESCRIPTION      :   This proc enter row in SHS_SCHEMA_HISTORY table if row is not present and change the status of entry

PROCEDURE SHS_ENTRY (scriptName varchar2, status varchar2, versionName varchar2 default null, scriptType varchar2 default 'UPDATE')
AS
    shsExists integer;
    rowCount integer;
    version varchar(20);
    BEGIN        
        rowCount := 0;
        EXECUTE IMMEDIATE 'select count(*) from user_tables where table_name = ''SHS_SCHEMA_HISTORY''' into shsExists;
        if shsExists > 0 then
            EXECUTE IMMEDIATE 'select count(*) from SHS_SCHEMA_HISTORY where SHS_SQL_SCRIPT_NAME = ''' || scriptName || '''' into rowCount;
        else
            version := null;
        end if;
        -- select count(*)  into rowCount from SHS_SCHEMA_HISTORY where SHS_SQL_SCRIPT_NAME = scriptName;
        
        IF versionName is null THEN
            version := GET_VERSION(scriptName);
        else
            version := versionName;
        END IF;
        
        if shsExists > 0 then
            IF rowCount > 0 THEN
            EXECUTE IMMEDIATE 'UPDATE    SHS_SCHEMA_HISTORY
                        SET     SHS_VERSION_OLD = (
                        SELECT    MAX (SHS_VERSION_NEW) 
                        FROM    SHS_SCHEMA_HISTORY 
                        WHERE    SHS_VERSION_NEW < ''' || version || ''' AND SHS_VERSION_NEW LIKE ''%.%.%.%''),
                        SHS_RESULTS = ''' || status || ''',
                        SHS_LAST_UPDATE_DATE = sysdate,
                        SHS_USR_UID_UPDATED_BY = -4
                    WHERE  SHS_SQL_SCRIPT_NAME = ''' || scriptName || ''' ';
                    COMMIT;
            else
                    EXECUTE IMMEDIATE 'INSERT INTO SHS_SCHEMA_HISTORY (
                    SHS_UID,
                    SHS_TYPE,
                    SHS_VERSION_OLD,
                    SHS_VERSION_NEW,
                    SHS_SQL_SCRIPT_NAME,
                    SHS_DESC,
                    SHS_DATE,
                    SHS_TIME,
                    SHS_RESULTS,
                    SHS_CREATE_DATE,
                    SHS_USR_UID_CREATED_BY
                    ) SELECT SHS_SEQUENCE.NEXTVAL,
                    ''' || scriptType || ''',
                    ''NONE'',
                    ''' || version || ''',
                    ''' || scriptName || ''',
                    ''Version Release Update Script'',
                    TO_DATE (to_char (SYSDATE,''MM/DD/YYYY''), ''MM/DD/YYYY''),
                    TO_CHAR (SYSDATE,''HH24MI''),
                    ''' || status || ''',
                    SYSDATE,
                    -4
                    FROM DUAL';
                    COMMIT;
            END IF;
        end if;
    END;    
 

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE        :   START_SCRIPT
-- DESCRIPTION      :  run at beginning of version script
-- POST CONDITIONS:  : package values for current script set.
PROCEDURE START_SCRIPT (
    scriptName varchar2, 
    versionName varchar2 default null, 
    scriptType varchar2 default 'UPDATE'
)

AS
status varchar(10);
    BEGIN
        LCURRENTITEM := NULL;
        LCURRENTSEQUENCE := NULL;
        LCURRENTSTATUS := NULL;
        LCURRENTITERATOR := NULL;
        status := 'Started';
        IF scriptName is not null THEN
            LANDA_CONVERSION.SHS_ENTRY (scriptName, status, versionName, scriptType);
        END IF;
        LANDA_LOGGING.createOrUpdateLoggingTable('N'); -- quick check
        LANDA_LOGGING.setScriptName(scriptName);
        LCURRENTSCRIPT := scriptName;
        SCH_TABLE_EXISTS := 0;
        SCH_TABLE_EXISTS := SETUPHISTORY('N'); -- quick check
        LANDA_LOGGING.setLog('START');
        LANDA_LOGGING.LOG('BEGIN Conversion script ' || LCURRENTSCRIPT,'','','INFO',LCURRENTSCRIPT);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE        :   Stop_script
-- DESCRIPTION      :  run at conclusion of version script
-- POST CONDITIONS:  : package values for current script set to null.
PROCEDURE STOP_SCRIPT (
    scriptName varchar2 default null, 
    versionName varchar2 default null, 
    scriptType varchar2 default 'UPDATE'
)

AS
status varchar(10);
FAILEDCOUNT number default 0;
    BEGIN
        EXECUTE IMMEDIATE 'SELECT count(*) from SCH_CHANGE_HISTORY
            where   SCH_STATUS = ''S'' and SCH_SHS_SCRIPT = ''' || scriptName || '''' into FAILEDCOUNT;
        IF FAILEDCOUNT > 0 THEN
            POST('ERROR','ERROR: a previous item did not succeed');
            HANDLE_ERROR(lbail=>'Y', lerrmessage=>'EXITING as one of the previous item did not succeed');
        END IF;
        status := 'Successful';
        POST('SUCCESS','END Conversion script ' || LCURRENTSCRIPT );
        LANDA_LOGGING.setLog('STOP');
        -- dbms_output.put_line('*****Version Name is******' || versionName);
        IF scriptName is not null THEN
            LANDA_CONVERSION.SHS_ENTRY (scriptName, status, versionName, scriptType);
        ELSIF landa_logging.getScriptName() is not null THEN
            LANDA_CONVERSION.SHS_ENTRY (landa_logging.getScriptName(), status, versionName, scriptType);
        END IF;
        LANDA_LOGGING.setScriptName(NULL);
        LCURRENTSCRIPT := NULL;
        LCURRENTITEM := NULL;
        LCURRENTSEQUENCE := NULL;
        LCURRENTSTATUS := NULL;
        LCURRENTITERATOR := NULL;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- FUNCTION       :  START_ITEM
-- DESCRIPTION    :  Set up for a DVT based grouping (ITEM) of SQL (interscript like)
-- POST CONDITIONS:  TRUE     : item has not been run, or needs to be re-run
--                   false    : item succeeded already. 
-- ITEM TYPE         S = system data; M = mapping; C = custom; N = non system; D = ddl
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  :
FUNCTION START_ITEM (
    ID         varchar2,
    PARENT_ID  varchar2 default null,
    REVISION   varchar2 default '0',
    ITEM_TYPE     varchar2 default 'N'
)
RETURN boolean

AS
    lobjectCount integer;
    BEGIN
        -- select from table to see if item has succeeded.
        IF LCURRENTITEM is not null THEN
            EXECUTE IMMEDIATE 'SELECT SCH_STATUS from SCH_CHANGE_HISTORY
                where   SCH_ID = ''' || LCURRENTITEM || '''
                and SCH_UID = (SELECT MAX(SCH_UID) from SCH_CHANGE_HISTORY
                    where   SCH_ID = ''' || LCURRENTITEM || ''')' into LCURRENTSTATUS;
            IF LCURRENTSTATUS IN ('F') THEN
                -- log failure
                POST('ERROR','ERROR: a previous item: ' ||  LCURRENTITEM || ', did not succeed');
                HANDLE_ERROR(lbail=>'Y', lerrmessage=>'EXITING as previous item: ' ||  LCURRENTITEM || ', did not succeed');
            END IF;
        END IF;
        IF PARENT_ID IS NOT NULL THEN
            EXECUTE IMMEDIATE 'SELECT nvl((SELECT SCH_STATUS from SCH_CHANGE_HISTORY
                where SCH_ID = ''' || PARENT_ID || '''
                and SCH_UID = (SELECT MAX(SCH_UID) from SCH_CHANGE_HISTORY
                    where   SCH_ID = ''' || PARENT_ID || ''')),''F'') from dual' into LCURRENTSTATUS;
                    -- need a catch for no values returned
            IF LCURRENTSTATUS NOT IN ('C', 'W', 'I') THEN
                -- log failure
                POST('ERROR','ERROR: parent depency item: ' ||  PARENT_ID || ', did not succeed');
                HANDLE_ERROR(lbail=>'Y', lerrmessage=>'EXITING as parent depency item: ' ||  PARENT_ID || ', did not succeed');
            END IF;
        END IF;
        LCURRENTITEM := ID;
        LCURRENTITERATOR := 0;
        LCURRENTSCDUID := '-1';
        EXECUTE IMMEDIATE 'SELECT count(*) from SCH_CHANGE_HISTORY
            where   SCH_ID = ''' || LCURRENTITEM || '''
            and SCH_REVISION = ''' || REVISION || '''
            and     (SCH_STATUS = ''C'')' into lobjectCount;  -- was  OR SCH_STATUS = W
        IF lobjectCount > 0 THEN
            LCURRENTSTATUS := 'C';
            POST('INFO', 'SKIPPING: item ' || LCURRENTITEM || '. It has already run successfully.');
            return false;
        ELSE
            LCURRENTSTATUS := 'S';
            EXECUTE IMMEDIATE 'SELECT count(*) from SCH_CHANGE_HISTORY
                where   SCH_ID = ''' || LCURRENTITEM || '''
                and SCH_REVISION = ''' || REVISION || '''
                and     (SCH_STATUS not in (''C''))' into lobjectCount;
            IF lobjectCount = 0 THEN
                -- not been run
                EXECUTE IMMEDIATE 'SELECT SCH_SEQUENCE.NEXTVAL from dual' into LCURRENTSCHUID;
                EXECUTE IMMEDIATE 'INSERT INTO SCH_CHANGE_HISTORY (
                    SCH_UID,SCH_SHS_SCRIPT,SCH_ID,SCH_SCH_ID_PARENT,
                    SCH_TIME_START,SCH_TIME_STOP,SCH_REVISION,SCH_STATUS,SCH_RECORD_STATUS,
                    SCH_TYPE
                ) values (
                  ''' || LCURRENTSCHUID || ''',''' || LCURRENTSCRIPT || ''',''' || LCURRENTITEM || ''',''' || PARENT_ID || ''',
                    systimestamp,  null, ''' || REVISION || ''', ''S'', ''A'', ''' || ITEM_TYPE || ''')';
                POST('START', 'STARTING ITEM ' || LCURRENTITEM);
            ELSE
                EXECUTE IMMEDIATE 'SELECT MAX(SCH_UID) from SCH_CHANGE_HISTORY
                where   SCH_ID = ''' || LCURRENTITEM || '''
                and SCH_REVISION = ''' || REVISION || '''
                and     (SCH_STATUS not in (''C''))' into LCURRENTSCHUID;
                POST('RESTART', 'RESTARTING ITEM ' || LCURRENTITEM || 'UID = ' || LCURRENTSCHUID);
            END IF;
        END IF;
        RETURN TRUE;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE        :   STOP_ITEM
-- DESCRIPTION      :  run at conclusion of ITEM grouping, records status of worst item in group
-- POST CONDITIONS:  : none
PROCEDURE STOP_ITEM

AS
    BEGIN
        IF LCURRENTSTATUS = 'S' THEN
            LCURRENTSTATUS := 'C';
        ELSIF LCURRENTSTATUS = 'F' THEN
            -- if error was severe enough to warrant exiting, it should have exited already.
            POST('ERROR', 'WARNING: an item within: ' || LCURRENTITEM || ', did not succeed. Please review the logs.');
            LCURRENTSTATUS := 'E';
        END IF;
        EXECUTE IMMEDIATE 'UPDATE SCH_CHANGE_HISTORY SET
            SCH_TIME_STOP = systimestamp,
            SCH_STATUS = ''' || LCURRENTSTATUS || '''
        WHERE
            SCH_UID = ''' || LCURRENTSCHUID || '''';
        COMMIT;
        LCURRENTITERATOR := 0;
        LCURRENTSCHUID := '';
        LCURRENTSCDUID := '-1';
        POST('SUCCESS', 'COMPLETED ' || LCURRENTITEM || ' with status ' || LCURRENTSTATUS);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE        :   STATUS
-- DESCRIPTION      :  run at begin and end of individual LANDA DDL or DML procedures to log and track status
-- POST CONDITIONS:  : START item is logged in SCD table with status S
-- STOP: status updated to the status sent in
FUNCTION STATUS (
lstatus  varchar2,
laction  varchar2 default null,
lobject  varchar2 default null,
lname     varchar2 default null,
ltext    varchar2 default null,
lscduid number default 0,
ORAERRORNUMBER number default 0
)
return NUMBER
AS
    TEMP_UID number := -1;
    stringResult varchar2(16);
    BEGIN
        IF lstatus = 'S' THEN
            stringResult := 'START';
            IF LCURRENTITEM is not null THEN
                execute immediate 'select scd_sequence.nextval from dual' into TEMP_UID;
                IF LCURRENTSCDUID <= 0 THEN
                    LCURRENTITERATOR := LCURRENTITERATOR + 1;
                    LCURRENTSCDUID := TEMP_UID;
                END IF;
                EXECUTE IMMEDIATE 'INSERT INTO SCD_SCH_DETAILS (
                    SCD_UID,
                    SCD_SCH_ID,
                    SCD_SEQUENCE,
                    SCD_ACTION,
                    SCD_NAME,
                    SCD_OBJECT,
                    SCD_STATUS,
                    SCD_TIME_START
                ) values (  ''' ||
                    TEMP_UID || ''', '''||
                    LCURRENTITEM || ''',''' ||
                    LCURRENTITERATOR || ''',''' ||
                    laction || ''',''' ||
                    substr(lname,1,64) || ''',''' ||
                    lobject || ''',''' ||
                    lstatus || ''',
                    systimestamp
                )';
                commit;
            END IF;
            POST(stringResult, stringResult || ' ' || laction || ' ' || lobject || ' ' || lname || ' ' || ltext);
        ELSE
            IF lscduid > 0 THEN
                TEMP_UID := lscduid;
                EXECUTE IMMEDIATE 'UPDATE SCD_SCH_DETAILS set
                    SCD_STATUS = ''' || lstatus || ''',
                    SCD_TIME_STOP = systimestamp
                WHERE
                    SCD_UID = ' || lscduid || '
                    AND SCD_STATUS = ''S''';
                commit;
                    IF lscduid = LCURRENTSCDUID then
                        LCURRENTSCDUID := 0;
                END IF;
            END IF;
            IF lstatus = 'C' THEN
                stringResult := 'COMPLETE';
            ELSIF lstatus = 'E' THEN
                stringResult := 'ERROR';
            ELSIF lstatus = 'F' THEN
                stringResult := 'FAIL';
--                 POST('SQL:', LSQL);
            ELSIF lstatus = 'I' THEN
                stringResult := 'INFO';
            ELSIF lstatus = 'W' THEN
                stringResult := 'WARNING';
            ELSE
                stringResult := 'UNKNOWN';
            END IF;
            POST(stringResult,stringResult || ' : ' || ORAERRORNUMBER || ' : ' || trim(ltext));
        END IF;
        LCURRENTSTATUS := lstatus;
        return TEMP_UID;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE        :   POST
-- DESCRIPTION      :  convenience function to call the landa_logging LOG 
-- POST CONDITIONS:  : none
PROCEDURE POST (
    lstatus VARCHAR2,
    ltext VARCHAR2
)

AS
    BEGIN
        LANDA_LOGGING.LOG(ltext, LCURRENTITEM, LCURRENTITERATOR, lstatus, LCURRENTSCRIPT);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- 
-- PROCEDURE:        LANDA_ADD_COLUMN
-- DESCRIPTION:      Adds a column to the indicated table.
-- POST CONDITIONS:  SUCCESS  :  COLUMN ADDED
--                   INFO     :  COLUMN EXISTS
--                   ERROR 
--                   FAILURE  :  COLUMN does not exist, is wrong datatype, or too small
-- NOTE(S):
PROCEDURE ADD_COLUMN (
   tableName         IN    VARCHAR2,
   columnName        IN    VARCHAR2,
   columnDataType    IN    VARCHAR2,
   columnLength      IN    VARCHAR2    default NULL,
   defaultValue      IN    VARCHAR2    default NULL,
   constraintClause  IN    VARCHAR2    default NULL,
   bailOnFail        IN    VARCHAR2    default 'N'
)

AS
   defaultClause       VARCHAR2(40);
   columnLengthClause  VARCHAR2(100);
   v_scd_uid integer;
   BEGIN
        IF defaultValue is not null THEN
            defaultClause := ENSURE_QUOTES(defaultValue);
            IF instr(upper(defaultValue), 'DEFAULT') = 0 THEN
                defaultClause := ' DEFAULT ' || defaultClause ;
            END IF;
        END IF;
        -- Ensure data length is parenthesized
        IF columnLength is not null THEN
            columnLengthClause := ENSURE_PARENS(columnLength);
        END IF;        
        select count(*) into NUMBER_VAR FROM USER_TAB_COLUMNS where column_name = upper(columnName) and table_name = upper(tableName);
        IF NUMBER_VAR = 0 THEN
            v_scd_uid := STATUS(lscduid=>0, lstatus=>'S', ORAERRORNUMBER=>'0', laction=>'ADD', lobject=>'COLUMN', lname=>tableName || '.' || columnName, ltext=>columnLength || ' ' || columnDataType || ' ' || defaultValue || ' ' || constraintClause);
            BEGIN
                LSQL := 'ALTER TABLE ' || tableName || ' ADD ' || columnName || ' ' || columnDataType || columnLengthClause ||  ' ' || defaultClause ||  ' ' || constraintClause;
                EXECUTE IMMEDIATE LSQL;
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Added column ' || columnName || ' to table '|| tableName || '.');
            EXCEPTION
            WHEN OTHERS THEN
                EX_CODE := SQLCODE;
                v_scd_uid := STATUS (lscduid=>v_scd_uid, ORAERRORNUMBER=>SQLCODE, lstatus=>'F', ltext=>' ' || SQLERRM || ' ' ||tableName || ' ADD ' || columnName || ' ' || columnDataType || columnLengthClause ||  ' ' || defaultClause ||  ' ' || constraintClause);
                HANDLE_ERROR(bailOnFail, addColumnFailureLevel, SQLERRM);
            END;
        ELSE
            MODIFY_COLUMN(tableName, columnName, columnDataType,columnLengthClause,defaultClause,constraintClause,bailOnFail);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
        -- EX_CODE := SQLCODE;
        v_scd_uid := STATUS (lscduid=>v_scd_uid, lstatus=>'F', ORAERRORNUMBER=>SQLCODE, ltext=>' ' || SQLERRM || ' ' ||tableName || ' ADD ' || columnName || ' ' || columnDataType || columnLengthClause ||  ' ' || defaultClause ||  ' ' || constraintClause);
        HANDLE_ERROR(bailOnFail, addColumnFailureLevel, SQLERRM);
   END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_ADD_FOREIGN_KEY
-- DESCRIPTION    :  Adds named fk constraint onto table.column on table2.column2
-- POST CONDITIONS:  SUCCESS  : constraint ADDED
--                   INFO     : constraint EXISTS
--                   WARNING  : constraint EXISTS wrong NAME
--                   ERROR    : 
--                   FAILURE  : constraint DOES NOT EXIST, unknown status
PROCEDURE ADD_FOREIGN_KEY (
   childTableName    IN    VARCHAR2,
   constraintName    IN    VARCHAR2,
   childColumnName   IN    VARCHAR2,
   parentTableName   IN    VARCHAR2,
   parentColumnName  IN    VARCHAR2,
   cascadeClause     IN    VARCHAR2    default NULL,
   bailOnFail        IN    VARCHAR2    default 'N'
)

AS
    tempConstraintName  VARCHAR2(30);
    tempColumnName      VARCHAR2(30);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','ADD','FOREIGN_KEY',childTableName || '.' || childColumnName || '.' || constraintName, 'TO'  || parentTableName || '.' || parentColumnName);
        LSQL := 'ALTER TABLE     ' || childTableName ||
            ' ADD CONSTRAINT  ' || constraintName|| '
            FOREIGN KEY    (' || childColumnName || ')
            REFERENCES      ' || parentTableName || ' (' || parentColumnName || ')' ||
            ' ' || cascadeClause;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Created foreign key constraint ' || constraintName || '.');
    EXCEPTION
        WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        IF EX_CODE = -2275 THEN
            BEGIN
                -- Referential constraint already exists
                SELECT  USER_CONSTRAINTS.CONSTRAINT_NAME, USER_CONS_COLUMNS.COLUMN_NAME
                    INTO    tempConstraintName, tempColumnName
                FROM    USER_CONSTRAINTS, USER_CONS_COLUMNS
                WHERE   USER_CONS_COLUMNS.COLUMN_NAME = upper(childColumnName)
                    AND USER_CONSTRAINTS.TABLE_NAME = upper(childTableName)
                    AND USER_CONSTRAINTS.R_CONSTRAINT_NAME =  (
                        SELECT  CONSTRAINT_NAME
                        FROM    USER_CONSTRAINTS
                        WHERE   CONSTRAINT_TYPE = 'P'
                            AND     TABLE_NAME = upper(parentTableName))
                    AND USER_CONSTRAINTS.CONSTRAINT_NAME = USER_CONS_COLUMNS.CONSTRAINT_NAME;
                IF tempConstraintName = constraintName THEN
                -- OK constraint exists already
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' ' || constraintName || ' on ' || childTableName || '.'|| childColumnName || ' already exists.', ORAERRORNUMBER=> EX_CODE);
                ELSIF tempColumnName = childColumnName THEN
                -- OK constraint exists, but wrong name - will need to fix later. - OR  fix it now?
                    POST ('WARNING',LSQL);
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ORAERRORNUMBER=>EX_CODE, ltext=>'Modify constraint name' || tempConstraintName || ' to ' || constraintName || ' on ' || childTableName || '.'|| childColumnName || '. Constraint ' || tempConstraintName || ' on column ' || childColumnName || ' already exists.');
                    HANDLE_ERROR(bailOnFail, renameConstraintFailureLevel, SQLERRM);
                END IF;
            END;
        ELSIF EX_CODE = -2264 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ORAERRORNUMBER=>EX_CODE, ltext=>' ' || SQLERRM || ' Cannot add constraint ' || constraintName || ' to ' || childTableName || '. Constraint ' || constraintName || ' is already being used by another object.');
            HANDLE_ERROR(bailOnFail, addFKFailureLevel, SQLERRM);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ORAERRORNUMBER=>EX_CODE, ltext=>' ' || SQLERRM || 'Cannot add constraint ' || constraintName || ' to ' || childTableName || '.');
            HANDLE_ERROR(bailOnFail, addFKFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- ADD_INDEX
-- Adds named index onto any number of columns to table
-- POST CONDITIONS:  SUCCESS  : named index of table ADDED
--                   INFO     : named index of table EXISTS
--                   WARNING  : index EXISTS, wrong NAME
--                   ERROR    : index DOES NOT EXIST
--                   FAILURE  : unknown status
-- Success - this script returns without error for all but unknown errors
-- Failure - Unknown errors.
PROCEDURE ADD_INDEX (
   indexName         IN    VARCHAR2,
   tableName         IN    VARCHAR2,
   columnNameList    IN    VARCHAR2,
   tbSpace           IN    VARCHAR2,
   initamt           IN    INTEGER     DEFAULT 8,
   nextamt           IN    INTEGER     DEFAULT 120,
   bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    oname               VARCHAR2(32);
    counter             INTEGER;
    columnList          VARCHAR2(2000);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','ADD','INDEX',tableName || '.' || indexName, columnNameList || ' ' || tbSpace || ' ' || initamt || ' ' || nextamt);
        LSQL := 'CREATE INDEX ' || indexName || ' ON ' || tableName || ' (' || columnNameList || ') TABLESPACE ' || tbSpace || ' STORAGE ( INITIAL ' || initamt || ' K NEXT ' || nextamt || ' K )';
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' ' || indexName || ' added to ' || tableName ||' on columns '|| columnNameList);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
            -- remove any spaces from columnNameList, and count the commas and add one to get number of columns
        columnList := translate(columnNameList, ', ', ',');
        counter := regexp_count(columnList, ',') + 1; 
        IF EX_CODE = -955 THEN -- name is already in use - could be correct index, or could be wrong
            SELECT count(*) into NUMBER_VAR FROM USER_IND_COLUMNS WHERE INDEX_NAME = upper(indexName);
            IF NUMBER_VAR = 0 THEN
                -- object of that name is not an index.
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ORAERRORNUMBER=>EX_CODE, ltext=>' ' || SQLERRM || ' : DROP object ' || indexName || ' : CREATE INDEX ' || indexName);
                HANDLE_ERROR(bailOnFail, addIndexFailureLevel, SQLERRM);
            ELSIF NUMBER_VAR != counter THEN
            -- index has wrong number of columns
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ORAERRORNUMBER=>EX_CODE, ltext=>' ' || SQLERRM || ' : DROP INDEX ' || indexName || ' : RECREATE INDEX ' || indexName);
                HANDLE_ERROR(bailOnFail, addIndexFailureLevel, SQLERRM);
            ELSE
                -- maybe it is correct listagg will return comma separated columns
                select count(*) INTO NUMBER_VAR 
                FROM DUAL 
                WHERE (SELECT  distinct listagg(COLUMN_NAME, ',') within group (order by COLUMN_POSITION) over (partition by INDEX_NAME) 
                   from USER_IND_COLUMNS 
                    where  TABLE_NAME = upper(tableName) and INDEX_NAME = upper(indexName)) = upper(columnList);
                IF NUMBER_VAR = 1 THEN
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ORAERRORNUMBER=>0,ltext=>' Index ' || indexName || ' already exists.');
                ELSE
                    -- wrong columns 
                    POST ('FAIL',LSQL);
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ORAERRORNUMBER=>EX_CODE, ltext=>' ' || SQLERRM || ' : DROP INDEX ' || indexName || ' : RECREATE INDEX ' || indexName);
                    HANDLE_ERROR(bailOnFail, addIndexFailureLevel, SQLERRM);
                END IF;
            END IF;
        ELSIF EX_CODE = -1408 THEN -- such an index definition already exists.
            select distinct nvl(INDEX_NAME,'NONE') into oname
            from USER_IND_COLUMNS UIC 
            where 
            upper(columnList) = (SELECT  distinct listagg(COLUMN_NAME, ',') within group (order by COLUMN_POSITION) over (partition by INDEX_NAME) 
                    from USER_IND_COLUMNS 
                    where  TABLE_NAME = upper(tableName) and INDEX_NAME = UIC.INDEX_NAME);
            IF oname = indexName THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Index ' || indexName || ' already exists.', ORAERRORNUMBER=> EX_CODE);
            ELSE
                -- wrong name
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ORAERRORNUMBER=>EX_CODE, ltext=>' ' || SQLERRM || ' : RENAME INDEX ' || oname || ' : TO ' || indexName);
                HANDLE_ERROR(bailOnFail, renameIndexFailureLevel, SQLERRM);
            END IF;
        ELSE
            -- unknown
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ORAERRORNUMBER=>EX_CODE, ltext=>' ' || SQLERRM || ' : DROP INDEX ' || indexName || ' : RECREATE INDEX ' || indexName);
            HANDLE_ERROR(bailOnFail, addIndexFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- ADD_INDEX_1C
-- adds named index to one named column on table
-- NOTE for two-column indexes, user ADD_INDEX
-- TODO - update to hANDle variable volume indexes
-- POST CONDITIONS:  SUCCESS  : index ADDED
--                   INFO     : index EXISTS
--                   WARNING  : index EXISTS, wrong NAME
--                   ERROR    : index DOES NOT EXIST
--                   FAILURE  : unknown status
-- Success - this script returns without error for all but unknown errors
-- Failure - Unknown errors.
PROCEDURE ADD_INDEX_1C (
    tableName         VARCHAR2,
    columnName        VARCHAR2,
    indexName         VARCHAR2,
    tbSpace           VARCHAR2,
    initamt           INTEGER     DEFAULT 8,
    nextamt           INTEGER     DEFAULT 120,
    bailOnFail        VARCHAR2    default 'N'
    )

AS
    BEGIN
        ADD_INDEX(indexName, tableName, columnName,tbSpace, initamt, nextamt, bailonFail);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_ADD_INDEX_2C
-- Adds named index onto two columns of table
-- POST CONDITIONS:  SUCCESS  : named index onto two columns of table ADDED
--                   INFO     : named index onto two columns of table EXIST
--                   WARNING  : index EXISTS, wrong NAME
--                   ERROR    : index DOES NOT EXIST
--                   FAILURE  : unknown status
-- Success - this script returns without error for all but unknown errors
-- Failure - Unknown errors.
PROCEDURE ADD_INDEX_2C (
    indexName         IN    VARCHAR2,
    tableName         IN    VARCHAR2,
    columnName1       IN    VARCHAR2,
    columnName2       IN    VARCHAR2,
    tbSpace           IN    VARCHAR2,
    initamt           IN    INTEGER     DEFAULT 8,
    nextamt           IN    INTEGER     DEFAULT 120,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    BEGIN
       ADD_INDEX(indexName, tableName, columnName1 || ',' || columnName2, tbSpace, initamt, nextamt, bailonFail);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE:      LANDA_ADD_NOT_NULL
-- POST CONDITIONS:  SUCCESS  : constraint ADDED
--                   INFO     : constraint EXISTS
--                   WARNING  : constraint EXISTS wrong NAME
--                   ERROR    : 
--                   FAILURE  : constraint DOES NOT EXIST, unknown status
-- DESCRIPTION:    Adds a not null constraint on the indicated column.
-- FAILS if it cannot be added, or status unknown. 
-- NOTE(S):
PROCEDURE ADD_NOT_NULL (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

AS
    temp VARCHAR2(32);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','ADD','NOT_NULL',tableName || '.' || columnName, constraintName);
        LSQL :=  'ALTER TABLE ' || tableName || ' MODIFY ( ' || columnName || ' CONSTRAINT ' || constraintName || ' NOT NULL )';
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Added not null constraint ' || constraintName || ' to column ' || columnName || '.');
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        IF EX_CODE = -1442 THEN
            SELECT UC.CONSTRAINT_NAME
               into temp
            FROM USER_CONS_COLUMNS UCC, USER_CONSTRAINTS UC
            WHERE UCC.COLUMN_NAME = upper(columnName)
                AND UC.TABLE_NAME = upper(tableName)
                AND UC.CONSTRAINT_NAME = UCC.CONSTRAINT_NAME
                and UC.CONSTRAINT_TYPE = 'C'
                ;
            IF temp = upper(constraintName) THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Constraint ' || constraintName || ' already exists on column ' || columnName || '.');
            ELSE
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>' ' || SQLERRM || ' : RENAME CONSTRAINT ' || temp || ' to ' || constraintName);
                HANDLE_ERROR(bailOnFail, renameConstraintFailureLevel, SQLERRM);
            END IF;
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ': REMOVE NULL VALUES : ADD CONSTRAINT ' || constraintName || ' to COLUMN ' || columnName || '.', ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addConstraintFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_ADD_PRIMARY_KEY
-- POST CONDITIONS:  SUCCESS  : constraint ADDED
--                   INFO     : constraint EXISTS
--                   WARNING  : constraint EXISTS wrong NAME
--                   ERROR    : 
--                   FAILURE  : constraint DOES NOT EXIST, unknown status
-- adds named primary key to column (s)  on table
-- Success - primary key added, or IF it exists already
-- Failure - Table does not have primary key or unknown status
PROCEDURE ADD_PRIMARY_KEY (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    columnNames       IN    VARCHAR2,
    indexTableSpace   IN    VARCHAR2    DEFAULT NULL,
    bailOnFail        IN    VARCHAR2    default 'N'
)

AS
    temp varchar2(128);
    v_scd_uid integer;
    BEGIN
        CONSTRAINT_INDEX(tableName, constraintName, columnNames, indexTableSpace, 'P');
        v_scd_uid := STATUS('S','ADD','PRIMARY_KEY',tableName || '.' || constraintName, columnNames || ' ' || indexTableSpace);
        LSQL := 'ALTER TABLE '|| tableName || ' ADD CONSTRAINT ' || constraintName || ' PRIMARY KEY (' || columnNames || ')';
        EXECUTE IMMEDIATE LSQL ;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' Primary Key constraint '|| constraintName || ' added to table ' || tableName || ' on ' || columnNames);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        IF EX_CODE = -2260 OR EX_CODE = -2261 THEN  -- table already has a primary key
            SELECT listagg(COLUMN_NAME, ',') within group (order by POSITION) into temp
            FROM USER_CONS_COLUMNS
            WHERE CONSTRAINT_NAME = (SELECT CONSTRAINT_NAME from USER_CONSTRAINTS where CONSTRAINT_TYPE = 'P' and TABLE_NAME = upper(tableName))
                AND TABLE_NAME = upper(tableName);
            IF temp = upper(columnNames) THEN -- pk has same column definition
                SELECT CONSTRAINT_NAME into temp
                FROM USER_CONSTRAINTS
                WHERE CONSTRAINT_TYPE = 'P' and TABLE_NAME = upper(tableName);
                IF temp = upper(constraintName) THEN -- it already exists
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' Table ' || tableName || ' already has primary key ' || constraintName);
                ELSE -- same columns, different name
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>' RENAME CONSTRAINT ' || temp || ' to ' || constraintName);
                    HANDLE_ERROR(bailOnFail, renameConstraintFailureLevel, SQLERRM);
                END IF;
            ELSE -- different column definition
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' : DROP PRIMARY KEY CONSTRAINT FROM ' || tableName || ' : RECREATE CONSTRAINT ' || constraintName, ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, addPrimaryKeyFailureLevel, SQLERRM);
            END IF;
        ELSE -- unknown error
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addPrimaryKeyFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE ADD_UNIQUE
-- DESCRIPTION    :  adds named unique key to column (s)  on table
-- POST CONDITIONS:  SUCCESS  : constraint ADDED
--                   INFO     : constraint EXISTS
--                   WARNING  : constraint EXISTS wrong NAME
--                   ERROR    : 
--                   FAILURE  : constraint DOES NOT EXIST, unknown status
-- NOTES          :  
-- TO DO
-- logic should be, if errors:
   -- ora 2261 - Is it the correct name NO: rename
   -- ora -955 - could be it is already there (INFO), or that an object already exists (drop object note, addconstraint error)
   -- ora -02299 - duplicate keys already exist (addconstraint error)
   --
PROCEDURE ADD_UNIQUE (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    tableSpace        IN    VARCHAR2    default NULL,
    bailOnFail        IN    VARCHAR2    default 'N'
)

AS
colsName        VARCHAR2(256);
temp            VARCHAR2(256);
tempName        VARCHAR2(32);
v_scd_uid integer;
    BEGIN
        colsName := replace(columnName, ' ');
        CONSTRAINT_INDEX(tableName, constraintName, colsName, tableSpace, 'U');
        v_scd_uid := STATUS('S','ADD','UNIQUE',tableName || '.' || constraintName, colsName || ' ' || tableSpace);
        -- check for index of the same name as the unique constraint.
        -- If it does not exist, create it as long as it is not position 1 on another index.
        LSQL := ' ALTER TABLE '|| tableName || ' ADD CONSTRAINT ' || constraintName || ' UNIQUE ('|| colsName ||')';
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' '|| constraintName || ' added to the table ' || tableName || '.' || colsName);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE :=SQLCODE;
        IF EX_CODE = -2261 THEN  -- constraint with those columns already in use: need to discern if correct name also
            SELECT distinct(UC.CONSTRAINT_NAME) into tempName
            from USER_CONSTRAINTS UC, USER_CONS_COLUMNS UCC
            where UC.CONSTRAINT_NAME = UCC.CONSTRAINT_NAME
            and UC.TABLE_NAME = upper(tableName)
            and UC.CONSTRAINT_TYPE in ('U','P')
            and (SELECT listagg(COLUMN_NAME, ',') within group (order by POSITION) from USER_CONS_COLUMNS
            where CONSTRAINT_NAME = UC.CONSTRAINT_NAME) = upper(colsName);
            IF tempName = upper(constraintName) THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' Table ' || tableName || ' already has unique key ' || constraintName, ORAERRORNUMBER=> EX_CODE);
            ELSE
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>' RENAME CONSTRAINT '  || tempName || ' on ' ||  tableName ||  '.' || colsName || ' to ' || constraintName || '.' );
                HANDLE_ERROR(bailOnFail, renameConstraintFailureLevel, SQLERRM);
            END IF;
        ELSIF EX_CODE = -2264 THEN -- name is correct,
            -- Name is in use : if name and column description matches, INFO,
            SELECT listagg(UCC.COLUMN_NAME, ',') within group (order by UCC.POSITION) into temp
            FROM USER_CONS_COLUMNS UCC, USER_CONSTRAINTS UC
            WHERE UCC.CONSTRAINT_NAME = upper(constraintName)
                AND UC.CONSTRAINT_NAME = upper(constraintName)
                AND UC.TABLE_NAME = upper(tableName)
                AND UC.CONSTRAINT_TYPE in ('U','P');
            IF temp = upper(colsName) THEN
                IF tempName = upper(constraintName) THEN
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' Table ' || tableName || ' already has unique key ' || constraintName, ORAERRORNUMBER=> EX_CODE);
                ELSE
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>' ' || SQLERRM || ' : RENAME UNIQUE KEY CONSTRAINT ' || tableName || ' : TO ' || constraintName);
                    HANDLE_ERROR(bailOnFail, renameConstraintFailureLevel, SQLERRM);
                END IF;
            ELSE
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' : DROP UNIQUE KEY CONSTRAINT FROM ' || tableName || ' : RECREATE CONSTRAINT ' || constraintName, ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, addConstraintFailureLevel, SQLERRM);
            END IF;
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' : Could not add constraint '  || constraintName || ' to ' || tableName || ' column(s) ' || colsName, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addConstraintFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE CONSTRAINT_INDEX
-- DESCRIPTION    :  creates index if checks for existence of index name on tablename and index position 1 on column name are false
-- POST CONDITIONS:  SUCCESS  : index already exists or index created
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : unknown status
-- NOTES          :  
-- TO DO
-- logic should be, if errors:
--
PROCEDURE CONSTRAINT_INDEX (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    columnNames       IN    VARCHAR2,
    tableSpace        IN    VARCHAR2 DEFAULT NULL,
    constraintType    IN    VARCHAR2 DEFAULT 'U'
)

AS
    tableSpaceValue     VARCHAR2(30);
    ind_def_input       VARCHAR2(500);
    ind_name_exist      VARCHAR2(500);
    ind_count           NUMBER;
    v_scd_uid integer;
    BEGIN
        IF tableSpace IS NULL or tableSpace = '' THEN
            tableSpaceValue := GET_DEFAULT_TBLSP(tableName);
        ELSE
            tableSpaceValue := tableSpace;
            select count(*) into NUMBER_VAR from user_tablespaces where tablespace_name = tableSpace;
            IF NUMBER_VAR = 0 THEN
                tableSpaceValue := GET_DEFAULT_TBLSP(tableName);
            END IF;
        END IF;
        ind_def_input := replace(translate(columnNames,' ()''','*'), '*');
        select count(*) into ind_count
            from dual
        where ind_def_input in (SELECT  listagg(COLUMN_NAME, ',') within group (order by COLUMN_POSITION) over (partition by index_name)
            from user_ind_columns);
        IF ind_count = 0 THEN
            ADD_INDEX(constraintName, tableName, ind_def_input,  tableSpaceValue);
        ELSE
            select listagg(uic.index_name,',') within group (order by COLUMN_POSITION)
                into ind_name_exist
                from user_ind_columns uic
                where uic.COLUMN_POSITION = 1
                and ind_def_input in (SELECT  listagg(COLUMN_NAME, ',') within group (order by COLUMN_POSITION) over (partition by index_name)
                    from user_ind_columns
                    where uic.index_name = upper(index_name) and table_name = upper(tableName));
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            EX_CODE :=SQLCODE;
            HANDLE_ERROR('N', addConstraintFailureLevel, 'Unexpected error ' || SQLCODE || ' -ERROR- ' || SQLERRM);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  
-- DESCRIPTION    :  
-- POST CONDITIONS:  SUCCESS  : Preference CREATED
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : Preference DOES NOT EXIST
--                   FAILURE  : unknown status
-- NOTES          :  TO DO: add failure level checks
   -- Check on whether the DRG (DMG?) should not be a continue case - why not continue and try to add preference, then fail?
PROCEDURE CREATE_PREFERENCE (
prefName          IN    VARCHAR2,
objName           IN    VARCHAR2,
addClause         IN    VARCHAR2    default NULL,
bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    objCount        number;
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','CREATE','PREFERENCE',prefName || '.' || objName, 'PREFERENCE For text index ');
        -- IF preference to be created already exists, drop it, to ensure it is correct
        LSQL := 'SELECT count(*) FROM CTXSYS.CTX_PREFERENCES WHERE pre_name = ''' || upper(prefName) || ''' AND PRE_OWNER = (SELECT USER FROM dual)';
        EXECUTE IMMEDIATE LSQL into objCount;
        IF objCount > 0 THEN
            BEGIN
                LSQL := 'BEGIN CTX_DDL.DROP_PREFERENCE ( ''' || upper(prefName) || ''' ); END;';
                EXECUTE IMMEDIATE LSQL;
                -- v_scd_uid := STATUS(lstatus=>'C', ltext=>'Dropped CTXSYS Preference '|| upper(prefName));
            EXCEPTION
            WHEN OTHERS THEN
               -- DMG-10700 indicates the preference does not exist
                objCount := INSTR(SQLERRM, 'DRG-10700');
                IF objCount != 0 THEN
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'Preference was not dropped ' || upper(prefName) || '.' ||upper(objName));
                    HANDLE_ERROR(bailOnFail, addTextIndexFailureLevel, 'Unexpected error ' || SQLCODE || ' -ERROR- ' || SQLERRM);
                    RETURN;
                END IF;
            END;
        END IF;
        -- create preference
        BEGIN
            LSQL := 'BEGIN CTX_DDL.CREATE_PREFERENCE( ''' || upper( prefName ) || ''', ''' || upper(objName) || '''); END;';
            EXECUTE IMMEDIATE LSQL;
            IF upper(prefName) = 'TEXT_STORAGE' OR (addClause IS NOT NULL AND addClause = 'ADD_CLAUSES') THEN
                LSQL := 'BEGIN CTX_DDL.SET_ATTRIBUTE(''' || prefName || ''', ''I_TABLE_CLAUSE'', ''TABLESPACE MAX2_CTX_TS STORAGE (INITIAL 10M NEXT 10M)''); END;';
                EXECUTE IMMEDIATE LSQL;
                LSQL := 'BEGIN CTX_DDL.SET_ATTRIBUTE(''' || prefName || ''', ''K_TABLE_CLAUSE'', ''TABLESPACE MAX2_CTX_TS STORAGE (INITIAL 10M NEXT 10M)''); END;';
                EXECUTE IMMEDIATE LSQL;
                LSQL := 'BEGIN CTX_DDL.SET_ATTRIBUTE(''' || prefName || ''', ''R_TABLE_CLAUSE'', ''TABLESPACE MAX2_CTX_TS STORAGE (INITIAL 1M) lob (data) store AS (cache)''); END;';
                EXECUTE IMMEDIATE LSQL;
                LSQL := 'BEGIN CTX_DDL.SET_ATTRIBUTE(''' || prefName || ''', ''N_TABLE_CLAUSE'', ''TABLESPACE MAX2_CTX_TS STORAGE (INITIAL 1M)''); END;';
                EXECUTE IMMEDIATE LSQL;
                LSQL := 'BEGIN CTX_DDL.SET_ATTRIBUTE(''' || prefName || ''', ''I_INDEX_CLAUSE'', ''TABLESPACE MAX2_CTX_TS STORAGE (INITIAL 1M) compress 2''); END;';
                EXECUTE IMMEDIATE LSQL;
            END IF;
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Created CTXSYS Preference ' || upper(prefName) || '.' ||upper(objName));
        EXCEPTION
        WHEN OTHERS THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'Failed to create CTXSYS Preference ' || upper(prefName) || '.' ||upper(objName), ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addTextIndexFailureLevel, 'Unexpected error ' || SQLCODE || ' -ERROR- ' || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'Failed to create CTXSYS Preference ' || upper(prefName) || '.' ||upper(objName), ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addTextIndexFailureLevel, 'Unexpected error ' || SQLCODE || ' -ERROR- ' || SQLERRM);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE CREATE_TEXT_INDEX (
    indexName varchar2,
    tableName varchar2,
    columnNames varchar2,
    indexType varchar2 default 'CTXSYS.CONTEXT',
    indexParameters varchar2 default 'SYNC (ON COMMIT) STOPLIST CTXSYS.EMPTY_STOPLIST STORAGE TEXT_STORAGE',
    bailonFail varchar2 default 'N'
)

AS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','CREATE','TEXT INDEX',indexName ||'.'|| tableName, columnNames || ' '|| indexType || ' '|| indexParameters);
        LSQL := 'CREATE INDEX ' || indexName || ' ON ' || tableName || '(' || columnNames || ') INDEXTYPE IS ' ||  indexType || ' PARAMETERS (''' ||  indexParameters || ''')';
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'INDEX created ');
    EXCEPTION
        WHEN OTHERS THEN
            EX_CODE := SQLCODE;
            IF EX_CODE = -955 THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'INDEX already exists ');
            ELSE
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, addIndexFailureLevel, 'Unexpected error ' || SQLCODE || ' -ERROR- ' || SQLERRM);
            END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  CREATE_TRIGGER
-- DESCRIPTION    :  Creates a trigger 
-- POST CONDITIONS:  SUCCESS  : trigger CREATED
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : trigger DOES NOT EXIST; unknown status
-- NOTES          :
PROCEDURE CREATE_TRIGGER (
    triggerDescription         IN    VARCHAR2,
    triggerWhenClause          IN    VARCHAR2,
    triggerBody                IN    VARCHAR2,
    bailOnFail                 IN    VARCHAR2    default 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','CREATE','TRIGGER','',triggerDescription);
        LSQL := 'CREATE OR REPLACE TRIGGER ' || triggerDescription || ' ' || triggerWhenClause || ' ' || triggerBody ;
        EXECUTE IMMEDIATE LSQL ;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Created  trigger');
    EXCEPTION
    WHEN OTHERS THEN
        -- Unknown failure
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' : Failed to create trigger "', ORAERRORNUMBER=> EX_CODE);
        HANDLE_ERROR(bailOnFail, addTriggerFailureLevel, SQLERRM);
   END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  CREATE_RECORD_VERSION_TRIGGER
-- DESCRIPTION    :  Creates the record version trigger on a table's XXX_RECORD_VERSION column
-- POST CONDITIONS:  SUCCESS  : trigger CREATED
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : trigger DOES NOT EXIST; unknown status
-- NOTES          :  Deduces the tables record version column name FROM the table
--                   name prefix.  Trigger is always named like "<prefix>_TGRB_U_01".
-- COULD use dbms_metadata.get_ddl and transform an existing trigger?
PROCEDURE CREATE_RECORD_VERSION_TRIGGER (
    tableName         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    v_scd_uid integer;
    columnName  VARCHAR2(100);
    tablePrefix VARCHAR2(3);
    triggerName VARCHAR2(50);
    BEGIN
        tablePrefix := SUBSTR(tableName, 0, 3);
        columnName  := '' || tablePrefix || '_RECORD_VERSION';
        triggerName := '' || tablePrefix || '_TGRB_U_01';
        v_scd_uid := STATUS('S','CREATE','TRIGGER',tableName || '.' || columnName || '.' || triggerName);
        LSQL := 'CREATE OR REPLACE TRIGGER ' || triggerName || '
BEFORE UPDATE ON ' || tableName|| '
FOR EACH ROW
BEGIN
IF (:new.' || columnName || ' >= 0)  THEN
  :new.' || columnName || ' := :old.' || columnName || ' +1;
ELSE
  :new.' || columnName || ' := :old.' || columnName || ';
END IF;
END;';
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Created record version trigger ' || triggerName || ' on table ' || tableName || '.');
    EXCEPTION
    WHEN OTHERS THEN
        -- Unknown failure
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' : Failed to create trigger ' || triggerName || '.', ORAERRORNUMBER=> EX_CODE);
        HANDLE_ERROR(bailOnFail, addTriggerFailureLevel, SQLERRM);
    END;
    
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  CREATE_RECORD_VERSION_TRIGGERS
-- DESCRIPTION    :  Creates record version triggers on all table's XXX_RECORD_VERSION column
-- POST CONDITIONS:  SUCCESS  : triggers CREATED
-- disadvantage: cannot rely on tor, as it may not yet be repopulated
-- hence any client table with _RECORD_VERSION may be picked up.
PROCEDURE CREATE_RECORD_VERSION_TRIGGERS 
IS
    trigCount integer;
    cursor trigcur is select distinct table_name from user_tables UT where exists 
    (select table_name from user_tab_columns where column_name = substr(UT.TABLE_NAME,1,3) || '_RECORD_VERSION' and data_type = 'NUMBER' 
    union select TABLE_OWNER from user_TRIGGERS where trigger_name like '____TGRB_U_01') 
    order by UT.TABLE_NAME;
    BEGIN
        for trigrow in trigcur LOOP
            execute immediate 'select count(*) from tor_table_order where TOR_TABLE_NAME = ''' || trigrow.table_name || '''' into trigCount;
            IF trigCount > 0 THEN
                CREATE_RECORD_VERSION_TRIGGER(trigrow.table_name);
            END IF;
        END LOOP;
    END;
    
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_RECORD_VERSION_TRIGGERS
-- DESCRIPTION    :  Drops record version triggers from all table's XXX_RECORD_VERSION column
-- POST CONDITIONS:  SUCCESS  : triggers dropped
PROCEDURE DROP_RECORD_VERSION_TRIGGERS 
IS
    trigCount integer;
    cursor trigcur is select trigger_name, table_name from user_triggers where trigger_name like '____TGRB_U_01' order by trigger_name;
    BEGIN
        for trigrow in trigcur LOOP
            execute immediate 'select count(*) from tor_table_order where TOR_TABLE_NAME = ''' || trigrow.table_name || '''' into trigCount;
            IF trigCount > 0 THEN
                execute immediate 'DROP TRIGGER ' || trigrow.trigger_name;
            END IF;
        END LOOP;
    END;
    
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  ENABLE_RECORD_VERSION_TRIGGERS
-- DESCRIPTION    :  Enables or recreates all triggers on XXX_RECORD_VERSION columns or where trigger name like ____TGRB_U_01
-- POST CONDITIONS:  SUCCESS  : triggers exist, valid and enabled
-- NOTE           :  there is one TGRB_U_02, we are ignoring
PROCEDURE ENABLE_RECORD_VERSION_TRIGGERS 
IS
    trigCount integer;
    cursor trigcur is select distinct table_name, substr(table_name,1,3) || '_TGRB_U_01' trigName from (
        select table_name from user_tab_columns where column_name = substr(table_name,1,3) || '_RECORD_VERSION' 
            and data_type = 'NUMBER' 
        union select table_name from user_TRIGGERS UT where trigger_name = substr(UT.table_name,1,3) || '_TGRB_U_01') 
        order by trigName;
    BEGIN
        FOR trigrow in trigcur LOOP
            BEGIN
                execute immediate 'select count(*) from tor_table_order where TOR_TABLE_NAME = ''' || trigrow.Table_name || '''' into trigCount;
                IF trigCount > 0 THEN
                    select count(status)  into NUMBER_VAR from user_objects where object_name = trigrow.trigName and status = 'VALID';
                    if NUMBER_VAR != 1 then
                       DROP_TRIGGER(trigrow.trigName);
                       CREATE_RECORD_VERSION_TRIGGER(trigrow.table_name);
                    ELSE
                        execute immediate 'ALTER TRIGGER ' || trigrow.trigName || ' ENABLE';
                    end if;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    DROP_TRIGGER(trigrow.trigName);
            end;
        END LOOP;
    END;
    
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DISABLE_RECORD_VERSION_TRIGS
-- DESCRIPTION    :  Drops record version triggers from all table's XXX_RECORD_VERSION column
-- POST CONDITIONS:  SUCCESS  : triggers dropped
PROCEDURE DISABLE_RECORD_VERSION_TRIGS 
IS
    trigCount integer;
    cursor trigcur is select trigger_name, table_name from user_triggers where trigger_name like '____TGRB_U_01' order by trigger_name;
    BEGIN
        FOR trigrow in trigcur LOOP
            execute immediate 'select count(*) from tor_table_order where TOR_TABLE_NAME = ''' || trigrow.Table_name || '''' into trigCount;
            IF trigCount > 0 THEN
                execute immediate 'ALTER TRIGGER ' || trigrow.trigger_name || ' DISABLE';
            END IF;
        END LOOP;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  CREATE_SEQUENCE
-- DESCRIPTION    :  Creates a named sequence with known start
-- POST CONDITIONS:  SUCCESS  : sequence CREATED
--                   INFO     : sequence RECREATED
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : sequence DOES NOT EXIST; unknown status
-- NOTES          :  
-- TO DO: add insert into the SEQ table with only WARNING on failure
-- add fail level
PROCEDURE CREATE_SEQUENCE (
    sequenceName      IN    VARCHAR2,
    startValue        IN    NUMBER      default 1,
    incrementValue    IN    NUMBER      default 1,
    maximumValue      IN    NUMBER      default 9999999999,
    cycleParam        IN    VARCHAR2    default 'NOCYCLE',
    cacheParam        IN    VARCHAR2    default '',
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    cacheClause varchar2(20);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','CREATE','SEQUENCE', sequenceName, startValue || ' ' || cacheParam);
        IF cacheParam is NULL or cacheParam = '' THEN
            cacheClause := 'NOCACHE';
        ELSIF cacheParam = 'NOCACHE' THEN
            cacheClause := cacheParam;
        ELSE
            cacheClause := 'CACHE ' || cacheParam;
        END IF;
        LSQL := 'CREATE SEQUENCE ' || sequenceName || '
                INCREMENT BY ' || incrementValue || '
                START WITH ' || startValue || '
                MAXVALUE '  || maximumValue || '
                ' || cycleParam || '
                ' || cacheClause || '';
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' created sequence ' || sequenceName || '');
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE :=SQLCODE;
        IF EX_CODE = -955 THEN
            -- Sequence already exists
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Sequence ' || sequenceName || ' already exists.', ORAERRORNUMBER=> EX_CODE);
        ELSIF EX_CODE = -1722 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'Invalid number specified in the call to LANDA_CREATE_SEQUENCE.', ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addSequenceFailureLevel, SQLERRM);
        ELSE
            -- Unknown error
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addSequenceFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  CREATE_TABLE
-- DESCRIPTION    :  creates named table in named tablespace with only one named column with definition given
-- POST CONDITIONS:  SUCCESS  : table CREATED as specified
--                   INFO     : table EXISTS as specified
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : table DOES NOT EXIST; table NOT AS SPECIFIED; unknown status

-- NOTES  to create table, we need at least one column.
PROCEDURE CREATE_TABLE (
    tableName         IN    VARCHAR2,
    tablespaceName    IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    columnDataType    IN    VARCHAR2,
    columnLength      IN    VARCHAR2    default '',
    defaultClause     IN    VARCHAR2    default '',
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    dataDefaultClause  VARCHAR2(64);
    columnLengthClause  VARCHAR2(100);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','CREATE','TABLE',tableName || '.' || columnName, columnDataType || ' ' || columnLength || ' ' || tablespaceName);
        IF defaultClause is not null THEN
            dataDefaultClause := ENSURE_QUOTES(defaultClause);
            IF instr(upper(defaultClause), 'DEFAULT') = 0 THEN
                dataDefaultClause := ' DEFAULT ' || dataDefaultClause ;
            END IF;
        END IF;
        -- IF defaultClause != '' or defaultClause is not null THEN
            -- dataDefaultClause := ' DEFAULT ' || defaultClause;
        -- END IF;
        IF columnLength is not null THEN
            columnLengthClause := ENSURE_PARENS(columnLength);
        END IF; 
        LSQL := 'CREATE TABLE ' || tableName || ' ( ' || columnName || ' ' || columnDataType || ' ' || columnLengthClause ||  ' ' || dataDefaultClause || ') TABLESPACE ' || tablespaceName;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Table ' || tableName || ' created.');
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE :=SQLCODE;
        IF EX_CODE = -955 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Table ' || tableName || ' already exists.', ORAERRORNUMBER=> EX_CODE);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' : Could not create table ' || tableName || '.', ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addTableFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DELETE_FK_CHILDREN
-- DESCRIPTION    :  removes child records, or sets the fk column value to null
-- POST CONDITIONS:  SUCCESS  : constraint SATISFIED; all child records DELETED
--                   INFO     : 
--                   WARNING  : constraint SATISFIED; all child records NOT DELETED, 
--                   ERROR    : 
--                   FAILURE  : constraint NOT SATISFIED; unknown status
-- NOTES          :
PROCEDURE DELETE_FK_CHILDREN (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    colVal            IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    updatedrows     NUMBER;
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DELETE','FK_CHILD',tableName || '.' || columnName, colVal);
        LSQL := '';
        LSQL := 'DELETE FROM ' || tableName || ' WHERE ' || columnName || ' = ''' || colVal || '''';
        EXECUTE IMMEDIATE LSQL;
        updatedrows := sql%rowcount;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' ' || updatedrows || ' rows deleted FROM FK column.');
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        IF EX_CODE = -2292 THEN -- child records found -
            BEGIN
                LSQL := 'UPDATE ' || tableName || ' SET ' || columnName || ' = NULL WHERE ' || columnName || ' = ''' || colVal || '''';
                EXECUTE IMMEDIATE LSQL;
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>' ' || SQLERRM || ' : Could not delete records - Nulled out reference to parent instead', ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, deleteValueFailureLevel, SQLERRM);
            EXCEPTION
            WHEN OTHERS THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' Unable to delete or set foreign key value to NULL.', ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, deleteFKchildrenFailureLevel, SQLERRM);
            END;
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, deleteFKchildrenFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DELETE_VALUE
-- DESCRIPTION    :  deletes indicated data.
-- POST CONDITIONS:  SUCCESS  : data DELETED
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : data NOT DELETED
--                   FAILURE  : unknown status

-- NOTES          :  outputs number of records deleted
PROCEDURE DELETE_VALUE (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    value1            IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

AS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DELETE','VALUE',tableName || '.' || columnName, value1);
        LSQL := 'DELETE FROM ' || tableName || ' WHERE ' || columnName || ' = ''' ||  value1 || '''';
        EXECUTE IMMEDIATE LSQL;
        NUMBER_VAR := sql%rowcount;
        IF NUMBER_VAR = 0 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' ' || NUMBER_VAR || ' : record(s) deleted.');
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' ' || NUMBER_VAR || ' record(s) deleted.');
        END IF;
        COMMIT;
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' : Could not delete ' || value1 || ' FROM ' || tableName, ORAERRORNUMBER=> EX_CODE);
        HANDLE_ERROR(bailOnFail, deleteValueFailureLevel, SQLERRM);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DISABLE_COL_CONSTRAINTS
-- DESCRIPTION    :  disables all constraints on a single column
-- POST CONDITIONS:  SUCCESS  : Constraint(s) disabled
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : Constraint does not exist; Table, or column does not exist
--                   FAILURE  : Constraint could not be disabled, unknown status

-- NOTES          :  Existance of column is checked first, so that error can be thrown as needed.
PROCEDURE DISABLE_COL_CONSTRAINTS (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    v_scd_uid integer;
    CURSOR conscur IS SELECT CONSTRAINT_NAME FROM USER_CONS_COLUMNS WHERE COLUMN_NAME = columnName
    AND TABLE_NAME = tableName;
    BEGIN
        v_scd_uid := STATUS('S','DISABLE','COL_CONS',tableName || '.' || columnName, '');
        SELECT count(*)
            into NUMBER_VAR
        FROM USER_TAB_COLUMNS
        WHERE COLUMN_NAME = upper(columnName)
            AND TABLE_NAME = upper(tableName);
        IF NUMBER_VAR = 0 THEN  -- column doesnt exist
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' Table or Column ' || tableName || '.' || columnName || ' does not exist.');
            HANDLE_ERROR(bailOnFail, disableConstraintFailureLevel, 'ORA-00942/ORA-00904 Table or Column does not exist');
        ELSE
            SELECT count(*)
                into NUMBER_VAR
            FROM USER_CONS_COLUMNS
            WHERE COLUMN_NAME = columnName
                AND TABLE_NAME = tableName;
            IF NUMBER_VAR = 0 THEN -- no constraints
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'INFO   : 0 :  - no constraints exist on ' || columnName);
            ELSE
                FOR conskrow IN conscur LOOP
                    BEGIN
                        LSQL := 'ALTER TABLE ' || tableName || ' DISABLE CONSTRAINT ' || conskrow.constraint_name;
                        EXECUTE IMMEDIATE LSQL;
                        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' ' || tableName || '.' || conskrow.constraint_name || ' on ' || columnName || ' disabled.');
                    EXCEPTION
                    WHEN OTHERS THEN
                        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
                        HANDLE_ERROR(bailOnFail, disableConstraintFailureLevel, SQLERRM);
                    END;
                END LOOP;
            END IF;
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_DISABLE_CONSTRAINT
-- PROCEDURE      :  DISABLE_CONSTRAINT
-- DESCRIPTION    :  disables a named constraint on a particular table.
-- POST CONDITIONS:  SUCCESS  : constraint disabled
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : constraint doesn't exist
--                   FAILURE  : constraint not able to be disabled; unknown status

-- NOTES          :  
-- TO DO: modify to handle cases such as in disable_col_constraint?
PROCEDURE DISABLE_CONSTRAINT (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DISABLE','CONSTRAINT',tableName || '.' || constraintName, '');
        SET_OBJECT_TBLSP(constraintName);
        LSQL := 'ALTER TABLE ' || tableName || ' DISABLE CONSTRAINT ' || constraintName;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>' ' || tableName || '.' || constraintName || ' has been disabled.');
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE :=SQLCODE;
        IF EX_CODE = -2431 THEN -- constraint (by that name) does not exists
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>' ' || SQLERRM || ' Constraint ' || constraintName ||' does not exist.', ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, disableConstraintFailureLevel, SQLERRM);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, disableConstraintFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_DISABLE_FK_CONSTRAINTS
-- Given a primary key name, disable all FK's constrained to that primary key
-- Success - constraints are disabled (or don't exist)
-- Failure  - IF constraint cannot be disabled. - can be overridden with bailOnFail = false
-- PROCEDURE      :  
-- DESCRIPTION    :  
-- POST CONDITIONS:  SUCCESS  : all fk constraints disabled
--                   INFO     : 
--                   WARNING  : table has not pk, fk constraint non - existant
--                   ERROR    : 
--                   FAILURE  : could not disable constraint, unknown status

-- NOTES          :
PROCEDURE DISABLE_FK_CONSTRAINTS (
    primaryKeyName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    tableName varchar2(32);
    constraintName varchar2(32);
    v_scd_uid integer;
    cursor fkcur is
    SELECT CONSTRAINT_NAME, TABLE_NAME FROM USER_CONSTRAINTS WHERE R_CONSTRAINT_NAME = upper(primaryKeyName);
    BEGIN
        v_scd_uid := STATUS('S','DISABLE','FK_CONST',primaryKeyName, '');
        SELECT count(CONSTRAINT_NAME) into NUMBER_VAR FROM USER_CONSTRAINTS WHERE R_CONSTRAINT_NAME = upper(primaryKeyName);
        IF NUMBER_VAR = 0 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>' ' || SQLERRM || ' : A primary key with the name ' || primaryKeyName || ' does not exist.');
            HANDLE_ERROR(bailOnFail, disableConstraintFailureLevel, SQLERRM);
        ELSE
            DECLARE
            cursor fkcur is
            SELECT CONSTRAINT_NAME, TABLE_NAME FROM USER_CONSTRAINTS WHERE R_CONSTRAINT_NAME = upper(primaryKeyName);
            BEGIN
                FOR fkrow IN fkcur LOOP
                    BEGIN
                        SET_OBJECT_TBLSP(fkrow.TABLE_NAME, 'TABLE');
                        LSQL := 'ALTER TABLE ' || fkrow.table_name || ' DISABLE CONSTRAINT ' || fkrow.CONSTRAINT_NAME;
                        EXECUTE IMMEDIATE LSQL;
                        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'foreign key ' || fkrow.CONSTRAINT_NAME || ' is disabled.');
                    EXCEPTION
                    WHEN OTHERS THEN
                        EX_CODE := SQLCODE;
                        IF EX_CODE = -2431 THEN -- constraint does not exist
                            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>'constraint ' || fkrow.CONSTRAINT_NAME || ' does not exist: ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
                            HANDLE_ERROR(bailOnFail, dropConstraintFailureLevel, SQLERRM);
                        ELSE
                            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
                            HANDLE_ERROR(bailOnFail, disableConstraintFailureLevel, SQLERRM);
                        END IF;
                    END;
                END LOOP;
            END;
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- ENABLE_FK_CONSTRAINTS
-- Given a primary key name, enable all FK's constrained to that primary key
-- Success - constraints are enabled (or don't exist)
-- Failure  - IF constraint cannot be enabled. - can be overridden with bailOnFail = false
-- PROCEDURE      :  
-- DESCRIPTION    :  
-- POST CONDITIONS:  SUCCESS  : all fk constraints enabled
--                   INFO     : 
--                   WARNING  : table has not pk, fk constraint non - existant
--                   ERROR    : 
--                   FAILURE  : could not enable constraint, unknown status

-- NOTES          :
PROCEDURE ENABLE_FK_CONSTRAINTS (
    primaryKeyName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    tableName varchar2(32);
    constraintName varchar2(32);
    v_scd_uid integer;
    cursor fkcur is
    SELECT CONSTRAINT_NAME, TABLE_NAME FROM USER_CONSTRAINTS WHERE R_CONSTRAINT_NAME = upper(primaryKeyName);
    BEGIN
        v_scd_uid := STATUS('S','ENABLE','FK_CONST',primaryKeyName, '');
        SELECT count(CONSTRAINT_NAME) into NUMBER_VAR FROM USER_CONSTRAINTS WHERE R_CONSTRAINT_NAME = upper(primaryKeyName);
        IF NUMBER_VAR = 0 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' : A primary key with the name ' || primaryKeyName || ' does not exist.', ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, enableConstraintFailureLevel, SQLERRM);
        ELSE
            DECLARE
                cursor fkcur is
                SELECT CONSTRAINT_NAME, TABLE_NAME FROM USER_CONSTRAINTS WHERE R_CONSTRAINT_NAME = upper(primaryKeyName);
            BEGIN
                FOR fkrow IN fkcur LOOP
                    BEGIN
                        SET_OBJECT_TBLSP(fkrow.TABLE_NAME, 'TABLE');
                        EXECUTE IMMEDIATE 'ALTER TABLE ' || fkrow.table_name || ' ENABLE CONSTRAINT ' || fkrow.CONSTRAINT_NAME;
                        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'foreign key ' || fkrow.CONSTRAINT_NAME || ' is enabled.');
                    EXCEPTION
                    WHEN OTHERS THEN
                        EX_CODE := SQLCODE;
                        IF EX_CODE = -2431 THEN -- constraint does not exist
                            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>' ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
                            HANDLE_ERROR(bailOnFail, addConstraintFailureLevel, SQLERRM);
                        ELSE
                            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
                            HANDLE_ERROR(bailOnFail, enableConstraintFailureLevel, SQLERRM);
                        END IF;
                    END;
                END LOOP;
            END;
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_COLUMN
-- DESCRIPTION    :  sets unused a named column, backing up data from the column if needed.
-- POST CONDITIONS:  SUCCESS  : column dropped
--                   INFO     : column doesnt exist
--                   WARNING  : 
--                   ERROR    : column could not be dropped, bailOnFail = N
--                   FAILURE  : column could not be dropped, unknown status

-- NOTES          :  defaults to save data = Y
PROCEDURE DROP_COLUMN (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    saveData          IN    VARCHAR2 default 'Y',
    bailOnFail        IN    VARCHAR2 default 'N'
)

IS
    backupColumnName varchar2(30);
    pkColList varchar2(128);
    dataType varchar2(64);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DROP','COLUMN',tableName || '.' || columnName, '');
        select count(*) into NUMBER_VAR
        from USER_TAB_COLUMNS
        where TABLE_NAME = upper(tableName);
        IF NUMBER_VAR = 0 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' Table ' || tableName || ' does not exist.');
            HANDLE_ERROR(bailOnFail, addTableFailureLevel, 'Table ' || tableName || ' does not exist.');
            return;
        END IF;
        select count(*) into NUMBER_VAR
        from USER_TAB_COLUMNS
        where COLUMN_NAME = upper(columnName)
          AND TABLE_NAME = upper(tableName);
        IF NUMBER_VAR > 0 THEN
            DROP_CONSTRAINT_FROM_COLUMN(tableName,columnName);
            DROP_INDEX_FROM_COLUMN(tableName,columnName);
            IF saveData = 'Y' THEN
                BEGIN
                    backupColumnName := 'DROP' || substr(columnName, 5, 30);
                    select count(*) into NUMBER_VAR from USER_TAB_COLUMNS
                        where COLUMN_NAME = upper(backupColumnName)
                            AND TABLE_NAME = upper(tableName); 
                    IF NUMBER_VAR = 0 THEN
                        LSQL :=  'ALTER TABLE ' || tableName  || ' RENAME COLUMN ' || columnName || ' TO ' || backupColumnName;
                        EXECUTE IMMEDIATE LSQL;
                        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Renamed column ' || columnName || ' to ' || backupColumnName  || '. Run drop_dropped columns when conversion has been validated.');
                    ELSE
                        LSQL := 'ALTER TABLE ' || tableName || ' SET UNUSED ( ' || columnName || ' )';
                        EXECUTE IMMEDIATE LSQL;
                        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'column ' || columnName || ' has already been renamed to ' || backupColumnName  || ' setting ' || columnName || ' to unused. Please drop unused columns if not set up to do so automatically');
                    END IF;
                EXCEPTION  -- error here indicates column could not be renamed. 
                WHEN OTHERS THEN
                   v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>' ' || SQLERRM || ' : Could not rename column ' || columnName || ' TO ' || backupColumnName || '.', ORAERRORNUMBER=> EX_CODE);
                   HANDLE_ERROR(bailOnFail, addColumnFailureLevel, SQLERRM);
                END;
            ELSIF saveData = 'F' THEN
                LSQL := 'ALTER TABLE ' || tableName || ' DROP ( ' || columnName || ' )';
                EXECUTE IMMEDIATE LSQL;
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Dropped column ' || columnName);
            ELSE
                -- Set the dropped column to unused.
                LSQL := 'ALTER TABLE ' || tableName || ' SET UNUSED ( ' || columnName || ' )';
                EXECUTE IMMEDIATE LSQL;
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Set column ' || columnName || ' to UNUSED. Please drop unused columns if not set up to do so automatically');
            END IF;
        ELSE  -- column doesn't exist -
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Table or column ' || tableName || '.' || columnName || ' does not exist. Cannot drop it.');
            HANDLE_ERROR(bailOnFail, dropColumnFailureLevel, SQLERRM);
        END IF;
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' Unexpected error dropping column ' || columnName || '.', ORAERRORNUMBER=> EX_CODE);
        HANDLE_ERROR(bailOnFail, dropColumnFailureLevel, SQLERRM);
    END;
    
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_DROPPED_COLUMNS
-- DESCRIPTION    :  drops (not set unused) columns that were renamed during conversion to DROP%
-- POST CONDITIONS:  SUCCESS  : column dropped
--                   INFO     : param 1 defaults to null which will drop all columns like DROP% 
                            -- otherwise, only column renamed during run of a particular script 
--                   WARNING  :
--                   ERROR    : 
--                   FAILURE  : unable to drop column; unknown status


PROCEDURE DROP_DROPPED_COLUMNS (
    ScriptName in VARCHAR2 default null
)
IS 
    v_scd_uid integer;
    BEGIN
        IF ScriptName is NULL OR ScriptName = '' THEN
            DECLARE
                type dropVarCur is table of user_tab_columns%rowTYPE;
                dropCols dropVarCur;
            BEGIN
                
                EXECUTE IMMEDIATE 'select *
                from USER_TAB_COLUMNS where COLUMN_NAME like ''DROP%''
                and TABLE_NAME in (SELECT TOR_TABLE_NAME from TOR_TABLE_ORDER)' BULK COLLECT into dropCols;
                FOR dropIndx in 1..dropCols.count LOOP
                    LANDA_CONVERSION.DROP_COLUMN(dropCols(dropIndx).table_name,dropCols(dropIndx).column_name,'F');
                END LOOP;
            END;
        ELSE
--  since we may not yet have the scd table, we cannot reference it directly
            DECLARE
                objectName varchar2(64);
                tableName varchar2(64);
                columnName varchar2(64);
                intval integer;
                type varcur is table of Varchar2(80);
                droppedSCD varcur;
            BEGIN
                Execute immediate 'select  SCD_NAME FROM SCD_SCH_DETAILS 
                where SCD_ACTION = ''DROP'' and SCD_OBJECT = ''COLUMN'' 
                  and SCD_STATUS = ''C'' and SCD_SCH_ID in (SELECT SCH_ID from SCH_CHANGE_HISTORY where SCH_SHS_SCRIPT = ''' || ScriptName || ''')
                ORDER BY SCD_UID'  BULK COLLECT into droppedSCD;
                FOR indx in 1..droppedSCD.count LOOP
                    objectName := droppedSCD(indx);
                    intval := instr(objectName, '.');
                    tableName := substr(objectName, 0, intval - 1);
                    columnName := substr(objectName, intval + 1);
                    objectName := 'DROP' || substr(columnName,5);
                    LANDA_CONVERSION.DROP_COLUMN(tableName,objectName,'F');
                END LOOP;
            END;
        END IF;
    END;
    
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_CONSTRAINT
-- DESCRIPTION    :  drops constraint after saving the index tablespace for recreation
-- POST CONDITIONS:  SUCCESS  : constraint dropped
--                   INFO     : 
--                   WARNING  : trying to drop non-existant constraint
--                   ERROR    : 
--                   FAILURE  : unable to drop constraint; unknown status

-- NOTES          :   Failure to drop the constraint may cause issues later; thus error is raised
--                    However, this behavior can be overridden with "false" for bailOnFail
PROCEDURE DROP_CONSTRAINT (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DROP','CONSTRAINT',tableName || '.' || constraintName);
         -- in case we are re-creating the constraint
        SET_OBJECT_TBLSP(constraintName);
        LSQL := 'Alter table ' || tableName || ' drop constraint ' || constraintName;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Dropped constraint ' || constraintName || ' FROM ' || tableName || '.');
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        IF EX_CODE = -2443 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Cannot drop constraint ' || constraintName || ' FROM table ' || tableName || '. Constraint does not exist.', ORAERRORNUMBER=> EX_CODE);
        ELSIF EX_CODE = -942 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>'Cannot drop constraint ' || constraintName || ' FROM table ' || tableName || '. Table does not exist.', ORAERRORNUMBER=> EX_CODE);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, dropConstraintFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  
-- DESCRIPTION    :  
-- POST CONDITIONS:  SUCCESS  : 
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : unknown status

-- NOTES          :
PROCEDURE DROP_FOREIGN_KEYS (
    primaryKeyName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    v_scd_uid integer;
    CURSOR fkcur IS
        SELECT CONSTRAINT_NAME, TABLE_NAME FROM USER_CONSTRAINTS WHERE R_CONSTRAINT_NAME = primaryKeyName;
    BEGIN
        v_scd_uid := STATUS('S','DROP','FOREIGN_KEYS',primaryKeyName);
        FOR fkrow IN fkcur LOOP
            BEGIN
                DROP_CONSTRAINT(fkrow.table_name, fkrow.constraint_name, 'Y');
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Constraint ' || fkrow.constraint_name || ' dropped.');
            EXCEPTION
            WHEN OTHERS THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM);
                HANDLE_ERROR(bailOnFail, dropFKsFailureLevel, SQLERRM);
            END;
        END LOOP;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_INDEX
-- DESCRIPTION    :  drops named index
-- POST CONDITIONS:  SUCCESS  : index dropped
--                   INFO     : 
--                   WARNING  : Index did not exist
--                   ERROR    : index could not be dropped
--                   FAILURE  : index could not be dropped and bailOnFail = Y, unknown status

-- NOTES          :  default is to continue on error
PROCEDURE DROP_INDEX (
    indexName         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DROP','INDEX',indexName);
        -- SET_OBJECT_TBLSP(indexName);
        LSQL := 'DROP Index ' || indexName;
        EXECUTE IMMEDIATE  LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'index ' || indexName || ' dropped');
        -- DELETE_OBJECT_TBLSP(tableName,constraintName); -- clean up temp data.
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        IF EX_CODE = -1418 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Index does not exist.', ORAERRORNUMBER=> EX_CODE);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' could not drop ' || indexName, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, dropIndexFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_INDEX_FROM
-- DESCRIPTION    :  drops index with column list
-- POST CONDITIONS:  SUCCESS  : index dropped
--                   INFO     : Index did not exist
--                   WARNING  : index could not be dropped
--                   ERROR    : 
--                   FAILURE  : index could not be dropped and bailOnFail = Y, unknown status

-- NOTES          :  default is to continue on error
PROCEDURE DROP_INDEX_FROM (
    tableName         IN    VARCHAR2,
    columnNameList    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
)
AS
    indexName       VARCHAR2(30);
    lastcomma           INTEGER;
    nextcomma           INTEGER;
    counter             INTEGER;
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DROP','INDEX',tableName || '.' || columnNameList);
        lastcomma := 1;
        nextcomma := 1;
        counter   := 1;
        LSQL := 'SELECT DISTINCT INDEX_NAME from USER_IND_COLUMNS UIC WHERE TABLE_NAME = ''' || upper(tableName) || '''';
        WHILE nextcomma > 0 LOOP
            nextcomma := INSTR(columnNameList, ',', lastcomma,1);
            LSQL := LSQL || ' AND (SELECT column_name FROM user_ind_columns WHERE table_name = ''' || upper(tableName) || ''' and index_name =  UIC.INDEX_NAME AND column_position = ' || counter || ') = ''' || upper(SUBSTR(columnNameList, lastcomma, nextcomma - lastcomma)) || '''';
            lastcomma := nextcomma + 1;
            counter := counter + 1;
        END LOOP;
        LSQL := rtrim (LSQL, '''') || ' ''' ||upper(substr (columnNameList, instr(columnNameList, ',', -1,1) + 1)) || '''';
        EXECUTE IMMEDIATE LSQL into indexName;
        LSQL := 'DROP INDEX ' || indexName;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'INDEX ' || indexName || ' on column list ' || columnNameList || ' dropped.');
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        null;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'INDEX on column list ' || columnNameList || ' does not exist.');
    WHEN OTHERS THEN
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' could not drop index from ' || tableName || '.' || columnNameList || '. Index Name?: ' || indexName);
        HANDLE_ERROR(bailOnFail, dropIndexFailureLevel, SQLERRM);
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_INDEX_FROM_COLUMN
-- DESCRIPTION    :  drops index(S) having referenced column 
-- POST CONDITIONS:  SUCCESS  : index dropped
--                   INFO     : Index did not exist
--                   WARNING  : index could not be dropped
--                   ERROR    : 
--                   FAILURE  : index could not be dropped and bailOnFail = Y, unknown status

-- NOTES          :  default is to continue on error; only one column can be passed in.
PROCEDURE DROP_INDEX_FROM_COLUMN (
    tableName         IN    VARCHAR2,
    columnName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
)
AS
    indexList varchar2(256);
    v_scd_uid integer;
    CURSOR DROP_INDEX_CUR is  SELECT DISTINCT 
        INDEX_NAME from USER_IND_COLUMNS UIC 
        WHERE TABLE_NAME =  upper(tableName)  and column_name = upper(columnName);
    BEGIN
        v_scd_uid := STATUS('S','DROP','INDEX',tableName || '.' || columnName);
        indexList := '';
        FOR DROP_INDEX_ROW in DROP_INDEX_CUR LOOP
            DROP_INDEX(DROP_INDEX_ROW.INDEX_NAME);
            indexList := indexList || ' ' || DROP_INDEX_ROW.INDEX_NAME;
        END LOOP;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'INDEX(s) ' || indexList || ' on column list ' || columnName || ' dropped.');
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        null;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'INDEX on column list ' || columnName || ' does not exist.');
    WHEN OTHERS THEN
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' could not drop index from ' || tableName || '.' || columnName || '. Index Name?: ' || indexList);
        HANDLE_ERROR(bailOnFail, dropIndexFailureLevel, SQLERRM);
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_CONSTRAINT_FROM_COLUMN
-- DESCRIPTION    :  drops constraint(S) having referenced column 
-- POST CONDITIONS:  SUCCESS  : constraint dropped
--                   INFO     : constraint did not exist
--                   WARNING  : constraint could not be dropped
--                   ERROR    : 
--                   FAILURE  : constraint could not be dropped and bailOnFail = Y, unknown status

-- NOTES          :  default is to continue on error; only one column can be passed in.
PROCEDURE DROP_CONSTRAINT_FROM_COLUMN (
    tableName     IN    VARCHAR2,
    columnName    IN    VARCHAR2,
    bailOnFail    IN    VARCHAR2 default 'N'
)
AS
    CONSTRAINTS_COUNT integer;
    v_scd_uid integer;
    
    BEGIN
        v_scd_uid := STATUS('S','DROP','CONST',tableName || '.' || columnName);
        SELECT DISTINCT count(*) INTO CONSTRAINTS_COUNT from USER_CONS_COLUMNS WHERE TABLE_NAME = upper(tableName) and column_name = upper(columnName);
        IF CONSTRAINTS_COUNT <> 0 THEN
            DROP_CONSTRAINT_FROM_TYPE(tableName,columnName, 'C');
            DROP_CONSTRAINT_FROM_TYPE(tableName,columnName, 'R');
            DROP_CONSTRAINT_FROM_TYPE(tableName,columnName, 'U');
            DROP_CONSTRAINT_FROM_TYPE(tableName,columnName, 'P');
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'CONSTRAINT(s) ' || constList || ' on column list ' || columnName || ' dropped.');
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'CONSTRAINT(s) on column list ' || columnName || ' does not exist.');
        end if;
    EXCEPTION
    -- WHEN NO_DATA_FOUND THEN
        -- null;
        -- v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'CONSTRAINT(s) on column list ' || columnName || ' does not exist.');
    WHEN OTHERS THEN
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' could not drop CONSTRAINT from ' || tableName || '.' || columnName || '. CONSTRAINT Name?: ' || constList);
        HANDLE_ERROR(bailOnFail, dropConstraintFailureLevel, SQLERRM);
    END;
    
PROCEDURE DROP_CONSTRAINT_FROM_TYPE (
    tableName     IN    VARCHAR2,
    columnName    IN    VARCHAR2,
    constraintType    IN VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
)
AS
    -- constList varchar2(256);
    v_scd_uid integer;
    CURSOR DROP_CONS_CUR is  SELECT DISTINCT 
        UCC.CONSTRAINT_NAME, UC.CONSTRAINT_TYPE from USER_CONS_COLUMNS UCC, USER_CONSTRAINTS UC
        WHERE UCC.TABLE_NAME =  upper(tableName)  and UCC.column_name = upper(columnName)
        and UCC.CONSTRAINT_NAME = UC.CONSTRAINT_NAME and UC.CONSTRAINT_TYPE = upper(constraintType);
    BEGIN
        constList := '';
        FOR DROP_CONS_ROW in DROP_CONS_CUR LOOP
            IF constraintType = 'P' OR constraintType = 'U' THEN
                DROP_FOREIGN_KEYS(DROP_CONS_ROW.CONSTRAINT_NAME);
            END IF;
            DROP_CONSTRAINT(tableName, DROP_CONS_ROW.CONSTRAINT_NAME);
            constList := constList || ' ' || DROP_CONS_ROW.CONSTRAINT_NAME;
        END LOOP;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        null;
    WHEN OTHERS THEN
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' could not drop constraint from ' || tableName || '.' || columnName || '. constraint Name?: ' || constList);
        HANDLE_ERROR(bailOnFail, dropConstraintFailureLevel, SQLERRM);
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_SEQUENCE
-- DESCRIPTION    :  drops sequence and row in seq table
-- POST CONDITIONS:  SUCCESS  : sequence dropped, and seq table cleaned
--                   INFO    : sequence didn't exist, seq table clean
--                   WARNING  : 
--                   ERROR   : could not drop sequence
--                   FAILURE  : unknown status

-- NOTES        :
PROCEDURE DROP_SEQUENCE (
    sequenceName      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
)

AS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DROP','SEQUENCE',sequenceName);
        SELECT count(sequence_name) into NUMBER_VAR FROM user_sequences WHERE sequence_name = upper(sequenceName);
        IF NUMBER_VAR = 0 THEN
            LSQL := 'delete FROM SEQ_SEQUENCE WHERE SEQ_NAME  = ''' || sequenceName || '''';
            EXECUTE IMMEDIATE LSQL;
            NUMBER_VAR := sql%ROWCOUNT;
            COMMIT;
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'No sequence named ' || sequenceName || ' exists.');
        ELSE
            LSQL := 'delete FROM SEQ_SEQUENCE WHERE SEQ_NAME  = ''' || sequenceName || '''';
            EXECUTE IMMEDIATE LSQL;
            NUMBER_VAR := sql%ROWCOUNT;
            LSQL := 'DROP SEQUENCE ' || sequenceName;
            EXECUTE IMMEDIATE LSQL;
          IF NUMBER_VAR > 0 THEN
              v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Dropped Sequence ' || sequenceName || ' and reference in SEQ_SEQUENCE table');
          ELSE
              v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Dropped Sequence ' || sequenceName || 'But there was no row in SEQ_SEQUENCE table.');
          END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            EX_CODE := SQLCODE;
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : could not drop ' || sequenceName, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, dropTabSequenceFailureLevel, SQLERRM);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_TABLE
-- DESCRIPTION    :  Drops a table from the schema
-- POST CONDITIONS:  SUCCESS  :  table dropped
--                   INFO     : table did not exists
--                   WARNING  : 
--                   ERROR    : table unable to be dropped 
--                   FAILURE  : table unable to be dropped, unknown status

-- NOTES          :   to override failure, set bailOnFail = N
PROCEDURE DROP_TABLE (
    tableName         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DROP','TABLE',tableName);
        LSQL := 'DROP TABLE ' || tableName || '';
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Dropped Table ' || tableName);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        IF EX_CODE = -942 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Table ' || tableName || ' does not exist.', ORAERRORNUMBER=> EX_CODE);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : Could not drop ' || tableName, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, dropTableFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE     :  DROP_TAB_SEQUENCE
-- DESCRIPTION   :  drops sequence and row in seq table
-- POST CONDITIONS:  SUCCESS  : sequence dropped
--                   INFO     : sequence didn't exist, seq table clean
--                   WARNING  : seq or seq table references existed, not both
--                   ERROR    : could not drop sequence
--                   FAILURE  : unknown status

-- NOTES        :
PROCEDURE DROP_TAB_SEQUENCE (
    tableName      IN    VARCHAR2,
    bailOnFail     IN    VARCHAR2   DEFAULT 'N'
)

AS
    seqcount integer;
    sequencecount integer;
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DROP','TAB_SEQUENCE',tableName);
        EXECUTE IMMEDIATE 'select count(SEQ_NAME) from SEQ_SEQUENCE where SEQ_NAME = ''' || substr(tableName,1,3) || '_SEQUENCE''' into seqcount;
        EXECUTE IMMEDIATE 'select count(sequence_name) from user_sequences where sequence_name = ''' || substr(tableName,1,3) || '_SEQUENCE''' into sequencecount;
        IF seqcount > 0 THEN
            LSQL := 'delete from SEQ_SEQUENCE where SEQ_NAME = ''' || substr(tableName,1,3) || '_SEQUENCE''';
            EXECUTE IMMEDIATE LSQL;
            COMMIT;
        END IF;
        IF sequencecount > 0 THEN
            LSQL := 'drop sequence ' || substr(tableName,1,3) || '_SEQUENCE';
            EXECUTE immediate LSQL;
        END IF;
        IF seqcount = 1 AND sequencecount = 1 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Dropped Sequence ' || substr(tableName,1,3) || '_SEQUENCE and references in table SEQ_SEQUENCE');
        ELSIF seqcount = 0 and sequencecount = 0 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'sequence ' || substr(tableName,1,3)  || '_SEQUENCE and references in table SEQ_SEQUENCE were already removed.');
        ELSIF seqcount = 0 and sequencecount = 1 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Sequence ' || substr(tableName,1,3)  || '_SEQUENCE dropped, but no references in table SEQ_SEQUENCE existed.');
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Sequence ' || substr(tableName,1,3)  || '_SEQUENCE did not exist, but references in table SEQ_SEQUENCE existed, and were removed.');
        END IF;
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>''|| SQLERRM || ' could not drop ' || substr(tableName,1,3) || '_SEQUENCE', ORAERRORNUMBER=> EX_CODE);
        HANDLE_ERROR(bailOnFail, dropTabSequenceFailureLevel, SQLERRM);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  DROP_TRIGGER
-- DESCRIPTION    :  drops named trigger
-- POST CONDITIONS:  SUCCESS  : trigger dropped
--                   INFO     : 
--                   WARNING  : Trigger did not exist
--                   ERROR    : Trigger could not be dropped and bailOnFail = N
--                   FAILURE  : unknown status, trigger could not be dropped

-- NOTES          :  to override failure, set bailOnFail = N
PROCEDURE DROP_TRIGGER (
    triggerName       IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','DROP','TRIGGER',triggerName);
        LSQL := 'DROP TRIGGER '|| triggerName;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Dropped Trigger '|| triggerName);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE :=SQLCODE;
        IF EX_CODE = -4080 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Trigger '|| triggerName || ' does not exist.', ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, LANDA_FAILURE_LEVEL_MAX, SQLERRM);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : could not drop ' || triggerName, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, dropTriggerFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  ENABLE_CONSTRAINT
-- DESCRIPTION    :  Enables a constraint on table
-- POST CONDITIONS:  SUCCESS  : constraint enabled
--                   INFO     : constraint already enabled
--                   WARNING  : No such constraint exists
--                   ERROR    : could not enable constraint
--                   FAILURE  : unknown status

-- NOTES          :  if no constraint was saved off, will get a landa default value, if available
PROCEDURE ENABLE_CONSTRAINT (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    indexTblspace    VARCHAR2(30);
    columnName       VARCHAR2(500);
    constraintType   VARCHAR2(1);
    sysDefaultTblspace     VARCHAR2(30);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','ENABLE','CONSTRAINT',tableName || '.' || constraintName);
        LSQL := 'select listagg(COLUMN_NAME, '','') within group (order by POSITION) from user_cons_columns where table_name = '''||upper(tableName)||''' and constraint_name = '''||upper(constraintName)||'''';
        EXECUTE IMMEDIATE LSQL into columnName;
        LSQL := 'select constraint_type from user_constraints where table_name = '''||upper(tableName)||''' and constraint_name = '''||upper(constraintName)||'''';
        EXECUTE IMMEDIATE LSQL into constraintType;
        LSQL := 'SELECT PROPERTY_VALUE FROM DATABASE_PROPERTIES WHERE PROPERTY_NAME = ''DEFAULT_PERMANENT_TABLESPACE''';
        EXECUTE IMMEDIATE LSQL into sysDefaultTblspace;
        IF constraintType = 'P' OR constraintType = 'U' THEN
            CONSTRAINT_INDEX(tableName,constraintName,(columnName),indexTblspace,constraintType);
        END IF;
        LSQL := 'ALTER TABLE ' || tableName || ' ENABLE CONSTRAINT ' || constraintName;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'constraint ' || constraintName || ' enabled.');
        DELETE_OBJECT_TBLSP(constraintName); -- clean up temp data.
    EXCEPTION
        WHEN OTHERS THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM);
            HANDLE_ERROR(bailOnFail, addConstraintFailureLevel, SQLERRM);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- FUNCTION       :  GET_PARENT_FK_COLS
-- DESCRIPTION    :  returns an array of constraint names referring to a tables PK
-- POST CONDITIONS:  SUCCESS  : names returned
--                   INFO     : no PRIMARY KEY on tablename
--                   WARNING  : 
--                   ERROR    : 
--                   FAILURE  : multi-key PK, unknown status

-- NOTES          :
FUNCTION GET_PARENT_FK_COLS (
    tableName         IN   VARCHAR2,
    bailOnFail        IN   VARCHAR2    default 'N'
)
    return              LANDA_VAR_ARRAY

IS
    primaryKeyName      VARCHAR2(30);
    i                   INTEGER;
    v_scd_uid integer;
    fkname LANDA_VAR_ARRAY := LANDA_VAR_ARRAY();
    cursor fkcur is
        SELECT A.column_name, A.table_name
        FROM user_cons_columns A, user_constraints B
        WHERE B.R_CONSTRAINT_NAME = primaryKeyName
            AND A.constraint_name = B.constraint_name
            AND (SELECT count(*) FROM user_cons_columns WHERE constraint_name = A.constraint_name) = 1
        order by A.table_name, A.column_name;
    BEGIN
        primaryKeyName := GET_PRIMARY_KEY_NAME(tableName);
        IF primaryKeyName is not null THEN
            SELECT count(*) into i FROM user_cons_columns WHERE constraint_name = primaryKeyName;
            IF i > 1 THEN
                raise_application_error (-20001, 'Cannot perform this function on mulitple column primary keys');
            END IF;
            i := 1;
            FOR fkrow in fkcur LOOP
                fkname.extEND;
                fkname(i) := fkrow.table_name;
                i := i + 1;
                fkname.extEND;
                fkname(i) := fkrow.column_name;
                i := i + 1;
            END loop;
            i:= 1;
            FOR j in fkname.first..fkname.last/2 loop
                i := i + 1;
                i := i + 1;
            END loop;
        ELSE
            dbms_output.put_line('INFO    : 0 : Table ' || tableName || ' has no primary key, no FK constraints.');
        END IF;
        return fkname;
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR   : ' || SQLERRM);
        raise_application_error (-20001, SQLERRM);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- FUNCTION       :  GET_PRIMARY_KEY_NAME
-- DESCRIPTION    :  Given a table name, returns the Primary key on the table
-- POST CONDITIONS:  SUCCESS  : primary key found and returned
--                   INFO     : 
--                   WARNING  : no primary key found on table
--                   ERROR    : 
--                   FAILURE  : unknown status

-- NOTES          :  All LANDA tables have primary keys.
FUNCTION GET_PRIMARY_KEY_NAME (
    tableName         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)
    return      VARCHAR2

IS
    pkName          VARCHAR2(30);
    v_scd_uid integer;
    BEGIN
        pkName := '';
        BEGIN
            EXECUTE IMMEDIATE 'SELECT CONSTRAINT_NAME FROM USER_CONSTRAINTS
            WHERE CONSTRAINT_TYPE = ''P'' AND TABLE_NAME = ''' || upper(tableName) || '''' INTO pkName;
        EXCEPTION
        WHEN OTHERS THEN
            EX_CODE := SQLCODE;
            IF EX_CODE = 100 THEN
                pkName := NULL;
            ELSE -- unknown error
                IF bailOnFail = 'Y' OR (GET_FAILURE_LEVEL() >= LANDA_FAILURE_LEVEL_CODE) THEN
                    raise_application_error (-20001, SQLERRM);
                END IF;
            END IF;
        END;
        return pkName;
    END;
    
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- -- PROCEDURE        :   INSERT_DATA

PROCEDURE INSERT_DATA (
    TABLENAME VARCHAR2,
    PK_COL VARCHAR2,
    PK_DATA VARCHAR2,
    OTHER_COLS VARCHAR2,
    OTHER_DATA  VARCHAR2,
    SYSTEM_YN VARCHAR2 default 'N',
    BAILONFAIL VARCHAR2 default 'N'
)
AS
SQLStatement CLOB;
numberVar    integer;
v_scd_uid    integer;
exText       varchar2(200);
    BEGIN
        v_scd_uid := STATUS(lscduid=>0, lSTATUS=>'S', laction=>'INSERT' , lobject=>'DATA',lname=>TABLENAME , ltext=>TABLENAME || '.' || PK_COL);
        numberVar := CHECK_DATA_EXISTENCE(TABLENAME,PK_COL,PK_DATA);
        IF numberVar = 0 THEN -- CASE A: all clear to do insert
            SQLStatement := 'INSERT INTO ' || TABLENAME || '(' ;
            SQLStatement := SQLStatement || CONCAT_STRINGS(',',PK_COL,OTHER_COLS); 
            SQLStatement := SQLStatement || ') values (';
            SQLStatement := SQLStatement  || CONCAT_STRINGS(',',PK_DATA,OTHER_DATA)  || ')';
            EXECUTE IMMEDIATE SQLStatement;
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lSTATUS=>'C', laction=>'INSERT' , lobject=>'DATA',lname=>TABLENAME , ltext=>'Inserted row with Primary Key ' || PK_DATA);
        ELSE -- CASE B: primary key already exists
                SQLStatement := MAKE_UPDATE_STATEMENT(TABLENAME,PK_COL,PK_DATA,OTHER_COLS,OTHER_DATA);
                EXECUTE IMMEDIATE SQLStatement;
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lSTATUS=>'C', laction=>'UPDATE' , lobject=>'DATA',lname=>TABLENAME , ltext=>'Value(s) ' || PK_DATA ||  ' already existed. Updated row values.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN -- CASE C: exception
            dbms_output.put_line('sql = ' || SQLStatement);
            EX_CODE := SQLCODE;
            exText := SQLERRM;
            LSQL := SQLStatement;
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lSTATUS=>'E', laction=>'INSERT', lobject=>'DATA', lname=>TABLENAME , ltext=>exText || ' Primary Key: ' || PK_DATA, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, insertValsFailureLevel, exText);
    END;
PROCEDURE INSERT_DATA_UNIQUE (
    TABLENAME VARCHAR2,
    PK_COL VARCHAR2,
    PK_DATA VARCHAR2,
    UNIQUE_COL VARCHAR2,
    UNIQUE_DATA VARCHAR2,
    OTHER_COLS VARCHAR2,
    OTHER_DATA  VARCHAR2,
    SYSTEM_YN VARCHAR2 default 'N',
    BAILONFAIL VARCHAR2 default 'N'
)
AS
SQLStatement CLOB;
counteruq    integer;
numberVar    integer;
v_scd_uid    integer;
exText       varchar2(200);
    BEGIN
        IF UNIQUE_COL is NULL OR UNIQUE_COL = '' THEN
            INSERT_DATA(TABLENAME,PK_COL,PK_DATA,OTHER_COLS,OTHER_DATA,SYSTEM_YN,BAILONFAIL);
        ELSE 
            BEGIN
                v_scd_uid := STATUS(lscduid=>0, lstatus=>'S', laction=>'INSERT' , lobject=>'DATA UNIQUE',lname=>TABLENAME , ltext=>TABLENAME || '.' || PK_COL);
                numberVar := CHECK_DATA_EXISTENCE(TABLENAME,PK_COL,PK_DATA);
                IF numberVar = 0 THEN -- primary key values do not exist
                    numberVar := CHECK_DATA_EXISTENCE(TABLENAME,UNIQUE_COL,UNIQUE_DATA);
                    IF numberVar = 0 THEN -- CASE A:  all clear, do insert
                        SQLStatement := 'INSERT INTO ' || TABLENAME || '(' ;
                        SQLStatement := SQLStatement || CONCAT_STRINGS(',',PK_COL,UNIQUE_COL,OTHER_COLS); 
                        SQLStatement := SQLStatement || ') values (';
                        SQLStatement := SQLStatement  || CONCAT_STRINGS(',',PK_DATA,UNIQUE_DATA,OTHER_DATA)  || ')';
                        EXECUTE IMMEDIATE SQLStatement;
                        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', laction=>'INSERT' , lobject=>'DATA UNIQUE',lname=>TABLENAME , ltext=>'Inserted row with Primary Key ' || PK_DATA);
                    ELSE -- CASE B: unique values to be inserted already exist
                        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', laction=>'INSERT' , lobject=>'DATA UNIQUE',lname=>TABLENAME , ltext=>'Unique Key values ' || UNIQUE_DATA || ' already exist, cannot insert again with Primary Key value(s) ' || PK_DATA, ORAERRORNUMBER=> '-1');
                        HANDLE_ERROR(bailOnFail, insertValsFailureLevel, 'UNIQUE CONSTRAINT VIOLATION');
                    END IF;
                ELSE -- primary key already exists - update if possible
                    numberVar := CHECK_DATA_EXISTENCE(TABLENAME,UNIQUE_COL,UNIQUE_DATA);
                    IF numberVar > 0 THEN -- the unique key also exists - ensure it is tied to correct primary key
                        numberVar := CHECK_DATA_EXISTENCE(TABLENAME, CONCAT_STRINGS(',',PK_COL,UNIQUE_COL),CONCAT_STRINGS(',',PK_DATA , UNIQUE_DATA));
                        IF numberVar > 0 THEN -- CASE D: the unique key is on the correct row -- update values 
                            SQLStatement := MAKE_UPDATE_STATEMENT(TABLENAME,PK_COL,PK_DATA,OTHER_COLS,OTHER_DATA);
                            EXECUTE IMMEDIATE SQLStatement;
                            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', laction=>'UPDATE' , lobject=>'DATA UNIQUE',lname=>TABLENAME , ltext=>'Value(s) ' || PK_DATA || ',' ||UNIQUE_DATA || ' already exist. Updated other row values.' );
                        ELSE  -- CASE E: the unique key is tied to another pk row 
                            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', laction=>'UPDATE' , lobject=>'DATA UNIQUE',lname=>TABLENAME , ltext=>'Primary Key value(s) ' || PK_DATA ||  ' already exist but Unique Key values ' || UNIQUE_DATA || ' are being used by another row', ORAERRORNUMBER=> '-1');
                            HANDLE_ERROR(bailOnFail, updateValueFailureLevel, 'UNIQUE KEY CONSTRAINT VIOLATION');
                        END IF;
                    ELSE -- CASE F: pk exists, has diffent unique values, but no collision
                        SQLStatement := MAKE_UPDATE_STATEMENT(TABLENAME,PK_COL,PK_DATA,CONCAT_STRINGS(',',UNIQUE_COL,OTHER_COLS),CONCAT_STRINGS(L_DATA_SEPARATOR,UNIQUE_DATA,OTHER_DATA));
                        EXECUTE IMMEDIATE SQLStatement;
                        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', laction=>'UPDATE' , lobject=>'DATA UNIQUE',lname=>TABLENAME , ltext=>'Value(s) ' || PK_DATA ||  ' already exist but did not have correct unique keys. Updated unique keys and other row values.' );
                    END IF;
                END IF;
            EXCEPTION
            WHEN OTHERS THEN -- CASE H: exception
                dbms_output.put_line('sql = ' || SQLStatement);
                EX_CODE := SQLCODE;
                exText := SQLERRM;
                LSQL := SQLStatement;
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'E', laction=>'INSERT', lobject=>'DATA UNIQUE', lname=>TABLENAME , ltext=>exText || ' Failed to insert values Primary Key: ' || PK_DATA || ' Unique Key?: ' || UNIQUE_DATA, ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, insertValsFailureLevel, exText);
            END;
        END IF;
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  INSERT_VALS
-- DESCRIPTION    :  inserts listed values into listed columns
-- POST CONDITIONS:  SUCCESS  : value(s) inserted to table
--                   INFO     : Value(s) already exist
--                   WARNING  : unique value(s) already exist, possible delta
--                   ERROR    : Unable to insert value
--                   FAILURE  : unknown status,Unable to insert value and override not set

-- NOTES          :  To skip failure, set bailOnFail = N
PROCEDURE INSERT_VALS (
    tableName         IN  VARCHAR2,
    columnList        IN  VARCHAR2,
    valueList         IN  VARCHAR2,
    bailOnFail        IN  VARCHAR2    DEFAULT 'N'
)

AS
    exText      varchar2(200);
    constName   varchar2(50);
    sqlRowCount number;
    columnListClause varchar2(2000);
    valueListClause varchar2(2000);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','INSERT','VALUES',tableName, 'INSERT into ' || tableName);
        columnListClause := ENSURE_PARENS(columnList);
        valueListClause := ENSURE_PARENS(valueList);
        LSQL := 'INSERT into ' || tableName || ' ' || columnListClause || ' VALUES ' || valueListClause;
        EXECUTE IMMEDIATE LSQL;
        sqlRowCount := SQL%ROWCOUNT;
        COMMIT;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Number of rows inserted = ' || sqlRowCount);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        exText := SQLERRM;
        -- unique constraint violation is a -1 which encompasses primary key AND unique constraint violations
        IF EX_CODE = -1 THEN
            -- now check IF it's primary key or just a unique constraint
            IF instr(exText, 'PRIMARY_KEY') > 0 OR instr(exText, 'UNIQUE') > 0 THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>'' || exText, ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, updateValueFailureLevel, exText);
            ELSE
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || exText, ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, updateValueFailureLevel, exText);
            END IF;
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || exText, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, insertValsFailureLevel, exText);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
/*
   *  PROCEDURE:      LANDA_ADD_COLUMN
   *  DESCRIPTION:    Adds a column to the indicated table.
   *  NOTE(S):        columnLength can be either  with parentheses or without.
   *                  For example either "(16)" or "16" can be used.
   */
PROCEDURE LANDA_ADD_COLUMN (
    tableName           VARCHAR2,
    columnName          VARCHAR2,
    columnDataType      VARCHAR2,
    columnLength        VARCHAR2    default NULL,
    defaultValue        VARCHAR2    default NULL,
    constraintClause    VARCHAR2    default NULL
)

IS
    BEGIN
        ADD_COLUMN (tableName,  columnName,  columnDataType,  columnLength, defaultValue, constraintClause);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_ADD_FOREIGN_KEY
-- Adds named fk constraint onto table.column on table.column
-- SUCCESS: constraint added
-- WARN: constraint already exists
-- FAIL: constraint could not be added and does not exist
-- EXCEPTION: only on unknown error
PROCEDURE LANDA_ADD_FOREIGN_KEY (
    childTableName      VARCHAR2,
    constraintName      VARCHAR2,
    childColumnName     VARCHAR2,
    parentTableName     VARCHAR2,
    parentColumnName    VARCHAR2
)

IS
    BEGIN
        ADD_FOREIGN_KEY (childTableName,  constraintName,  childColumnName,  parentTableName, parentColumnName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_ADD_INDEX_1C
-- adds named index to one named column on table
-- NOTE for two-column indexes, user LANDA_ADD_INDEX_2C
-- TODO - update to handle variable volume indexes
-- SUCCESS: index added
-- WARN: index exists as expected
-- FAIL: index could not be created, name or column definition already in use
-- EXCEPTION: unknown errors
PROCEDURE LANDA_ADD_INDEX_1C (
    tableName   VARCHAR2,
    columnName  VARCHAR2,
    indexName   VARCHAR2,
    tbSpace     VARCHAR2,
    initamt     INTEGER     DEFAULT 8,
    nextamt     INTEGER     DEFAULT 120
)

IS
    BEGIN
        ADD_INDEX (indexName, tableName, columnName, tbSpace, initamt, nextamt);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_ADD_INDEX_2C
-- Adds named index onto two columns of table
-- Success - this script returns without error for all but unknown errors
-- Failure - Unknown errors.
PROCEDURE LANDA_ADD_INDEX_2C (
    indexName           VARCHAR2,
    tableName           VARCHAR2,
    columnName1         VARCHAR2,
    columnName2         VARCHAR2,
    tbSpace             VARCHAR2,
    initamt             INTEGER         DEFAULT 8,
    nextamt             INTEGER         DEFAULT 120
)

IS
    BEGIN
        ADD_INDEX (indexName, tableName, columnName1 || ',' || columnName2, tbSpace, initamt, nextamt);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
/*
   *  PROCEDURE:      LANDA_ADD_NOT_NULL
   *  DESCRIPTION:    Adds a not null constraint on the indicated column.
   *  NOTE(S):        
   */
PROCEDURE LANDA_ADD_NOT_NULL (
    tableName       VARCHAR2,
    columnName      VARCHAR2,
    constraintName  VARCHAR2
)

IS
    BEGIN
        ADD_NOT_NULL (tableName, columnName, constraintName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_ADD_PRIMARY_KEY
-- adds named primary key to column (s)  on table
-- Success - primary key added, or if it exists already
-- Failure - Table does not have primary key or unknown status
PROCEDURE LANDA_ADD_PRIMARY_KEY (
    tableName           VARCHAR2,
    constraintName      VARCHAR2,
    columnNames         VARCHAR2,
    indexTableSpace     VARCHAR2
)

IS
    BEGIN
        ADD_PRIMARY_KEY (tableName, constraintName, columnNames, indexTableSpace);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_ADD_UNIQUE (
    tableName       VARCHAR2,
    constraintName  VARCHAR2,
    columnName      VARCHAR2,
    tableSpace      VARCHAR2
)

IS
    BEGIN
        ADD_UNIQUE (tableName, constraintName, columnName, tableSpace);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- Landa create preference
-- superceded by Create preference.
-- since already use, directing to new proc instead
PROCEDURE LANDA_CREATE_PREFERENCE (
    prefName       VARCHAR2,
    objName        VARCHAR2
)

IS
    objCount        number;
    BEGIN
        CREATE_PREFERENCE (prefName, objName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_CREATE_SEQUENCE (
    sequenceName    VARCHAR2,
    startValue      NUMBER      default 1,
    incrementValue  NUMBER      default 1,
    maximumValue    NUMBER      default 9999999999,
    cycleParam      VARCHAR2    default 'NOCYCLE',
    cacheParam      VARCHAR2    default 'NOCACHE'
)

IS
    BEGIN
        CREATE_SEQUENCE (sequenceName, startValue, incrementValue, maximumValue, cycleParam, cacheParam);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_CREATE_TABLE
-- creates named table in named tablespace with only one named column with definition given
-- NOTE: tablespace must exist - it is not checked.
-- SUCCESS: table created
-- WARN: table already exists
-- FAIL: table could not be created and does not exist
-- EXCEPTION: none
PROCEDURE LANDA_CREATE_TABLE (
    tableName         VARCHAR2,
    tablespaceName    VARCHAR2,
    columnName        VARCHAR2,
    columnDataType    VARCHAR2,
    columnLength      VARCHAR2    default '',
    defaultClause     VARCHAR2    default ''
)

IS
    BEGIN
        CREATE_TABLE (tableName, tablespaceName, columnName, columnDataType, columnLength, defaultClause);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_DELETE_FK_CHILDREN
-- removes child records, or sets the fk column value to null
-- Success - child record removed, or fk column set to null
-- Failure - any other error
PROCEDURE LANDA_DELETE_FK_CHILDREN (
    tableName       IN  VARCHAR2,
    columnName      IN  VARCHAR2,
    colVal          IN  VARCHAR2
)

IS
    BEGIN
        DELETE_FK_CHILDREN (tableName, columnName, colVal);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
/*
   *  PROCEDURE:      LANDA_DELETE_VALUE
   *  DESCRIPTION:    Performs a delete operation on the indicated data.
   *  NOTE(S):        
   */
PROCEDURE LANDA_DELETE_VALUE (
    tableName       VARCHAR2,
    columnName      VARCHAR2,
    value1          VARCHAR2
)

IS
    BEGIN
        DELETE_VALUE (tableName, columnName, value1);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_DISABLE_COL_CONSTRAINTS
-- disables all constraints from a particular column
-- Success - all constraints disable that exist
-- Failure - to do
PROCEDURE LANDA_DISABLE_COL_CONSTRAINTS (
    tableName       VARCHAR2,
    columnName      VARCHAR2
)

IS
    BEGIN
        DISABLE_COL_CONSTRAINTS (tableName, columnName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_DISABLE_CONSTRAINT
-- disables a named constraint on a particular table.
-- success - constraint disabled or doesn't exist
-- failure - constraint not able to be disabled
PROCEDURE LANDA_DISABLE_CONSTRAINT (
    tableName       VARCHAR2,
    constraintName  VARCHAR2
)

IS
    BEGIN
        DISABLE_CONSTRAINT (tableName, constraintName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_DISABLE_FK_CONSTRAINTS
-- Given a primary key name, disable all FK's constrained to that primary key
-- Success - constraints are disabled (or don't exist)
-- Failure  - if constraint cannot be disabled.
PROCEDURE LANDA_DISABLE_FK_CONSTRAINTS (
    primaryKeyName  IN VARCHAR2
)

IS
    BEGIN
        DISABLE_FK_CONSTRAINTS (primaryKeyName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
/*
   *  PROCEDURE:      LANDA_DROP_COLUMN
   *  DESCRIPTION:    Sets a column to unused.
   *  NOTE(S):        
   */
PROCEDURE LANDA_DROP_COLUMN (
    tableName   VARCHAR2,
    columnName  VARCHAR2
)

IS
    BEGIN
        DROP_COLUMN (tableName, columnName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_DROP_CONSTRAINT (
    tableName       IN  VARCHAR2,
    constraintName  IN  VARCHAR2
)

IS
    BEGIN
        DROP_CONSTRAINT (tableName, constraintName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_DROP_FOREIGN_KEYS (
    primaryKeyName  IN VARCHAR2
)

IS
    BEGIN
        DROP_FOREIGN_KEYS (primaryKeyName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_DROP_INDEX (
    indexName       VARCHAR2
)

IS
    BEGIN
        DROP_INDEX (indexName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_DROP_SEQUENCE (
    tableName   VARCHAR2
)

IS
    BEGIN
        DROP_TAB_SEQUENCE (tableName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_DROP_TABLE (
    tableName   IN      VARCHAR2
)

IS
    BEGIN
        DROP_TABLE (tableName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_DROP_TRIGGERS (
    triggerName         VARCHAR2
)

IS
    BEGIN
        DROP_TRIGGER (triggerName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_ENABLE_CONSTRAINT (
    tableName       VARCHAR2,
    constraintName  VARCHAR2
)

IS
    BEGIN
        ENABLE_CONSTRAINT (tableName, constraintName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

FUNCTION LANDA_GET_PARENT_FK_COLS (
    tableName   IN      VARCHAR2
)
    return              LANDA_VAR_ARRAY

IS
    BEGIN
        return GET_PARENT_FK_COLS(tableName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

FUNCTION LANDA_GET_PRIMARY_KEY_NAME (
    tableName   IN      VARCHAR2
)
    return      VARCHAR2

IS
    pkName          VARCHAR2(30);
    BEGIN
        pkName := GET_PRIMARY_KEY_NAME(tableName);
        return pkName;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE RUN_DML (
    sqlStatement      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

AS
    exText      varchar2(200);
    constName   varchar2 (50);
    sqlRowCount number;
    v_scd_uid integer;
    BEGIN
        exText := upper(substr(trim(sqlStatement), 1, 6));
        LSQL := sqlStatement;
        v_scd_uid := STATUS('S', exText,'VALUE', 'DML: ' || replace(substr(sqlStatement, 1, 64),''''));
        EXECUTE IMMEDIATE sqlStatement;
        sqlRowCount := SQL%ROWCOUNT;
        COMMIT;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Number of rows affected = ' || sqlRowCount);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        exText := SQLERRM;
        IF EX_CODE = -1 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>'' || exText, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, updateValueFailureLevel, exText);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || exText, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, insertValsFailureLevel, exText);
        END IF;
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE RUN_DML_S (
    sqlStatement      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

AS
    exText      varchar2(200);
    constName   varchar2 (50);
    sqlRowCount number;
    v_scd_uid integer;
    BEGIN
        exText := upper(substr(trim(sqlStatement), 1, 6));
        LSQL := sqlStatement;
        EXECUTE IMMEDIATE sqlStatement;
        sqlRowCount := SQL%ROWCOUNT;
        COMMIT;
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        exText := SQLERRM;
        IF EX_CODE = -1 THEN
            IF LCURRENTSTATUS != 'F' THEN
                LCURRENTSTATUS := 'W';
            END IF;
            HANDLE_ERROR(bailOnFail, updateValueFailureLevel, exText);
        ELSE
            LCURRENTSTATUS := 'F';
            HANDLE_ERROR(bailOnFail, insertValsFailureLevel, exText);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
/*
   *  PROCEDURE:      LANDA_INSERT
   *  DESCRIPTION:    Performs an insert on the provided values.
   *  NOTE(S):        
   */
-- PROCEDURE      :  LANDA_INSERT
-- DESCRIPTION    :  executes insert statement
-- POST CONDITIONS:  SUCCESS  : rows inserted
--                   INFO     : 
--                   WARNING  : PK violation
--                   ERROR    : data not inserted
--                   FAILURE  : unknown status

-- NOTES          :
PROCEDURE LANDA_INSERT (
    sqlStatement      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

AS
    BEGIN
        RUN_DML(sqlStatement, bailOnFail);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
/*
   *  PROCEDURE:      LANDA_INSERT_VALS
   *  DESCRIPTION:    Performs an insert on the provided values.
   *  NOTE(S):        
   */
PROCEDURE LANDA_INSERT_VALS (
    tableName   IN  varchar2,
    columnList  IN  varchar2,
    valueList   IN  varchar2
)

IS
    BEGIN
        INSERT_VALS (tableName, columnList, valueList);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_MODIFY_COLUMN (
    tableName            VARCHAR2,
    columnName           VARCHAR2,
    columnDataType       VARCHAR2,
    columnLength         VARCHAR2    default NULL,
    defaultClause        VARCHAR2    default NULL,
    additionalClause     VARCHAR2    default NULL
)

IS
    BEGIN
        MODIFY_COLUMN (tableName, columnName, columnDataType, columnLength, defaultClause, additionalClause);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_RENAME_COLUMN (
    tableName       VARCHAR2,
    oldColumnName   VARCHAR2,
    newColumnName   VARCHAR2
)

IS
    BEGIN
        RENAME_COLUMN (tableName, oldColumnName, newColumnName);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_RENAME_CONSTRAINT (
    tableName           VARCHAR2,
    constraintName      VARCHAR2,
    constraintName2     VARCHAR2
)

IS
    BEGIN
        RENAME_CONSTRAINT (tableName, constraintName, constraintName2);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_RENAME_INDEX (
    indexName       VARCHAR2,
    indexNew        VARCHAR2
)

IS
    BEGIN
        RENAME_INDEX (indexName, indexNew);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_RENAME_TABLE (
    tableName       VARCHAR2,
    tableName2      VARCHAR2
)

IS
    BEGIN
        RENAME_TABLE (tableName, tableName2);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LANDA_SET_ATTRIBUTE (
    prefName        VARCHAR2,
    attribName      VARCHAR2,
    attribVal       VARCHAR2
)

IS
    BEGIN
        SET_ATTRIBUTE (prefName, attribName, attribVal);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- LANDA_TRIG_RECORD
-- creates the record version trigger on the %_REcoRD_VERSION column for optimistic record locking
-- Any table with that column should have a trigger
-- SUCCESS: trigger created or replaced
-- WARN: none
-- FAIL: could not add trigger
-- Exceptions: none
PROCEDURE LANDA_TRIG_RECORD(
    triggerName         VARCHAR2,
    tableName           VARCHAR2,
    columnName          VARCHAR2
)

IS
    BEGIN
        CREATE_RECORD_VERSION_TRIGGER (tableName, 'N');
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
/*
   *  PROCEDURE:      LANDA_UPDATE_VALUE
   *  DESCRIPTION:    Performs an update statement.
   *  NOTE(S):        
   */
PROCEDURE LANDA_UPDATE_VALUE (
    tableName   VARCHAR2,
    columnName  VARCHAR2,
    value1      VARCHAR2,
    columnName2 VARCHAR2,
    value2      VARCHAR2
)

IS
    BEGIN
        UPDATE_VALUE (tableName, columnName, value1, columnName2, value2);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE MODIFY_COLUMN (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    columnDataType    IN    VARCHAR2,
    columnLength      IN    VARCHAR2    default NULL,
    defaultClause     IN    VARCHAR2    default NULL,
    additionalClause  IN    VARCHAR2    default NULL,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    dataDefaultClause    VARCHAR2(64);
    columnDataTypeClause VARCHAR2(32);
    columnLengthClause   VARCHAR2(64);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','MODIFY','COLUMN',tableName || '.' || columnName, columnDataType || ' ' || columnLength || ' ' || defaultClause || ' ' || additionalClause);
        -- ensure default clause has  DEFAULT
        --columnDataTypeClause := columnDataType;
        SELECT data_type into columnDataTypeClause from USER_TAB_COLUMNS where column_name = columnName and table_name = tableName;
        IF columnDataTypeClause in ('CLOB', 'BLOB', 'LOB', 'LONG RAW') THEN
            IF columnDataType = columnDataTypeClause THEN
                v_scd_uid := STATUS('C','MODIFY','COLUMN',tableName || '.' || columnName, ' is already of datatype: ' || columnDataTypeClause || ' ' || columnLength || ' ' || defaultClause || ' ' || additionalClause);
            ELSE
                v_scd_uid := STATUS('F','MODIFY','COLUMN',tableName || '.' || columnName, 'Cannot modify this datatype: ' || columnDataTypeClause || ' ' || columnLength || ' ' || defaultClause || ' ' || additionalClause);
                HANDLE_ERROR(bailOnFail, modifyColumnFailureLevel, SQLERRM);
            END IF;
        ELSE
            IF defaultClause is not null THEN
                dataDefaultClause := defaultClause;
                IF instr(UPPER(dataDefaultClause), 'NULL') = 0 THEN
                    dataDefaultClause := ENSURE_QUOTES(dataDefaultClause);
                END IF;
                IF instr(dataDefaultClause, 'DEFAULT') = 0 THEN
                    dataDefaultClause := ' DEFAULT ' || dataDefaultClause;
                END IF;
            END IF;
            -- ensure data length is parenthesized
            IF columnLength is not null THEN
                columnLengthClause := ENSURE_PARENS(columnLength);
            END IF;
            BEGIN
                LSQL := 'alter table ' || tableName || '  Modify ' || '(' || columnName ||' '|| columnDataType || columnLengthClause || ' ' || dataDefaultClause || ' ' || additionalClause || ')';
                EXECUTE IMMEDIATE LSQL;
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'column ' || tableName || '.' || columnName || ' correctly modified to: datatype ' || columnDataType || ', precision ' || columnLengthClause || ' ' || dataDefaultClause || ' ' || additionalClause);
            END;
        END IF;
    EXCEPTION   
        WHEN OTHERS THEN
            EX_CODE :=SQLCODE;
            IF EX_CODE = -1440 THEN  -- column to be modified must be empty to decrease precision or scale
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>'' || SQLERRM || ' Cannot decrease size of ' || tableName || '.' || columnName, ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, modifyColumnFailureLevel, SQLERRM);
            ELSIF EX_CODE = -904 THEN -- column does not exist
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' Column ' || columnName || ' does not exist.', ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, addColumnFailureLevel, SQLERRM);
            ELSIF EX_CODE = 100 THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'Table or column does not exist : ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, modifyColumnFailureLevel, SQLERRM);
            ELSE
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM);
                HANDLE_ERROR(bailOnFail, modifyColumnFailureLevel, SQLERRM);
            END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
/*
   *  PROCEDURE:      MOVE_IND_TBLSPC
   *  DESCRIPTION:    Moves the indicated index to another tablespace.
   *  NOTE(S):        
   */
PROCEDURE MOVE_IND_TBLSPC (
    indexName        IN    VARCHAR2,
    tblspc           IN    VARCHAR2,
    bailOnFail       IN    VARCHAR2    DEFAULT 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','MOVE','INDEX',indexName, 'TO TABLESPACE' || ' ' || tblspc);
        LSQL :='ALTER INDEX '|| indexName ||' REBUILD TABLESPACE ' || tblspc;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Index ' || indexName || ' moved to ' || tblspc);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE :=SQLCODE;
        IF EX_CODE = -959 THEN -- tablespace does not exist
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>'' || SQLERRM || ' Cannot move ' || indexName || ' to ' || tblspc || '.', ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, moveIndTblspcFailureLevel, SQLERRM);
        ELSE -- some other error?
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'W', ltext=>'' || SQLERRM || ' : could not change index ' || indexName || ' to ' || tblspc, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, moveIndTblspcFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
/*
   *  PROCEDURE:      LANDA_RENAME_COLUMN
   *  DESCRIPTION:    Renames the indicated column on the indicated table.
   *  NOTE(S):        
   */
PROCEDURE RENAME_COLUMN (
    tableName         IN    VARCHAR2,
    oldColumnName     IN    VARCHAR2,
    newColumnName     IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    oldCount NUMBER;
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','RENAME','COLUMN',tableName|| '.' || newColumnName, 'WAS ' || ' ' || oldColumnName);
        -- EXECUTE the statement
        LSQL := 'ALTER TABLE '|| tableName ||' RENAME COLUMN ' || oldColumnName || ' TO ' || newColumnName;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'column renamed from ' || oldColumnName || ' to ' || newColumnName);

    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE;
        IF EX_CODE = -957 THEN
            -- Duplicate column name
            BEGIN
                SELECT count(*) into oldCount FROM user_tab_columns WHERE table_name = tableName AND column_name = oldColumnName;
                IF oldCount = 0 THEN
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Column has already been renamed.', ORAERRORNUMBER=> EX_CODE);
                ELSE
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' Cannot rename ' || oldColumnName || ' to ' || newColumnName || ', as '  || newColumnName || ' already exists.', ORAERRORNUMBER=> EX_CODE);
                    HANDLE_ERROR(bailOnFail, renameColumnFailureLevel, SQLERRM);
                END IF;
            END;
        ELSIF EX_CODE = -904 THEN
            -- Column to be renamed does not exist
            SELECT count(*) into oldCount FROM user_tab_columns WHERE table_name = tableName AND column_name = newColumnName;
            IF oldCount > 0 THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Column has already been renamed.', ORAERRORNUMBER=> EX_CODE);
            ELSE
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM ||' : Failed to rename column ' || oldColumnName || ' to ' || newColumnName || ', as '  || oldColumnName || ' does not exist.', ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, addColumnFailureLevel, SQLERRM);
            END IF;
        ELSE
            -- Unknown error
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : Failed to rename column ' || oldColumnName || '.', ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, renameColumnFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE RENAME_CONSTRAINT (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    constraintNameNew IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','RENAME','CONSTRAINT',tableName|| '.' || constraintName, ' TO ' || ' ' || constraintNameNew);
        LSQL := 'ALTER TABLE '|| tableName ||' RENAME CONSTRAINT  '|| constraintName || ' TO ' || constraintNameNew;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'constraint ' || constraintName || ' renamed to ' || constraintNameNew);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE :=SQLCODE;
        IF EX_CODE = -2264 THEN  -- name already used by an existing constraint
            LSQL := 'SELECT count(*) FROM USER_CONSTRAINTS where constraint_name = ''' || constraintName || ''' and TABLE_NAME = ''' || tableName || '''';
            EXECUTE IMMEDIATE LSQL    into NUMBER_VAR ;
            IF NUMBER_VAR = 0 THEN
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'' || SQLERRM || ' : The constraint name ' || constraintNameNew || ' is already being used, and ' || constraintName ||' no longer exists.', ORAERRORNUMBER=> EX_CODE);
            ELSE
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : Cannot rename ' || constraintName || '. The constraint name ' || constraintNameNew || ' is already being used.', ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, renameConstraintFailureLevel, SQLERRM);
            END IF;
        ELSIF EX_CODE = -23292 THEN -- constraint does not exist
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : could not change ' || constraintName || ' to ' || constraintNameNew, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addConstraintFailureLevel, SQLERRM);
        ELSIF EX_CODE = -2250 THEN -- Renaming constarint with oracle keyword
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : could not change ' || constraintName || ' to ' || constraintNameNew, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addConstraintFailureLevel, SQLERRM);	
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : could not change ' || constraintName || ' to ' || constraintNameNew, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addConstraintFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE RENAME_INDEX (
    indexName        IN    VARCHAR2,
    indexNew         IN    VARCHAR2,
    bailOnFail       IN    VARCHAR2    DEFAULT 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','RENAME','INDEX',indexName, 'RENAME TO ' || ' ' || indexNew);
        LSQL :='ALTER INDEX '|| indexName ||' RENAME TO ' || indexNew;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Index ' || indexName || ' renamed to ' || indexNew);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE :=SQLCODE;
        IF EX_CODE = -1418 THEN -- Name already in use by an existing object
            LSQL := 'SELECT count(*) FROM USER_INDEXES WHERE INDEX_NAME = '''|| upper(indexName) || '''';
            EXECUTE IMMEDIATE  LSQL  into NUMBER_VAR;
            IF NUMBER_VAR = 0 THEN -- old index name does not exist, could be already renamed?
                 LSQL := 'SELECT count(*) FROM USER_OBJECTS WHERE OBJECT_NAME = ''' || upper(indexNew) ||
                ''' and OBJECT_TYPE = ''INDEX''';
                EXECUTE IMMEDIATE LSQL into NUMBER_VAR;
                IF NUMBER_VAR = 1 THEN -- likely already been renamed
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'' || ' : INDEX ' || indexNew || ' already exists, and ' || indexName ||' no longer exists. (Already renamed?) ' || SQLERRM, ORAERRORNUMBER=> EX_CODE);
                ELSE -- old does not exists, new name belongs to some other object type
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' Cannot change ' || indexName || ' to ' || indexNew || '. That name is already used by an existing object.', ORAERRORNUMBER=> EX_CODE);
                    HANDLE_ERROR(bailOnFail, addIndexFailureLevel, SQLERRM);
                END IF;
            ELSE  -- old index still exists, so doe new index name
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' Cannot change ' || indexName || ' to ' || indexNew || '. That name is already used by an existing object.', ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, renameIndexFailureLevel, SQLERRM);
            END IF;
        ELSE -- some other error - perhaps column doesn't exist?
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : could not change index ' || indexName || ' to ' || indexNew, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addIndexFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE RENAME_TABLE (
    tableName         IN    VARCHAR2,
    tableNameNew      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','RENAME','TABLE',tableName, 'WAS ' || tableNameNew);
        LSQL := 'ALTER TABLE '|| tableName ||' RENAME TO ' || tableNameNew;
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Table ' || tableName || ' RENAMED TO ' || tableNameNew);
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE :=SQLCODE;
        IF EX_CODE = -955 THEN -- Name already in use by an existing object
            EXECUTE IMMEDIATE 'SELECT count(*) FROM USER_TABLES WHERE TABLE_NAME = ''' || upper(tableName) || '''' into NUMBER_VAR;
            IF NUMBER_VAR = 0 THEN -- old table name does not exist, could be already renamed?
                EXECUTE IMMEDIATE 'SELECT count(*) FROM USER_OBJECTS WHERE OBJECT_NAME = ''' || upper(tableNameNew) ||
                ''' and OBJECT_TYPE = ''TABLE''' into NUMBER_VAR;
                IF NUMBER_VAR = 1 THEN -- likely already been renamed
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'' || SQLERRM || ' : Table ' || tableNameNew || ' already exists, ' || tableName || ' no longer exists.', ORAERRORNUMBER=> EX_CODE);
                ELSE -- old does not exist, new name belongs to some other object type
                    v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || '  ' || tableName || ' Does not exist, and was not renamed to ' || tableNameNew || '. That name is already used by an existing non-table object.', ORAERRORNUMBER=> EX_CODE);
                    HANDLE_ERROR(bailOnFail, addTableFailureLevel, SQLERRM);
                END IF;
            ELSE  -- old table still exists, so does new table name
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' Cannot change ' || tableName || ' to ' || tableNameNew || '. That name is already used by an existing object.', ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, renameTableFailureLevel, SQLERRM);
            END IF;
        ELSIF EX_CODE = -942 THEN -- old table does not exist -- check for new name
            EXECUTE IMMEDIATE 'SELECT count(*) FROM USER_OBJECTS WHERE OBJECT_NAME = ''' || upper(tableNameNew) ||
           ''' and OBJECT_TYPE = ''TABLE''' into NUMBER_VAR;
            IF NUMBER_VAR = 1 THEN -- likely already been renamed
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'' || SQLERRM || ' : Table ' || tableNameNew || ' already exists, ' || tableName || ' no longer exists.', ORAERRORNUMBER=> EX_CODE);
            ELSE -- old does not exists, new table doesn't
                v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' Table ' || tableName || ' does not exist, neither does table with name ' || tableNameNew || '.', ORAERRORNUMBER=> EX_CODE);
                HANDLE_ERROR(bailOnFail, addTableFailureLevel, SQLERRM);
            END IF;
        ELSE -- some other error ?
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' : could not change table ' || tableName || ' to ' || tableNameNew, ORAERRORNUMBER=> EX_CODE);
            HANDLE_ERROR(bailOnFail, addTableFailureLevel, SQLERRM);
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  SET_ATTRIBUTE
-- DESCRIPTION    :  sets attibute for ctx preferences
-- POST CONDITIONS:  SUCCESS  : attribute set
--                   INFO     : 
--                   WARNING  : 
--                   ERROR    : attribute not set
--                   FAILURE  : unknown status

-- NOTES          :
PROCEDURE SET_ATTRIBUTE (
    prefName          IN    VARCHAR2,
    attribName        IN    VARCHAR2,
    attribVal         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)

IS
    objCount        number;
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','SET','ATTRIBUTE',prefName || '.' || attribName);
        -- IF preference to be created already exists, drop it
        LSQL := 'SELECT COUNT(*) FROM CTXSYS.CTX_PREFERENCE_VALUES WHERE PRV_PREFERENCE = ''' || upper(prefName) || ''' AND PRV_ATTRIBUTE = ''' || upper(attribName) || ''' AND PRV_VALUE = ''' || upper(attribVal) || ''' AND PRV_OWNER = (SELECT USER FROM DUAL)';
        EXECUTE IMMEDIATE LSQL INTO objCount;
        IF objCount > 0 THEN
            LSQL := 'BEGIN ctx_ddl.unset_attribute ( ''' || upper(prefName) || ''', ''' || upper(attribName) || ''' ); END;';
            EXECUTE IMMEDIATE LSQL;
        END IF;
        -- create preference
        LSQL := 'BEGIN CTX_DDL.SET_ATTRIBUTE ( ''' || upper(prefName) || ''', ''' || upper(attribName) || ''', ''' || upper(attribVal) || ''' ); END;';
        EXECUTE IMMEDIATE LSQL;
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Created CTXSYS Attribute ' || upper(attribName) || ' for Preference ' || upper(prefName) || ' with value(s) ' || upper(attribVal));
    EXCEPTION
    WHEN OTHERS THEN
        v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM);
        HANDLE_ERROR(bailOnFail, setAttributeFailureLevel, SQLERRM);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- PROCEDURE      :  UPDATE_VALUE
-- DESCRIPTION    :  executes an update statement
-- POST CONDITIONS:  SUCCESS  : 1 or more rows updated
--                   INFO     : 0 rows updated
--                   WARNING  : 
--                   ERROR    : Could not update row(s)
--                   FAILURE  : unknown status

-- NOTES          :
PROCEDURE UPDATE_VALUE (
    tableName      IN    VARCHAR2,
    columnName     IN    VARCHAR2,
    value1         IN    VARCHAR2,
    columnName2    IN    VARCHAR2,
    value2         IN    VARCHAR2,
    updateAudit    IN    VARCHAR2    DEFAULT 'Y',
    bailOnFail     IN    VARCHAR2    DEFAULT 'N'
)

IS
    sqlRowCount number;
    auditText   varchar2(70) := '';
    tableCode   varchar2(8);
    v_scd_uid integer;
    BEGIN
        v_scd_uid := STATUS('S','UPDATE','VALUE',tableName || '.' || columnName, columnName2 || ' ' || value1 || ' where ' || value2);
        --Add Audit Calls
        IF updateAudit = 'Y' THEN
            tableCode := SUBSTR(tableName, 0, INSTR(tableName, '_')-1);  --Returns 'TBL'
            auditText := ', ' || tableCode || '_LAST_UPDATE_DATE = SYSDATE, ' || tableCode || '_USR_UID_UPDATED_BY = -4';
        END IF;
        LSQL := 'UPDATE '|| tableName || ' SET ' || columnName || ' = ' || ''''|| value1 || '''' || auditText || ' WHERE ' || columnName2 || ' = ' ||''''|| value2 || '''';
        EXECUTE IMMEDIATE LSQL;
        sqlRowCount := SQL%ROWCOUNT;
        COMMIT;
        IF sqlRowCount > 0 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'Number of rows updated = ' || sqlRowCount);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'C', ltext=>'No rows were updated');
        END IF;
    EXCEPTION
    WHEN OTHERS THEN
        EX_CODE := SQLCODE; --1407 cannot set not null to null
        IF EX_CODE = -1407 THEN
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' Cannot set value to null in not null column.', ORAERRORNUMBER=> EX_CODE);
        ELSE
            v_scd_uid := STATUS(lscduid=>v_scd_uid, lstatus=>'F', ltext=>'' || SQLERRM || ' Cannot update value.', ORAERRORNUMBER=> EX_CODE);
        END IF;
        HANDLE_ERROR(bailOnFail, updateValueFailureLevel, SQLERRM);
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- FUNCTION        :   ENSURE_QUOTES
-- DESCRIPTION      :  ensures that a variable is quoted 
-- POST CONDITIONS:  : returns string with single quotes
FUNCTION ENSURE_QUOTES (
    item        IN      VARCHAR2
)
    RETURN              VARCHAR2
AS
    newItem     VARCHAR2(2000);
    BEGIN
        newItem := item;
        IF instr(newItem, '''') = 0 THEN
            newItem := '''' || newItem || '''';
        END IF;
        RETURN newItem;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
-- FUNCTION        :   ENSURE_PARENS
-- DESCRIPTION      :  ensures that a variable is parethesised
-- POST CONDITIONS:  : returns string with parentheses
FUNCTION ENSURE_PARENS (
    item        IN      VARCHAR2
)
    RETURN              VARCHAR2
AS
    newItem     VARCHAR2(2000);
    BEGIN
        newItem := item;
        IF instr(newItem, '(') = 0 THEN
            newItem := '(' || newItem || ')';
        END IF;
        RETURN newItem;
    END;

FUNCTION CHECK_DATA_EXISTENCE (
    TABLENAME VARCHAR2,
    COLS VARCHAR2,
    COL_DATA VARCHAR2
)
    return integer
AS
columnList varchar2(4000);
datatest    varchar2(4000);
SQLStatement CLOB;
colCounter integer;
colstart integer;
datastart integer;
colend integer;
dataend integer;
loopvar integer;
andvar varchar2(8);
    BEGIN
        SQLStatement := MAKEUPDATELIST(COLS,COL_DATA, 'AND');
        EXECUTE IMMEDIATE 'SELECT count(*) from ' || TABLENAME || ' where ' || SQLStatement into loopvar;
    return loopvar;
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --

FUNCTION CONCAT_STRINGS (
    CONCATSTRING VARCHAR2,
    STRING1 clob,
    STRING2 clob,
    STRING3 clob default '')
RETURN CLOB
AS
    rVAL CLOB;
    BEGIN
        IF STRING1 IS NOT NULL OR STRING1 != '' THEN
            rVal := STRING1;
        END IF;
        IF STRING2 IS NOT NULL OR STRING2 != '' THEN
            IF rVal IS NOT NULL OR rVal != '' THEN
                rval := rval || CONCATSTRING || STRING2;
            ELSE 
                rval := STRING2;
            END IF;
        END IF;
        IF STRING3 IS NOT NULL OR STRING3 != '' THEN
            IF rval IS NOT NULL OR rVal != '' THEN
                rVAL := rval || CONCATSTRING || STRING3;
            ELSE
                rVal := STRING3;
            END IF;
        END IF;
        return rVal;
    END;
FUNCTION MAKE_UPDATE_STATEMENT (
    TABLENAME VARCHAR2,
    WHERELIST CLOB,
    WHEREDATA CLOB,
    COLUMNLIST CLOB,
    DATALIST CLOB
)
return CLOB
AS
SQLStatement CLOB;
    BEGIN
        SQLStatement := 'UPDATE ' || TABLENAME || ' set ' ;
        SQLStatement := SQLStatement || makeUpdateLIst(COLUMNLIST,DATALIST); 
        SQLStatement := SQLStatement || ' where ' ;
        SQLStatement := SQLStatement || makeUpdateLIst(WHERELIST,WHEREDATA,'AND'); 
        return SQLStatement;
    END;

FUNCTION MAKEUPDATELIST (
    COLS VARCHAR2,
    COL_DATA VARCHAR2,
    JOINTOKEN VARCHAR2 default ',')
    return CLOB
AS
columnList varchar2(4000);
datatest    varchar2(4000);
SQLStatement CLOB;
colCounter integer;
colstart integer;
datastart integer;
colend integer;
dataend integer;
loopvar integer;
andvar varchar2(8);
    BEGIN
        SQLStatement := '';
        columnList := translate(COLS, ', ', ',');
        colCounter := regexp_count(columnList, ',') + 1;
        loopvar := 0;
        colstart := 1;
        datastart := 1;
        WHILE loopvar < colCounter LOOP
            loopvar := loopvar + 1;
            colend := instr(columnList,',',colstart + 1) - 1;
            dataend := GET_DATA_ITEM(substr(COL_DATA,datastart));
            if loopvar = colCounter then
                dataend := dataend + 1;
            end if;
            datatest := substr(COL_DATA,datastart,dataend - 1);
            datastart := datastart + dataend ;
            andvar := '';
            if colend > 0 THEN
                andvar := ' ' || JOINTOKEN || ' ';
                SQLStatement := SQLStatement ||  substr(columnList,colstart,colend - colstart + 1);
            ELSE
                SQLStatement := SQLStatement ||  substr(columnList,colstart);
            END IF;
            IF datatest = 'NULL' AND JOINTOKEN in ('OR','AND') THEN
                    SQLStatement := SQLStatement || ' is NULL' || andvar;
            ELSIF datatest = 'NULL' THEN
                SQLStatement := SQLStatement || ' = ''''' || andvar;
            ELSE
                SQLStatement := SQLStatement || ' = '  || datatest || ' ' || andvar;
            END IF;
            colstart := colend + 2;
        END LOOP;
    return SQLStatement;
    END;

FUNCTION TODATE (
    DATESTRING Varchar2)
    return date
AS
BEGIN
    return to_date(DATESTRING, L_DATEFORMAT);
END;

PROCEDURE SETDATEFORMAT (
    formatString varchar2 default 'MM/DD/YYYY')
AS
BEGIN
    L_DATEFORMAT := formatString;
END;

-- Note that the function returns the in-between commas that will be at the 
-- end of the string at retrun val position dataend
FUNCTION GET_DATA_ITEM (
    COL_DATA VARCHAR2,
    JOINTOKEN VARCHAR2 default ',')
    return integer
AS
dataend integer;        -- end of current item, including trailing comma, if it exists.
opened integer;         -- test if current item is quoted or not, and if it has been closed
testchar varchar2(1);   -- character tested one by one
Finished integer;       -- if jointoken has been found
dataendtest integer;    -- loop ends if past length of string.  if so, there will not be a comma at end of string.
BEGIN
    dataend := 1;
    opened :=0;
    dataendtest := length(COL_DATA);
    Finished := 0;
    while Finished = 0 AND dataend < dataendtest LOOP
        -- check if character is JOINTOKEN, meaning end of this item (beginning of next)
        testchar := substr(COL_DATA,dataend, 1);
        if testchar = JOINTOKEN THEN
           if opened = 0 then  -- not in a quoted string, so we are done
                dataend := dataend - 1;
                Finished := 1;
            end if;
        elsif testchar = '''' THEN
            -- found a single quote.  determine if opening or closing
            if opened = 1 then
                opened := 0;
            else 
                opened := 1;
            end if;
        end if;
        dataend := dataend + 1;
    END LOOP;
    if dataend = 1 then
        dataend := 2;
    end if;
return dataend;
END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE SETPACKAGEVERSION

AS
    objcount integer;
    BEGIN
        EXECUTE IMMEDIATE 'select count(*) from SCH_CHANGE_HISTORY where SCH_SHS_SCRIPT = ''PACKAGE_VERSION''' into objcount;
        if objcount = 0 THEN 
            EXECUTE IMMEDIATE 'select min(nvl((select SCH_UID from SCH_CHANGE_HISTORY where sch_uid < 0),0)) -1 from dual' into NUMBER_VAR;
            EXECUTE IMMEDIATE 'insert into SCH_CHANGE_HISTORY (SCH_UID,SCH_ID,SCH_SCH_ID_PARENT,SCH_SHS_SCRIPT) values ('||NUMBER_VAR||', ''' || LC_PACKAGE_VERSION || ''', ''' || LC_PACKAGE_REVISION || ''', ''PACKAGE_VERSION'')';
        ELSE
            EXECUTE IMMEDIATE 'update SCH_CHANGE_HISTORY set SCH_ID = ''' || LC_PACKAGE_VERSION || ''', SCH_SCH_ID_PARENT = ''' || LC_PACKAGE_REVISION || ''' where SCH_SHS_SCRIPT = ''PACKAGE_VERSION''';
        END IF;
        commit;
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
FUNCTION GETPACKAGEVERSION
RETURN varchar2
AS
    BEGIN
        return LC_PACKAGE_VERSION;
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
FUNCTION GETSCHVERSION
RETURN VARCHAR2
AS
    objcount integer;
    ver     varchar2(32);
    BEGIN
        ver := '0';
        EXECUTE IMMEDIATE 'select count(*) from SCH_CHANGE_HISTORY where SCH_SHS_SCRIPT = ''PACKAGE_VERSION''' into objcount;
        if objcount > 0 THEN
            EXECUTE IMMEDIATE 'select sch_id from SCH_CHANGE_HISTORY where SCH_SHS_SCRIPT = ''PACKAGE_VERSION''' into ver;
        END IF;
        return ver;
    END;
FUNCTION GETPACKAGEREVISION
RETURN varchar2
AS
    BEGIN
        return LC_PACKAGE_REVISION;
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
FUNCTION GETSCHREVISION
RETURN VARCHAR2
AS
    objcount integer;
    ver     varchar2(32);
    BEGIN
        ver := '0';
        EXECUTE IMMEDIATE 'select count(*) from SCH_CHANGE_HISTORY where SCH_SHS_SCRIPT = ''PACKAGE_VERSION''' into objcount;
        if objcount > 0 THEN
            EXECUTE IMMEDIATE 'select SCH_SCH_ID_PARENT from SCH_CHANGE_HISTORY where SCH_SHS_SCRIPT = ''PACKAGE_VERSION''' into ver;
        END IF;
        return ver;
    END;
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
FUNCTION SETUPHISTORY (
    forceupdate     varchar2     default 'N'
)
RETURN INTEGER

AS
    objcount integer;
    v_scd_uid integer;
    BEGIN
    SCH_TABLE_EXISTS := 0;
    SELECT count(*) into objcount from USER_TABLES where TABLE_NAME = 'SCH_CHANGE_HISTORY';
        IF objcount = 0 THEN
            CREATE_TABLE('SCH_CHANGE_HISTORY','MAX2_ELA_TS','SCH_UID','NUMBER','');
        END IF;
        IF objcount = 0 OR forceupdate = 'Y' OR GETSCHVERSION() < GETPACKAGEVERSION() THEN
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_UID','NUMBER','10');
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_SHS_SCRIPT','VARCHAR2','32');
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_ID','VARCHAR2','(32)');
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_REVISION','NUMBER','10','0');
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_SCH_ID_PARENT','VARCHAR2','(32)');
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_STATUS','VARCHAR2','8');
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_TYPE','VARCHAR2','1', '''N''');
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_TIME_START','TIMESTAMP');
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_TIME_STOP','TIMESTAMP');
            ADD_COLUMN('SCH_CHANGE_HISTORY','SCH_RECORD_STATUS','VARCHAR2','1');

            ADD_NOT_NULL('SCH_CHANGE_HISTORY','SCH_UID','SCH_NOT_NULL_01');
            ADD_NOT_NULL('SCH_CHANGE_HISTORY','SCH_ID','SCH_NOT_NULL_02');
            ADD_NOT_NULL('SCH_CHANGE_HISTORY','SCH_REVISION','SCH_NOT_NULL_03');
            ADD_INDEX('SCH_PRIMARY_KEY','SCH_CHANGE_HISTORY','SCH_UID','MAX2_INDEX_E_TS');
            ADD_INDEX ('SCH_UNIQUE_01','SCH_CHANGE_HISTORY', 'SCH_ID,SCH_REVISION','MAX2_INDEX_E_TS');
            ADD_INDEX ('SCH_INDEX_01','SCH_CHANGE_HISTORY','SCH_SCH_ID_PARENT' ,'MAX2_INDEX_E_TS');
            ADD_PRIMARY_KEY ('SCH_CHANGE_HISTORY','SCH_PRIMARY_KEY','SCH_UID','MAX2_INDEX_E_TS');
            ADD_UNIQUE ('SCH_CHANGE_HISTORY', 'SCH_UNIQUE_01', 'SCH_ID,SCH_REVISION','MAX2_INDEX_E_TS');
            CREATE_SEQUENCE('SCH_SEQUENCE','1','1','9999999999','NOCYCLE','20');
        END IF;
        SELECT count(*) into objcount from USER_TABLES where TABLE_NAME = 'SCD_SCH_DETAILS';
        IF objcount = 0 THEN
            CREATE_TABLE('SCD_SCH_DETAILS','MAX2_ELA_TS','SCD_UID', 'NUMBER','');
        END IF;
        IF objcount = 0 OR forceupdate = 'Y' OR GETSCHVERSION() < GETPACKAGEVERSION() THEN
            ADD_COLUMN('SCD_SCH_DETAILS','SCD_UID', 'NUMBER','10');
            ADD_COLUMN('SCD_SCH_DETAILS','SCD_SCH_ID', 'VARCHAR2','(32)');
            ADD_COLUMN('SCD_SCH_DETAILS','SCD_SEQUENCE', 'NUMBER','10');
            ADD_COLUMN('SCD_SCH_DETAILS','SCD_STATUS', 'VARCHAR2', '8');
            ADD_COLUMN('SCD_SCH_DETAILS','SCD_ACTION', 'VARCHAR2','8');
            ADD_COLUMN('SCD_SCH_DETAILS','SCD_OBJECT', 'VARCHAR2','32');
            ADD_COLUMN('SCD_SCH_DETAILS','SCD_NAME', 'VARCHAR2','64');
            ADD_COLUMN('SCD_SCH_DETAILS','SCD_TIME_START', 'TIMESTAMP');
            ADD_COLUMN('SCD_SCH_DETAILS','SCD_TIME_STOP', 'TIMESTAMP');

            ADD_NOT_NULL('SCD_SCH_DETAILS','SCD_UID','SCD_NOT_NULL_01');
            ADD_INDEX('SCD_PRIMARY_KEY','SCD_SCH_DETAILS','SCD_UID','MAX2_INDEX_E_TS');
            ADD_PRIMARY_KEY ('SCD_SCH_DETAILS','SCD_PRIMARY_KEY','SCD_UID','MAX2_INDEX_E_TS');
            CREATE_SEQUENCE('SCD_SEQUENCE','1','1','9999999999','NOCYCLE','20');

        END IF;
        SETPACKAGEVERSION();
        SCH_TABLE_EXISTS := 1;
        RETURN SCH_TABLE_EXISTS;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
BEGIN
    LC_PACKAGE_VERSION := '3.0';
    LC_PACKAGE_REVISION := '1.0';
    LANDA_DEFAULT_FAILURE_CODE := 3;
    LANDA_FAILURE_LEVEL_CODE := LANDA_DEFAULT_FAILURE_CODE;
    LANDA_FAILURE_LEVEL_MAX := 5;
    addColumnFailureLevel := 2;
    addConstraintFailureLevel := 3;
    addFKFailureLevel := 4;
    addIndexFailureLevel := 4;
    addPrimaryKeyFailureLevel := 2;
    addSequenceFailureLevel := 3;
    addTriggerFailureLevel := 4;
    addTableFailureLevel := 2;
    addTextIndexFailureLevel := 4;
    addUniqueFailureLevel := 2;
    backUpDataFailureLevel := 2;
    ConstraintIndexLevel := 2;
    CreatePreferenceFailureLevel := 3;
    CreateTriggerFailureLevel := 4;
    CreateSequenceFailureLevel := 3;
    CreateTableFailureLevel := 2;
    deleteFKchildrenFailureLevel := 4;
    deleteValueFailureLevel := 5;
    disableConstraintFailureLevel := 3;
    dropColumnFailureLevel := 4;
    dropConstraintFailureLevel := 4;
    dropFKsFailureLevel := 4;
    dropIndexFailureLevel := 5;
    dropTableFailureLevel := 4;
    dropTabSequenceFailureLevel := 5;
    dropTriggerFailureLevel := 5;
    enableConstraintFailureLevel := 3;
    insertPKvalsFailureLevel := 4;
    insertValsFailureLevel := 4;
    landaInsertFailureLevel := 4;
    modifyColumnFailureLevel := 3;
    moveIndTblspcFailureLevel := 5;
    renameColumnFailureLevel := 3;
    renameConstraintFailureLevel := 4;
    renameIndexFailureLevel := 4;
    renameTableFailureLevel := 3;
    setAttributeFailureLevel := 4;
    updateValueFailureLevel := 5;
    SCH_TABLE_EXISTS := 0;
    L_DATA_SEPARATOR := ',';
    SETDATEFORMAT();

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
END LANDA_CONVERSION;
/
show errors
CREATE or REPLACE 
PACKAGE BODY LANDA_LOGGING 
AS

-- * -- * -- * -- * -- * -- * -- * -- * -- * --
LandaLogTableName   USER_TAB_COLUMNS.TABLE_NAME%type; 
uidColumn           USER_TAB_COLUMNS.COLUMN_NAME%type;
uidDatatype         USER_TAB_COLUMNS.DATA_TYPE%type;
uidsize             varchar2(12);
timeColumn          USER_TAB_COLUMNS.COLUMN_NAME%type;
timedatatype        USER_TAB_COLUMNS.DATA_TYPE%type;
timesize            varchar2(8);
sequenceColumn            USER_TAB_COLUMNS.COLUMN_NAME%type;
sequencedatatype          USER_TAB_COLUMNS.DATA_TYPE%type;
sequencesize              varchar2(8);
itemColumn          USER_TAB_COLUMNS.COLUMN_NAME%type;
itemdatatype        USER_TAB_COLUMNS.DATA_TYPE%type;
itemsize            varchar2(8);
textColumn          USER_TAB_COLUMNS.COLUMN_NAME%type;
textdatatype        USER_TAB_COLUMNS.DATA_TYPE%type;
textsize            varchar2(8);
typeColumn          USER_TAB_COLUMNS.COLUMN_NAME%type;
typedatatype        USER_TAB_COLUMNS.DATA_TYPE%type;
typesize            varchar2(8);
statusColumn        USER_TAB_COLUMNS.COLUMN_NAME%type;
statusDatatype      USER_TAB_COLUMNS.DATA_TYPE%type;
statussize          varchar2(8);
scriptColumn        USER_TAB_COLUMNS.COLUMN_NAME%type;
scriptDataType      USER_TAB_COLUMNS.DATA_TYPE%type;
scriptsize          varchar2(8);
repeatableColumn    USER_TAB_COLUMNS.COLUMN_NAME%type;
repeatableDatatype  USER_TAB_COLUMNS.DATA_TYPE%type;
repeatablesize      varchar2(8);
loggedColumn        USER_TAB_COLUMNS.COLUMN_NAME%type;
loggedDataType      USER_TAB_COLUMNS.DATA_TYPE%type;
loggedsize          varchar2(8);
LindexName          varchar2(30);
LtablespName        varchar2(30);
Lindextablesp       varchar2(30);
indexColumn         varchar2(30);
LscriptName         varchar2(32);
Lsequence           varchar2(4);
LOGGING_ON          varchar2(1);

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE SETLOGTABLENAME (tableName varchar2)

IS
    BEGIN
        LandaLogTableName := tableName;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE setScriptName (scriptNameIn varchar2)

IS
    BEGIN
        LscriptName := scriptNameIn;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

FUNCTION getLogTableName (tprefix varchar2 default 'SCL')
RETURN varchar2

IS
    BEGIN
        IF LandaLogTableName IS NULL THEN
            LandaLogTableName := tprefix || '_CONVERSION_LOG';
        END IF;
        return LandaLogTableName;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

FUNCTION getScriptName return varchar2

IS
    BEGIN
        return LscriptName;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE setLoggingDefaults (
    tprefix     varchar2     default 'SCL'
)

IS
    BEGIN
        IF LandaLogTableName is NULL then
            LandaLogTableName := getLogTableName(tprefix);
        END IF;
        uidColumn           := tprefix || '_UID';
        uidDatatype         := 'NUMBER';
        uidsize             := '(10)';
        timeColumn          := tprefix || '_TIME';   -- time of log entry
        timedatatype        := 'TIMESTAMP';
        timesize            := NULL;
        itemColumn          := tprefix || '_SCH_ID';     -- associated item (issue + type)
        itemdatatype        := 'VARCHAR2';
        itemsize            := '(32)';
        sequenceColumn      := tprefix || '_SEQUENCE';     -- associated scd iterator in item
        sequencedatatype    := 'NUMBER';
        sequencesize        := '(10)';
        textColumn          := tprefix || '_TEXT';   -- text output
        textdatatype        := 'VARCHAR2';
        textsize            := '(200)';
        statusColumn        := tprefix || '_STATUS'; -- status type - started completed, interim
        statusDatatype      := 'VARCHAR2';
        statussize          := '(8)';
        scriptColumn        := tprefix || '_SHS_SCRIPT_NAME';    -- associated shs uid or name
        scriptDatatype      := 'VARCHAR2';
        scriptsize          := '(32)';

        Lindexname         := tprefix || '_INDEX_01';
        indexcolumn     := timeColumn;
        Lindextablesp     := 'MAX2_INDEX_E_TS';
        LtablespName     := 'MAX2_ELA_TS';
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE createOrUpdateLoggingTable (
    forceupdate     varchar2     default 'N'
)

IS
tcount integer;
    BEGIN
        if LandaLogTableName is NULL THEN
            LandaLogTableName := getLogTableName();
        END IF;
        setLoggingDefaults ();
        select count(*) into tcount from user_tables where table_name = LandaLogTableName;
        IF tcount = 0 THEN
            LANDA_CONVERSION.CREATE_TABLE(LandaLogTableName,LtablespName,uidColumn,uidDatatype,uidsize);
        END IF;
        IF tcount = 0 OR forceupdate = 'Y' OR LANDA_CONVERSION.GETSCHVERSION() < LANDA_CONVERSION.GETPACKAGEVERSION() OR (LANDA_CONVERSION.GETSCHVERSION() = LANDA_CONVERSION.GETPACKAGEVERSION() AND LANDA_CONVERSION.GETSCHREVISION() < LANDA_CONVERSION.GETPACKAGEREVISION()) THEN
            LANDA_CONVERSION.ADD_COLUMN(LandaLogTableName,uidColumn, uidDatatype,uidsize);
            LANDA_CONVERSION.ADD_COLUMN(LandaLogTableName,timeColumn, timeDatatype);
            LANDA_CONVERSION.ADD_COLUMN(LandaLogTableName,itemColumn, itemDatatype,itemsize);
            LANDA_CONVERSION.ADD_COLUMN(LandaLogTableName,sequenceColumn, sequencedatatype,sequencesize);
            LANDA_CONVERSION.ADD_COLUMN(LandaLogTableName,statusColumn, statusDatatype,statussize);
            LANDA_CONVERSION.ADD_COLUMN(LandaLogTableName,textColumn, textDatatype,textsize);
            LANDA_CONVERSION.ADD_COLUMN(LandaLogTableName,scriptColumn, scriptDatatype,scriptsize);
            
            LANDA_CONVERSION.ADD_INDEX ('SCL_PRIMARY_KEY',LandaLogTableName,uidColumn,Lindextablesp);
            LANDA_CONVERSION.ADD_NOT_NULL(LandaLogTableName,uidColumn,'SCL_NOT_NULL_01');
            LANDA_CONVERSION.ADD_PRIMARY_KEY(LandaLogTableName,'SCL_PRIMARY_KEY',uidColumn,Lindextablesp);

            LANDA_CONVERSION.CREATE_SEQUENCE('SCL_SEQUENCE','1','1','9999999999','NOCYCLE','20');
        END IF;
    END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE LOG (
    THETEXT                 varchar2 default '',
    THEITEM                 varchar2 default '',
    THESEQUENCE             NUMBER default '',
    THESTATUS               varchar2 default '',
    THESCRIPT               varchar2 default ''
)

IS
    Ltext        varchar2(200);
    Luid        NUMBER(10);
    BEGIN
        Ltext := substr(replace(THETEXT,''''), 1, 200);
        if LOGGING_ON = 'Y' THEN
            EXECUTE IMMEDIATE 'SELECT SCL_SEQUENCE.NEXTVAL from dual'  into Luid;
            EXECUTE IMMEDIATE 'INSERT INTO ' || LandaLogTableName || ' (' || uidColumn || ',' ||
            timeColumn || ',' || itemColumn || ',' || sequenceColumn || ',' ||statusColumn || ',' ||
            textColumn || ',' || scriptColumn ||
            ') values ( ' || Luid || ', systimestamp ,' || '''' || THEITEM || ''',''' ||
            THESEQUENCE || ''',''' || THESTATUS || ''',''' ||
            Ltext || ''',''' || THESCRIPT || ''')';
            commit;
        ELSE
            dbms_output.put_line (systimestamp || ' ' || THEITEM || ' ' ||
            THESEQUENCE || ' ' ||
            THETEXT || ' ' || THESCRIPT );
        END IF;
     END;

-- * -- * -- * -- * -- * -- * -- * -- * -- * --

PROCEDURE setLog (LACTION varchar2 )

IS
    Luid        NUMBER(10);
    BEGIN
        IF upper(LACTION) = 'START' THEN
            LOGGING_ON := 'Y';
            EXECUTE IMMEDIATE 'SELECT SCL_SEQUENCE.NEXTVAL from dual'  into Luid;
            EXECUTE IMMEDIATE 'INSERT INTO ' || LandaLogTableName || ' (  ' || uidColumn || ',' || timeColumn || ',' || scriptColumn || ',' || textColumn || ') VALUES ( ' || Luid || ', systimestamp  , ''' || LscriptName || ''',''' || LACTION || ''')';
            COMMIT;
        ELSE
            LOGGING_ON := 'N';
        END IF;
    END;
     
PROCEDURE cleanUpTables_Duplicate_SCD
IS 
    LSQL VARCHAR2(4000);
    BEGIN     
        dbms_output.put_line( 'Duplicate removal of SCD_SCH_DETAILS table in-progress'); 
    
        -- now delete duplicate rows from SCD table
        LSQL :=  'delete from SCD_SCH_DETAILS
            where SCD_UID in (
              select SCD_UID from  
              (
                select SCD.countofduplicates , B.SCD_UID, B.SCD_SCH_ID, B.SCD_SEQUENCE, B.SCD_STATUS , B.SCD_ACTION , B.SCD_OBJECT , B.SCD_NAME , 
                ROW_NUMBER() OVER ( PARTITION BY B.SCD_SCH_ID, B.SCD_SEQUENCE, B.SCD_STATUS , B.SCD_ACTION , B.SCD_OBJECT , B.SCD_NAME ORDER BY B.SCD_UID desc ,  B.SCD_SCH_ID, B.SCD_SEQUENCE, B.SCD_STATUS , B.SCD_ACTION , B.SCD_OBJECT , B.SCD_NAME ) AS RowRank
                , SCD_TIME_START from SCD_SCH_DETAILS B
                INNER JOIN ( 
                        select count (*) as countofduplicates , SCD_SCH_ID, SCD_SEQUENCE, SCD_STATUS , SCD_ACTION , SCD_OBJECT , SCD_NAME
                        from SCD_SCH_DETAILS 
                        group by SCD_SCH_ID, SCD_SEQUENCE, SCD_STATUS , SCD_ACTION , SCD_OBJECT , SCD_NAME
                        having count (*) > 1
                        order by SCD_SCH_ID desc
                  ) SCD on B.SCD_SCH_ID = SCD.SCD_SCH_ID and B.SCD_SEQUENCE =SCD.SCD_SEQUENCE and  B.SCD_STATUS =SCD.SCD_STATUS and B.SCD_ACTION =SCD.SCD_ACTION and B.SCD_OBJECT =SCD.SCD_OBJECT and B.SCD_NAME =SCD.SCD_NAME
              )
                  where RowRank > 1
            )' ;
        EXECUTE IMMEDIATE LSQL ;
        commit ;
        
    dbms_output.put_line('Duplicate removal of SCD_SCH_DETAILS tables finished'); 

    END;
    
PROCEDURE cleanUpTables_Duplicate_SCL (
    LandaLogTableName     varchar2 ,
    tprefix     varchar2     default 'SCL'
)
IS 
    LSQL VARCHAR2(4000);
    BEGIN                
        dbms_output.put_line( 'Duplicate removal for table ' || LandaLogTableName || ' in-progress');

        -- now delete duplicate rows from SCL table
        LSQL :=  'DELETE FROM ' || LandaLogTableName || '
            where SCL_UID in (
                  select SCL_UID from 
                   (
                      select SCL.countofduplicate, B.SCL_UID , B.SCL_TEXT  , B.SCL_STATUS , B.SCL_SHS_SCRIPT_NAME, B.SCL_SCH_ID, B.SCL_SEQUENCE , 
                      ROW_NUMBER() OVER(PARTITION BY B.SCL_TEXT , B.SCL_STATUS , B.SCL_SHS_SCRIPT_NAME, B.SCL_SCH_ID, B.SCL_SEQUENCE ORDER BY B.SCL_UID desc, B.SCL_TEXT , B.SCL_STATUS , B.SCL_SHS_SCRIPT_NAME, B.SCL_SCH_ID, B.SCL_SEQUENCE) AS RowRank
                      from ' || LandaLogTableName || ' B
                        INNER JOIN ( 
                              select count (*) as countofduplicate , SCL_TEXT  , SCL_STATUS , SCL_SHS_SCRIPT_NAME, SCL_SCH_ID, SCL_SEQUENCE 
                              from ' || LandaLogTableName || ' 
                              group by SCL_TEXT  , SCL_STATUS , SCL_SHS_SCRIPT_NAME, SCL_SCH_ID, SCL_SEQUENCE 
                              having count (*)  > 1
                              order by SCL_TEXT desc
                        ) SCL on B.SCL_TEXT = SCL.SCL_TEXT and B.SCL_STATUS = SCL.SCL_STATUS and B.SCL_SHS_SCRIPT_NAME = SCL.SCL_SHS_SCRIPT_NAME and B.SCL_SCH_ID =  SCL.SCL_SCH_ID and B.SCL_SEQUENCE = SCL.SCL_SEQUENCE
                  )
                  where RowRank > 1
            )' ;  
        EXECUTE IMMEDIATE LSQL ;
        commit ;        
        
        dbms_output.put_line('Duplicate removal of tables ' || LandaLogTableName || ' finished'); 

    END;

PROCEDURE cleanUpTables_deleteDataByDay ( TABLENAME varchar2, COLUMNNAME varchar2 , DAYS integer, COMPARISON varchar2 ) 
IS 
    LSQL VARCHAR2(4000);
    COMPARISON_text VARCHAR2(20);
    BEGIN        
        -- Delete data older then XX days(XX can not be more then 99 days)   
        IF DAYS > 99 then
            dbms_output.put_line('Condition must not be greter then 99 days !!!');
            RETURN;
        END IF; 
        CASE COMPARISON 
            WHEN '<' THEN COMPARISON_text := 'less than' ;
            WHEN '>' THEN COMPARISON_text := 'greater than' ;
            WHEN '=' THEN COMPARISON_text := 'equals to' ;
       END CASE; 
        
        dbms_output.put_line('Deleting data '|| COMPARISON_text ||' '|| DAYS ||' days from table '|| TABLENAME ||'...');
        LSQL := 'DELETE FROM '|| TABLENAME ||' 
                 WHERE '|| COLUMNNAME ||' '|| COMPARISON ||'  SYSDATE - INTERVAL '''|| DAYS ||''' DAY' ;      
        EXECUTE IMMEDIATE LSQL ;
        commit ;
    END;
    
PROCEDURE cleanUpTables_VERSION (
    VERSION     varchar2    
)
IS 
    LSQL VARCHAR2(4000);
    tprefix     varchar2(10)  default  'SCL';
    BEGIN
        
        IF LandaLogTableName is NULL then
            LandaLogTableName := getLogTableName(tprefix);
        END IF;        

        -- now delete duplicate rows from SCL table
        dbms_output.put_line('Removing log for version ' || VERSION || '');
        LSQL :=  'DELETE FROM ' || LandaLogTableName || ' 
        where SCL_SHS_SCRIPT_NAME in ( select SHS_SQL_SCRIPT_NAME from SHS_SCHEMA_HISTORY where shs_version_new = ''' || VERSION || ''' )' ;  
        EXECUTE IMMEDIATE LSQL ;
        commit ;
        
        dbms_output.put_line('Cleaning of tables ' || LandaLogTableName || ' for version ' || VERSION || ' finished'); 

    END;
    
-- Main Procedure to call the cleanup procedures     
PROCEDURE cleanUpTables ( 
    TABLENAME varchar2 default 'ALL',
    CONDITION varchar2 default 'BY DAY',
    COMPARISON varchar2 default '<',    
    DAY_VERSION_DATE varchar2 default 30,
    tprefix     varchar2     default 'SCL'    
)
IS 
DAYS INTEGER;
VERSION varchar2(20);
DATE varchar2(20);
LSQL VARCHAR2(4000);
    BEGIN    

        IF LandaLogTableName is NULL then
            LandaLogTableName := upper(getLogTableName(tprefix));
        END IF;         
      
      CASE upper(CONDITION)
            WHEN 'BY DAY' THEN                
                DAYS := DAY_VERSION_DATE ;                
                CASE upper(TABLENAME)
                -- Delete data older then XX days
                    WHEN LandaLogTableName THEN 
                        -- SCL table
                        LANDA_LOGGING.cleanUpTables_deleteDataByDay(LandaLogTableName,'SCL_TIME',DAYS,COMPARISON);
                    WHEN 'SCD_SCH_DETAILS' THEN
                        -- SCD table
                        LANDA_LOGGING.cleanUpTables_deleteDataByDay('SCD_SCH_DETAILS','SCD_TIME_START',DAYS,COMPARISON);
                    WHEN 'ALL' THEN                        
                        --ALL
                        -- SCL table
                        LANDA_LOGGING.cleanUpTables_deleteDataByDay(LandaLogTableName,'SCL_TIME',DAYS,COMPARISON);
                         -- SCD table
                        LANDA_LOGGING.cleanUpTables_deleteDataByDay('SCD_SCH_DETAILS','SCD_TIME_START',DAYS,COMPARISON);
                    ELSE
                        dbms_output.put_line('**************************************************');
                        dbms_output.put_line('Don''t know how to clean the table ''' || TABLENAME || ''' !!!') ;
                        dbms_output.put_line('**************************************************');
                END CASE;        
            WHEN 'BY VERSION' THEN
                VERSION := DAY_VERSION_DATE;
                dbms_output.put_line('CLEANING UP BY VERSION ' || VERSION  ) ;
                LANDA_LOGGING.cleanUpTables_VERSION(VERSION);
            WHEN 'BY DATE' THEN
                DATE := DAY_VERSION_DATE;
                dbms_output.put_line('CLEANING UP BY DATE ' || DATE ) ;
                dbms_output.put_line ('SELECT ROUND ( SysDate - TO_DATE('''||DATE||''',''DD-MM-YYYY'') ) FROM dual' ) ;
                LSQL := 'SELECT ROUND ( SysDate - TO_DATE('''||DATE||''',''DD-MM-YYYY'') ) FROM dual' ;                    
                EXECUTE IMMEDIATE LSQL into DAYS;  
                
                CASE upper(TABLENAME)
                    WHEN LandaLogTableName THEN  
                        -- SCL table
                        LANDA_LOGGING.cleanUpTables_deleteDataByDay(LandaLogTableName,'SCL_TIME',DAYS,COMPARISON);
                    WHEN 'SCD_SCH_DETAILS' THEN 
                        -- SCD table
                        LANDA_LOGGING.cleanUpTables_deleteDataByDay('SCD_SCH_DETAILS','SCD_TIME_START',DAYS,COMPARISON); 
                    WHEN 'ALL' THEN 
                        -- SCL table
                        LANDA_LOGGING.cleanUpTables_deleteDataByDay(LandaLogTableName,'SCL_TIME',DAYS,COMPARISON);
                        -- SCD table
                        LANDA_LOGGING.cleanUpTables_deleteDataByDay('SCD_SCH_DETAILS','SCD_TIME_START',DAYS,COMPARISON);                      
                    ELSE
                        dbms_output.put_line('**************************************************');
                        dbms_output.put_line('Don''t know how to clean the table ''' || TABLENAME || ''' !!!') ;
                        dbms_output.put_line('**************************************************');
                END CASE;
            WHEN 'DUPLICATES' THEN 
                -- now remove duplicates
                CASE upper(TABLENAME)
                    WHEN LandaLogTableName THEN  
                        LANDA_LOGGING.cleanUpTables_Duplicate_SCL(LandaLogTableName) ;
                    WHEN 'SCD_SCH_DETAILS' THEN 
                        LANDA_LOGGING.cleanUpTables_Duplicate_SCD ; 
                    WHEN 'ALL' THEN 
                        LANDA_LOGGING.cleanUpTables_Duplicate_SCL(LandaLogTableName) ;
                        LANDA_LOGGING.cleanUpTables_Duplicate_SCD ;                      
                    ELSE
                        dbms_output.put_line('**************************************************');
                        dbms_output.put_line('Don''t know how to clean the table ''' || TABLENAME || ''' !!!') ;
                        dbms_output.put_line('**************************************************');
                END CASE;
            ELSE
                dbms_output.put_line('**************************************************');
                dbms_output.put_line('Wrong Argument !! ') ;
                dbms_output.put_line('Please use one of the following options: ') ;
                dbms_output.put_line('1) exec LANDA_LOGGING.cleanUpTables(''ALL'', ''BY DATE'', ''<'' ,''30-12-2019'')') ;
                dbms_output.put_line('2) exec LANDA_LOGGING.cleanUpTables(''ALL'', ''BY DAY'', ''<'' ,''30'')') ;
                dbms_output.put_line('3) exec LANDA_LOGGING.cleanUpTables(''SCD_SCH_DETAILS'', ''BY VERSION'', ''<'' ,''03.03.00.00'')') ;
                dbms_output.put_line('4) exec LANDA_LOGGING.cleanUpTables(''SCD_SCH_DETAILS'', ''BY VERSION'', ''='' ,''03.03.00.00'')') ;
                dbms_output.put_line('5) exec LANDA_LOGGING.cleanUpTables(''ALL'', ''DUPLICATES'')') ;
                dbms_output.put_line('**************************************************');
       END CASE;             
    END;
 
-- * -- * -- * -- * -- * -- * -- * -- * -- * --
BEGIN
setLoggingDefaults();
END LANDA_LOGGING;
/
show errors
