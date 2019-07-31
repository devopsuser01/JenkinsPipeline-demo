-- LC_PACKAGE_VERSION=3.0
-- LC_PACKAGE_REVISION=1
set echo off
CREATE OR REPLACE 
PACKAGE LANDA_CONVERSION 
AUTHID CURRENT_USER
AS
TYPE LANDA_VAR_ARRAY IS VARRAY(2000) of VARCHAR2(64);

FUNCTION GET_OBJECT_TBLSP (
   objectName IN VARCHAR2
)
   RETURN varchar2;
PROCEDURE SET_OBJECT_TBLSP (
   objectName IN VARCHAR2,
   objectType IN VARCHAR2 default 'INDEX'
);
PROCEDURE DELETE_OBJECT_TBLSP (
   objectName        IN    VARCHAR2
);
FUNCTION GET_DEFAULT_TBLSP (
   tableName   IN    VARCHAR2,
   bailOnFail  IN    VARCHAR2    default 'N'
)
   RETURN varchar2;
FUNCTION GET_FAILURE_LEVEL
   return integer;
FUNCTION GET_LANDA_FAILURE_LEVEL
   return integer;
PROCEDURE SET_LANDA_FAILURE_LEVEL (
   newLevel integer
);
PROCEDURE HANDLE_ERROR (
    lbail varchar2,
    lfailurelevel integer default 3,
    lerrmessage varchar2 default null
);
PROCEDURE SHS_ENTRY (
    scriptName varchar2, 
    status varchar2,
    versionName varchar2 default null, 
    scriptType varchar2 default 'UPDATE'
);
FUNCTION GET_VERSION (scriptName varchar2)
return varchar2;
FUNCTION GET_FAILED_SCRIPT
RETURN varchar2;
PROCEDURE START_SCRIPT (
    scriptName varchar2 default null, 
    versionName varchar2 default null, 
    scriptType varchar2 default 'UPDATE'
);
PROCEDURE STOP_SCRIPT (
    scriptName varchar2 default null,
    versionName varchar2 default null,
    scriptType varchar2 default 'UPDATE'
);
FUNCTION START_ITEM (
    ID         varchar2,
    PARENT_ID  varchar2 default null,
    REVISION   varchar2 default '0',
    ITEM_TYPE     varchar2 default 'N'
)
RETURN boolean;
PROCEDURE STOP_ITEM;
FUNCTION STATUS (
lstatus  varchar2,
laction  varchar2 default null,
lobject  varchar2 default null,
lname     varchar2 default null,
ltext    varchar2 default null,
lscduid number default 0,
ORAERRORNUMBER number default 0
)
    return number;
PROCEDURE POST (
    lstatus VARCHAR2,
    ltext VARCHAR2
);
PROCEDURE ADD_COLUMN (
   tableName         IN    VARCHAR2,
   columnName        IN    VARCHAR2,
   columnDataType    IN    VARCHAR2,
   columnLength      IN    VARCHAR2    default NULL,
   defaultValue      IN    VARCHAR2    default NULL,
   constraintClause  IN    VARCHAR2    default NULL,
   bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE ADD_FOREIGN_KEY (
   childTableName    IN    VARCHAR2,
   constraintName    IN    VARCHAR2,
   childColumnName   IN    VARCHAR2,
   parentTableName   IN    VARCHAR2,
   parentColumnName  IN    VARCHAR2,
   cascadeClause     IN    VARCHAR2    default NULL,
   bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE ADD_INDEX (
   indexName         IN    VARCHAR2,
   tableName         IN    VARCHAR2,
   columnNameList    IN    VARCHAR2,
   tbSpace           IN    VARCHAR2,
   initamt           IN    INTEGER     DEFAULT 8,
   nextamt           IN    INTEGER     DEFAULT 120,
   bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE ADD_INDEX_1C (
    tableName         VARCHAR2,
    columnName        VARCHAR2,
    indexName         VARCHAR2,
    tbSpace           VARCHAR2,
    initamt           INTEGER     DEFAULT 8,
    nextamt           INTEGER     DEFAULT 120,
    bailOnFail        VARCHAR2    default 'N'
    );
PROCEDURE ADD_INDEX_2C (
    indexName         IN    VARCHAR2,
    tableName         IN    VARCHAR2,
    columnName1       IN    VARCHAR2,
    columnName2       IN    VARCHAR2,
    tbSpace           IN    VARCHAR2,
    initamt           IN    INTEGER     DEFAULT 8,
    nextamt           IN    INTEGER     DEFAULT 120,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE ADD_NOT_NULL (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE ADD_PRIMARY_KEY (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    columnNames       IN    VARCHAR2,
    indexTableSpace   IN    VARCHAR2    DEFAULT NULL,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE ADD_UNIQUE (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    tableSpace        IN    VARCHAR2    default NULL,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE CONSTRAINT_INDEX (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    columnNames       IN    VARCHAR2,
    tableSpace        IN    VARCHAR2 DEFAULT NULL,
    constraintType    IN    VARCHAR2 DEFAULT 'U'
);
PROCEDURE CREATE_PREFERENCE (
prefName          IN    VARCHAR2,
objName           IN    VARCHAR2,
addClause         IN    VARCHAR2    default NULL,
bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE CREATE_TEXT_INDEX (
    indexName varchar2,
    tableName varchar2,
    columnNames varchar2,
    indexType varchar2 default 'CTXSYS.CONTEXT',
    indexParameters varchar2 default 'SYNC (ON COMMIT) STOPLIST CTXSYS.EMPTY_STOPLIST STORAGE TEXT_STORAGE',
    bailonFail varchar2 default 'N'
);
PROCEDURE CREATE_TRIGGER (
    triggerDescription         IN    VARCHAR2,
    triggerWhenClause          IN    VARCHAR2,
    triggerBody                IN    VARCHAR2,
    bailOnFail                 IN    VARCHAR2    default 'N'
);
PROCEDURE CREATE_RECORD_VERSION_TRIGGER (
    tableName         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE CREATE_RECORD_VERSION_TRIGGERS;
PROCEDURE DROP_RECORD_VERSION_TRIGGERS;
PROCEDURE DISABLE_RECORD_VERSION_TRIGS;
PROCEDURE ENABLE_RECORD_VERSION_TRIGGERS;
PROCEDURE CREATE_SEQUENCE (
    sequenceName      IN    VARCHAR2,
    startValue        IN    NUMBER      default 1,
    incrementValue    IN    NUMBER      default 1,
    maximumValue      IN    NUMBER      default 9999999999,
    cycleParam        IN    VARCHAR2    default 'NOCYCLE',
    cacheParam        IN    VARCHAR2    default '',
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE CREATE_TABLE (
    tableName         IN    VARCHAR2,
    tablespaceName    IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    columnDataType    IN    VARCHAR2,
    columnLength      IN    VARCHAR2    default '',
    defaultClause     IN    VARCHAR2    default '',
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE DELETE_FK_CHILDREN (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    colVal            IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE DELETE_VALUE (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    value1            IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE DISABLE_COL_CONSTRAINTS (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE DISABLE_CONSTRAINT (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
);
PROCEDURE DISABLE_FK_CONSTRAINTS (
    primaryKeyName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE ENABLE_FK_CONSTRAINTS (
    primaryKeyName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE DROP_COLUMN (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    saveData          IN    VARCHAR2 default 'Y',
    bailOnFail        IN    VARCHAR2 default 'N'
);
PROCEDURE DROP_DROPPED_COLUMNS (
    ScriptName in VARCHAR2 default null
);
PROCEDURE DROP_CONSTRAINT (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
);
PROCEDURE DROP_FOREIGN_KEYS (
    primaryKeyName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE DROP_INDEX (
    indexName         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
);
PROCEDURE DROP_INDEX_FROM (
    tableName         IN    VARCHAR2,
    columnNameList    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
);
PROCEDURE DROP_INDEX_FROM_COLUMN (
    tableName         IN    VARCHAR2,
    columnName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
);
PROCEDURE DROP_CONSTRAINT_FROM_COLUMN (
    tableName         IN    VARCHAR2,
    columnName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
);
PROCEDURE DROP_CONSTRAINT_FROM_TYPE (
    tableName         IN    VARCHAR2,
    columnName    IN    VARCHAR2,
    constraintType      IN VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
);
PROCEDURE DROP_SEQUENCE (
    sequenceName      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2 default 'N'
);
PROCEDURE DROP_TABLE (
    tableName         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE DROP_TAB_SEQUENCE (
    tableName      IN    VARCHAR2,
    bailOnFail     IN    VARCHAR2   DEFAULT 'N'
);
PROCEDURE DROP_TRIGGER (
    triggerName       IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE ENABLE_CONSTRAINT (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
FUNCTION GET_PARENT_FK_COLS (
    tableName         IN   VARCHAR2,
    bailOnFail        IN   VARCHAR2    default 'N'
)
    return              LANDA_VAR_ARRAY;
FUNCTION GET_PRIMARY_KEY_NAME (
    tableName         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
)
    return      VARCHAR2;
PROCEDURE INSERT_DATA (
    TABLENAME VARCHAR2,
    PK_COL VARCHAR2,
    PK_DATA VARCHAR2,
    OTHER_COLS VARCHAR2,
    OTHER_DATA  VARCHAR2,
    SYSTEM_YN VARCHAR2 default 'N',
    BAILONFAIL VARCHAR2 default 'N'
);
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
);
PROCEDURE INSERT_VALS (
    tableName         IN  VARCHAR2,
    columnList        IN  VARCHAR2,
    valueList         IN  VARCHAR2,
    bailOnFail        IN  VARCHAR2    DEFAULT 'N'
);
PROCEDURE LANDA_ADD_COLUMN (
    tableName           VARCHAR2,
    columnName          VARCHAR2,
    columnDataType      VARCHAR2,
    columnLength        VARCHAR2    default NULL,
    defaultValue        VARCHAR2    default NULL,
    constraintClause    VARCHAR2    default NULL
);
PROCEDURE LANDA_ADD_FOREIGN_KEY (
    childTableName      VARCHAR2,
    constraintName      VARCHAR2,
    childColumnName     VARCHAR2,
    parentTableName     VARCHAR2,
    parentColumnName    VARCHAR2
);
PROCEDURE LANDA_ADD_INDEX_1C (
    tableName   VARCHAR2,
    columnName  VARCHAR2,
    indexName   VARCHAR2,
    tbSpace     VARCHAR2,
    initamt     INTEGER     DEFAULT 8,
    nextamt     INTEGER     DEFAULT 120
);
PROCEDURE LANDA_ADD_INDEX_2C (
    indexName           VARCHAR2,
    tableName           VARCHAR2,
    columnName1         VARCHAR2,
    columnName2         VARCHAR2,
    tbSpace             VARCHAR2,
    initamt             INTEGER         DEFAULT 8,
    nextamt             INTEGER         DEFAULT 120
);
PROCEDURE LANDA_ADD_NOT_NULL (
    tableName       VARCHAR2,
    columnName      VARCHAR2,
    constraintName  VARCHAR2
);
PROCEDURE LANDA_ADD_PRIMARY_KEY (
    tableName           VARCHAR2,
    constraintName      VARCHAR2,
    columnNames         VARCHAR2,
    indexTableSpace     VARCHAR2
);
PROCEDURE LANDA_ADD_UNIQUE (
    tableName       VARCHAR2,
    constraintName  VARCHAR2,
    columnName      VARCHAR2,
    tableSpace      VARCHAR2
);
PROCEDURE LANDA_CREATE_PREFERENCE (
    prefName       VARCHAR2,
    objName        VARCHAR2
);
PROCEDURE LANDA_CREATE_SEQUENCE (
    sequenceName    VARCHAR2,
    startValue      NUMBER      default 1,
    incrementValue  NUMBER      default 1,
    maximumValue    NUMBER      default 9999999999,
    cycleParam      VARCHAR2    default 'NOCYCLE',
    cacheParam      VARCHAR2    default 'NOCACHE'
);
PROCEDURE LANDA_CREATE_TABLE (
    tableName         VARCHAR2,
    tablespaceName    VARCHAR2,
    columnName        VARCHAR2,
    columnDataType    VARCHAR2,
    columnLength      VARCHAR2    default '',
    defaultClause     VARCHAR2    default ''
);
PROCEDURE LANDA_DELETE_FK_CHILDREN (
    tableName       IN  VARCHAR2,
    columnName      IN  VARCHAR2,
    colVal          IN  VARCHAR2
);
PROCEDURE LANDA_DELETE_VALUE (
    tableName       VARCHAR2,
    columnName      VARCHAR2,
    value1          VARCHAR2
);
PROCEDURE LANDA_DISABLE_COL_CONSTRAINTS (
    tableName       VARCHAR2,
    columnName      VARCHAR2
);
PROCEDURE LANDA_DISABLE_CONSTRAINT (
    tableName       VARCHAR2,
    constraintName  VARCHAR2
);
PROCEDURE LANDA_DISABLE_FK_CONSTRAINTS (
    primaryKeyName  IN VARCHAR2
);
PROCEDURE LANDA_DROP_COLUMN (
    tableName   VARCHAR2,
    columnName  VARCHAR2
);
PROCEDURE LANDA_DROP_CONSTRAINT (
    tableName       IN  VARCHAR2,
    constraintName  IN  VARCHAR2
);
PROCEDURE LANDA_DROP_FOREIGN_KEYS (
    primaryKeyName  IN VARCHAR2
);
PROCEDURE LANDA_DROP_INDEX (
    indexName       VARCHAR2
);
PROCEDURE LANDA_DROP_SEQUENCE (
    tableName   VARCHAR2
);
PROCEDURE LANDA_DROP_TABLE (
    tableName   IN      VARCHAR2
);
PROCEDURE LANDA_DROP_TRIGGERS (
    triggerName         VARCHAR2
);
PROCEDURE LANDA_ENABLE_CONSTRAINT (
    tableName       VARCHAR2,
    constraintName  VARCHAR2
);
FUNCTION LANDA_GET_PARENT_FK_COLS (
    tableName   IN      VARCHAR2
)
    return              LANDA_VAR_ARRAY;
FUNCTION LANDA_GET_PRIMARY_KEY_NAME (
    tableName   IN      VARCHAR2
)
    return      VARCHAR2;
PROCEDURE RUN_DML (
    sqlStatement      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE RUN_DML_S (
    sqlStatement      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE LANDA_INSERT (
    sqlStatement      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE LANDA_INSERT_VALS (
    tableName   IN  varchar2,
    columnList  IN  varchar2,
    valueList   IN  varchar2
);
PROCEDURE LANDA_MODIFY_COLUMN (
    tableName            VARCHAR2,
    columnName           VARCHAR2,
    columnDataType       VARCHAR2,
    columnLength         VARCHAR2    default NULL,
    defaultClause        VARCHAR2    default NULL,
    additionalClause     VARCHAR2    default NULL
);
PROCEDURE LANDA_RENAME_COLUMN (
    tableName       VARCHAR2,
    oldColumnName   VARCHAR2,
    newColumnName   VARCHAR2
);
PROCEDURE LANDA_RENAME_CONSTRAINT (
    tableName           VARCHAR2,
    constraintName      VARCHAR2,
    constraintName2     VARCHAR2
);
PROCEDURE LANDA_RENAME_INDEX (
    indexName       VARCHAR2,
    indexNew        VARCHAR2
);
PROCEDURE LANDA_RENAME_TABLE (
    tableName       VARCHAR2,
    tableName2      VARCHAR2
);
PROCEDURE LANDA_SET_ATTRIBUTE (
    prefName        VARCHAR2,
    attribName      VARCHAR2,
    attribVal       VARCHAR2
);
PROCEDURE LANDA_TRIG_RECORD(
    triggerName         VARCHAR2,
    tableName           VARCHAR2,
    columnName          VARCHAR2
);
PROCEDURE LANDA_UPDATE_VALUE (
    tableName   VARCHAR2,
    columnName  VARCHAR2,
    value1      VARCHAR2,
    columnName2 VARCHAR2,
    value2      VARCHAR2
);
PROCEDURE MODIFY_COLUMN (
    tableName         IN    VARCHAR2,
    columnName        IN    VARCHAR2,
    columnDataType    IN    VARCHAR2,
    columnLength      IN    VARCHAR2    default NULL,
    defaultClause     IN    VARCHAR2    default NULL,
    additionalClause  IN    VARCHAR2    default NULL,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE MOVE_IND_TBLSPC (
    indexName        IN    VARCHAR2,
    tblspc           IN    VARCHAR2,
    bailOnFail       IN    VARCHAR2    DEFAULT 'N'
);
PROCEDURE RENAME_COLUMN (
    tableName         IN    VARCHAR2,
    oldColumnName     IN    VARCHAR2,
    newColumnName     IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE RENAME_CONSTRAINT (
    tableName         IN    VARCHAR2,
    constraintName    IN    VARCHAR2,
    constraintNameNew IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE RENAME_INDEX (
    indexName        IN    VARCHAR2,
    indexNew         IN    VARCHAR2,
    bailOnFail       IN    VARCHAR2    DEFAULT 'N'
);
PROCEDURE RENAME_TABLE (
    tableName         IN    VARCHAR2,
    tableNameNew      IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE SET_ATTRIBUTE (
    prefName          IN    VARCHAR2,
    attribName        IN    VARCHAR2,
    attribVal         IN    VARCHAR2,
    bailOnFail        IN    VARCHAR2    default 'N'
);
PROCEDURE UPDATE_VALUE (
    tableName      IN    VARCHAR2,
    columnName     IN    VARCHAR2,
    value1         IN    VARCHAR2,
    columnName2    IN    VARCHAR2,
    value2         IN    VARCHAR2,
    updateAudit    IN    VARCHAR2    DEFAULT 'Y',
    bailOnFail     IN    VARCHAR2    DEFAULT 'N'
);
FUNCTION ENSURE_QUOTES (
    item        IN      VARCHAR2
)
RETURN              VARCHAR2;
FUNCTION ENSURE_PARENS (
    item        IN      VARCHAR2
)
RETURN              VARCHAR2;
FUNCTION CHECK_DATA_EXISTENCE (
    TABLENAME VARCHAR2,
    COLS VARCHAR2,
    COL_DATA VARCHAR2
)
    RETURN integer;
FUNCTION CONCAT_STRINGS (
    CONCATSTRING VARCHAR2,
    STRING1 clob,
    STRING2 clob,
    STRING3 clob default ''
)
   RETURN CLOB;
FUNCTION MAKE_UPDATE_STATEMENT (
    TABLENAME VARCHAR2,
    WHERELIST CLOB,
    WHEREDATA CLOB,
    COLUMNLIST CLOB,
    DATALIST CLOB
)
   RETURN CLOB;
FUNCTION MAKEUPDATELIST (
    COLS VARCHAR2,
    COL_DATA VARCHAR2,
    JOINTOKEN VARCHAR2 default ','
)
    RETURN CLOB;
FUNCTION GET_DATA_ITEM (
    COL_DATA VARCHAR2,
    JOINTOKEN VARCHAR2 default ',')
    RETURN INTEGER;
PROCEDURE SETPACKAGEVERSION;
FUNCTION GETPACKAGEVERSION
RETURN varchar2;
FUNCTION GETSCHVERSION
RETURN VARCHAR2;
FUNCTION GETPACKAGEREVISION
RETURN varchar2;
FUNCTION GETSCHREVISION
RETURN VARCHAR2;
FUNCTION SETUPHISTORY (
    forceupdate     varchar2     default 'N'
)
RETURN INTEGER;

FUNCTION TODATE (
    DATESTRING Varchar2)
    return date;


PROCEDURE SETDATEFORMAT (
formatString varchar2 default 'MM/DD/YYYY');

END LANDA_CONVERSION;
/
show errors
CREATE OR REPLACE 
PACKAGE LANDA_LOGGING 
AUTHID CURRENT_USER
AS

PROCEDURE SETLOGTABLENAME (tableName varchar2);
PROCEDURE setScriptName (scriptNameIn varchar2);
FUNCTION getLogTableName (tprefix varchar2 default 'SCL')
RETURN varchar2;
FUNCTION getScriptName return varchar2;
PROCEDURE setLoggingDefaults (
    tprefix     varchar2     default 'SCL'
);

PROCEDURE createOrUpdateLoggingTable(
    forceupdate     varchar2     default 'N'
);
PROCEDURE LOG (
    THETEXT                 varchar2 default '',
    THEITEM                 varchar2 default '',
    THESEQUENCE             NUMBER default '',
    THESTATUS               varchar2 default '',
    THESCRIPT               varchar2 default ''
);
PROCEDURE setLog (LACTION varchar2 );
PROCEDURE cleanUpTables_Duplicate_SCL (LandaLogTableName varchar2, tprefix     varchar2     default 'SCL');
PROCEDURE cleanUpTables_Duplicate_SCD ;
PROCEDURE cleanUpTables_deleteDataByDay ( TABLENAME varchar2, COLUMNNAME varchar2 , DAYS integer ,COMPARISON  varchar2) ;
PROCEDURE cleanUpTables_VERSION ( VERSION varchar2 ) ;
PROCEDURE cleanUpTables ( 
    TABLENAME varchar2 default 'ALL',
    CONDITION varchar2 default 'BY DAY',
    COMPARISON varchar2 default '<',    
    DAY_VERSION_DATE varchar2 default 30,
    tprefix     varchar2     default 'SCL'    
);
END LANDA_LOGGING;
/
show errors
