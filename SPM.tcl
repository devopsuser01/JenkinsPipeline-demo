namespace eval ::spm { 
    namespace export setServerName getServerName getRelengString setRelengString getSchemaName
}
#//##########################################################################################################################
#
# SCRIPT NAME   : SPM.tcl
# Schema Pool Maintenance
#
# Author(s)     : Tarun Arya ,Parminder Singh, Anurag Tripathi, Vinay Aswal
#
# Since         : 21 Feb 2017
#
# Last updated  : 18 Aug 2018
#
# Last updated by : Vinay Aswal
#
# PLATFORM      : Windows
#
# INSTRUCTIONS  :
#
# For a brief list of commands, run this script without any arguments.
#
# PURPOSE :
# To make standard schema pool maintenance tasks easier
#
# ADDITIONAL NOTES :
#
# This script is the property of ExlService Technology Solutions, LLC
#
# MODIFICATION LOG
# Who   When        Comments
# ---   ----------  ----------------------------------
# Vinay   10/Oct/2017  No logic change, logs and headers changed as per coding standards
# Vinay   29/Nov/2017  DB name normalization , safeLogon function implemented
# Vinay   29/Jan/2018  Moved CSP table from DB releng_test to DB releng
# Vinay   06/Feb/2018  merged SPM.tcl with validateSchema.tcl
# Vinay   12/Feb/2018   code cleanup
# Vinay   16/Feb/2018   main logic from createSchema.tcl and dropAchema.tcl has been merged to SPM.tcl
# updated the SPM version to 3.4
# Vinay   20/Mar/2018 removed unused code, removed proc getPath
# Vinay   10/April/2018 added dropOrphanSchema proc to drop schema from db09 which are not listed in CSP table
# Vinay   18/Aug/2018 No Logical change ! formatting corrected and logs has been updated as per RE-1255
#
#//##########################################################################################################################

package require otc
package require RE
package require http
package require base64
package require re::pump

#----------Global variables------#
global env
# max schema count for a single version should not exceed 3
set g_maxAllowedSchema 3
set SCHEMAMAXLIFETIME_HOUR 720
global RELENGCONNECTIONSTRING
set RELENGCONNECTIONSTRING ""
set dateToday [clock format [clock seconds] -format %d-%m-%Y]
set dateYesterday [clock format [clock scan "yesterday"] -format %d-%m-%Y ]
set RELIBPATH "$::env(GIT_LOCAL)/tcl-lib/src"
#No more then 60 schema(AVAILABLE+INUSE+PENDING) will be maintained on DB.
set MAXSCHEMAONDB 60
# this limit is used when creating schema locally
set MAXSCHEMAONDB_LOCAL 80
set SPM_JENKINS_SERVER "FRODO"
#----------Global variables END ------#
proc ::spm::getMAXSCHEMAONDB {} {
    return $::MAXSCHEMAONDB
}
proc ::spm::setServerName {server} {
    global SPM_JENKINS_SERVER
    set SPM_JENKINS_SERVER $server
}
proc spm::getServerName {} {
    global SPM_JENKINS_SERVER
    return $SPM_JENKINS_SERVER
}
proc spm::getRelengString {} {
    global RELENGCONNECTIONSTRING
    if {$RELENGCONNECTIONSTRING == ""} {
        set RELENGCONNECTIONSTRING "releng@db08"
    }
    return $RELENGCONNECTIONSTRING
}
proc spm::setRelengString {s} {
    set RELENGCONNECTIONSTRING $s
}
#----------Global variables END ------#

##To run the script in debug mode set environment variable DEBUG to 1
if { [ info exists env(DEBUG) ] == 1 } {
    set DEBUG $env(DEBUG)
} else  {
    set DEBUG 0
}

## this Proc is responsible to input the logs to file
# logging is off by default
# logs will ve created only when script is running in debug mode
# location will be <windows tmp dir>/SPM_LOGS
# call the function fileLog without any arguments to get the logs path
# @author   Vinay Aswal
# @return nothing
proc fileLog { {text ""} } {
    global env
    global DEBUG

    if {[info exists env(TEMP)]} {
        set tmpDir $env(TEMP)
    } else {
        puts "Error : No temporary directory found "
        return -1
    }

    regsub -all {\\} $tmpDir "/" tmpDir
    set SPMlogDir $tmpDir/SPM_LOGS/

    #if log directory doesn't exist, create it
    if { ![ file exists $SPMlogDir] } {
        file mkdir $SPMlogDir
    }

    #returning log directory path
    if {$text == ""} {
        puts_debug "SPM log directory is $SPMlogDir"
        return $SPMlogDir
    }

    #logging is only done when running the script in debug  mode
    if {$DEBUG == 1} {
        set fp [open $SPMlogDir/SPM_$::dateToday.log a+]
        puts $fp "[clock format [clock seconds] -format %d/%m/%Y-%H:%M:%S]: $text"
        close $fp
    }
}

## <B>
# Proc for information logging. This proc will fromat the common log messages and display them on prompt.
# @param    text: text to be logged
# @return   Nothings
proc puts_info {text} {
    global DEBUG
    puts "INFO: $text"

    if {$DEBUG == 1} {
        fileLog "INFO: $text"
    }
}

## <B>
# proc for providing error messages. proc can format the text before printing to screen or log file
# </B>
# @author   Vinay Aswal
# @param    text: text to be logged
# @return   nothing
proc puts_error {text} {
    global DEBUG
    puts "----------------------------------------"
    puts "ERROR: $text"
    puts "----------------------------------------"

    if {$DEBUG == 1} {
        fileLog "ERROR: $text"
    }
    #here we can add file log options in future if needed
}

## <B>
# puts_debug will put logs on screen as well as on a log if environment variable DEBUG is set to 1
# </B>
# @author   Vinay Aswal
# @param    text: text to be logged
# @return   nothing
proc puts_debug {text} {
    global DEBUG
    if {$DEBUG == 1} {

        puts "DEBUG INFO: $text"
        fileLog "DEBUG INFO: $text"
    }
    return 0
}

## <B>
# puts_warning will put logs on screen as well as on a log if environment variable DEBUG is set to 1
# </B>
# @author   Vinay Aswal
# @param    text: text to be logged
# @return   nothing
proc puts_warning {text} {
    global DEBUG
    puts "----------------------------------------"
    puts "WARNING: $text"
    puts "----------------------------------------"

    if {$DEBUG == 1} {
        fileLog "WARNING: $text"
    }
}

## <B>
# this Proc is responsible for cleaning up debug logs in nightly Jenkins job
# note: logging to file is off by default. if you want to enable it , please set the environment variable DEBUG to 1
# </B>
# @author   Vinay Aswal
# @return   nothing
proc cleanupLogs {} {
    puts_debug "inside proc [info level 0]"

    # get the log path
    set SPMlogDir [fileLog]
    set currDir [pwd]
    puts_debug "[info level 0]: SPM log directory is $SPMlogDir"
    cd $SPMlogDir

    set fileList [glob -nocomplain SPM_*.log]
    # set fileList [list $fileList]

    regsub -all "SPM_$::dateToday.log" $fileList "" fileList
    regsub -all "SPM_$::dateYesterday.log" $fileList "" fileList

    puts_debug "logs found : $fileList"

    foreach file $fileList {
        puts_info "removing log $SPMlogDir/$file"
        file delete $file
    }
    cd $currDir
}

## <B>
# The function poolDBSync will list all the schemas from DB pool with status "AVAILABLE" and check them for validity.
# Invalid schema will be dropped by validateSchema proc.
# </B>
# @author   Vinay Aswal
# @param    poolDBserver poll db derver short name , db09
# @param    tdbh data base handle for table DB server
# @return   or -1(error) or 0(no error)
proc poolDBSync {poolDBserver tdbh } {
    puts_debug "inside proc [info level 0]"
    # checking DB handle validity
    if { [checkDBHandle $tdbh ] < 0 } {
        puts_error "Database handle invalid !!"
        return -1
    }

    set availableSchemaQuery "select CSP_SCHEMA_NAME, CSP_SERVER_TNS into :schemaList, :dbList from CSP_CONVERSION_SCHEMA_POOL where CSP_STATUS = 'AVAILABLE'"

    catch {execsql use $tdbh $availableSchemaQuery} Queryresult

    puts_debug "$schemaList $Queryresult"

    foreach schemaName $schemaList poolDBserver $dbList {
        set sql "select CSP_SCHEMA_NAME, CSP_STATUS into :availableSchema, :status
        from CSP_CONVERSION_SCHEMA_POOL
        where CSP_STATUS = 'AVAILABLE'
        and CSP_SCHEMA_NAME = '$schemaName'
        and CSP_SERVER_TNS = '$poolDBserver'
        and rownum <= 1
        for update skip locked"
        catch {execsql use $tdbh $sql} err
        if {$err != 0} { 
            execsql use $tdbh "commit"
        } else {
            execsql use $tdbh "Update CSP_CONVERSION_SCHEMA_POOL set CSP_STATUS = 'LOCKED', CSP_LAST_USED = sysdate  where CSP_SCHEMA_NAME = '$schemaName' and CSP_SERVER_TNS = '$poolDBserver'"
            execsql use $tdbh "commit"
            if {[validateSchema $poolDBserver $schemaName] == 0} { 
                set sql "Update CSP_CONVERSION_SCHEMA_POOL set CSP_STATUS = '$status', CSP_LAST_USED = '' where CSP_SCHEMA_NAME = '$schemaName' and CSP_SERVER_TNS = '$poolDBserver'"
                execsql use $tdbh $sql
                execsql use $tdbh "commit"
            } else {
                setSchemaToBeDropped $schemaName $poolDBserver
            }
        }
    }
    return 0
}

## <B>
## This function is responsible of validating schemas i.e. checking the schemas for availability by logging in schemas
# The function validateSchema will internally call proc dropSchema() to drop invalid schema.
# Also look DropSchema.tcl
# </B>
# @author   Vinay Aswal
# @param    poolDBserver poll db derver short name , db09
# @param    schemaName schema name to be validated
# @param    schemaPWD schema password (Optional)
# @return   or -1(error) or 0(no error)
proc validateSchema {poolDBserver schemaName {schemaPWD ""} } {
    puts_debug "inside proc [info level 0]"
    set max 0
    set retval 0
    # extracting schema version from name
    # exa: 02020400 from CRPOOL02020400_1096
    regsub {CRPOOL} $schemaName "" version
    regsub {_.*} $version "" version

    if {$schemaPWD == ""} {
        #setting default schema password
        set schemaPWD $schemaName
    }
    # puts_debug "Checking schema $schemaName for validity"
    set status [catch {safeLogon $schemaName/$schemaPWD@$poolDBserver } dbh]
    # Check the return status of logon command
    if {$dbh == -1} {
        puts_error "unable to connect to DB $poolDBserver !! please check the DB server entered."
        logoff $dbh
        return -1
    } elseif {$status == 1 || $dbh < 0 } {
        puts_error "Unable to login on schema $schemaName on server $poolDBserver!! Dropping invalid schema "
        logoff $dbh
        #Calling function setSchemaToBeDropped from SPM to drop the invalid schema
        catch [ setSchemaToBeDropped $schemaName $poolDBserver ] commandResult
        # the return status will be used in SPM to determine if the schema was valid or not
        # -1 schema was invalid and had been dropped
        # 0 schema is valid
        set retval -1
    } else {
        set sql "select max(shs_version_new) into :max from shs_schema_history"
        #catch block here for the case execution of sql failed
        catch { execsql use $dbh $sql} err
        if {$err != 0 } {
            # if error encountered while executing SQL
            puts_error "No shs_schema_history table found for schema $schemaName , Dropping invalid schema !! "
            puts_debug "Status for the last sql , error is $err "
            setSchemaToBeDropped $schemaName $poolDBserver
            set retval -1
        } else {
            # check that the advertised version matches the actual version from the schema name
            set shs_version [join [split $max "."] ""]
            puts_debug "real version : $shs_version, advertised version $version"
            if {![regexp $shs_version $version]} {
                # schema is invalid
                puts_error "schema $schemaName : real version $shs_version does not match with advertised version $version, dropping schema $schemaName on $poolDBserver !!"
                # drop the schema
                setSchemaToBeDropped $schemaName $poolDBserver
                set retval -1
            } else {
                puts_debug "schema $schemaName is valid"
                set retval 0
            }
        }
    }
    logoff $dbh
    return $retval
}

## <B>
# This function is responsible for getting a valid schema name from schemaPool.
# The schema will be validated before returning the schema name
# Returns : returns schema name or "-1"
# </B>
# @author   Tarun Arya / Vinay Aswal
# @param    version schema version
# @param    poolDBserver pool deb short name
# @param    tdbh data base handle for table DB server
# @return   -1(error) or 0(no error)
proc getAvailableSchema {version tdbh {poolDBserver "db09"}} {
    puts_debug "inside proc [info level 0]"

    # checking DB handle validity
    if { [checkDBHandle $tdbh ] < 0 } {
        puts_error "Database handle invalid !!"
        return -1
    }
    set availableSchema "-1"
    if {$version == "" } {
        puts_error "please provide version information"
        # show usages and return
        return -1
    }
    execsql use $tdbh "commit"
    if {$version == "*"} {
        set sql "select CSP_SCHEMA_NAME, CSP_VERSION into :availableSchema, :version
        from CSP_CONVERSION_SCHEMA_POOL
        where CSP_STATUS = 'AVAILABLE'
        and CSP_SERVER_TNS = '$poolDBserver'
        and rownum <= 1
        for update skip locked"
    } else {
        set sql "select CSP_SCHEMA_NAME into :availableSchema
        from CSP_CONVERSION_SCHEMA_POOL
        where CSP_STATUS = 'AVAILABLE'
        and CSP_VERSION = '$version'
        and CSP_SERVER_TNS = '$poolDBserver'
        and rownum <= 1
        for update skip locked"
    }
    catch {execsql use $tdbh $sql} err
    
    puts_debug "[info level 0]: sql $sql returned error : $err"

    if {$err == -1 || $err == 100 } {
        puts_warning "No ready-made schema found in schemaPool for version $version on server $poolDBserver"
        execsql use $tdbh "commit" ;# release lock on table
        return -1
    }
    execsql use $tdbh "Update CSP_CONVERSION_SCHEMA_POOL set CSP_STATUS = 'LOCKED', CSP_LAST_USED = sysdate  where CSP_SCHEMA_NAME = '$availableSchema' and CSP_SERVER_TNS = '$poolDBserver'"
    execsql use $tdbh "commit"
    # Checking Schema validity for $availableSchemsa
    puts_info "validating schema $availableSchema on server $poolDBserver "
    if { [validateSchema $poolDBserver $availableSchema ] == "0" } {
        puts_debug "[info level 0] : schema $availableSchema is valid"
        updateRelengEntry $availableSchema "INUSE" $tdbh $poolDBserver
        execsql use $tdbh "commit"
    } else {
        execsql use $tdbh "commit" ;# release lock on table
        setSchemaToBeDropped $availableSchema $poolDBserver
        puts_error "schema $availableSchema is invalid, calling getAvailableSchema again"
        set lastSchema $availableSchema
        ## pause for 10 seconds and wait for status change of invalid schema or you might get the same schema again.
        # call getAvailableSchema again to get a valid schema name from schemaPool
        set availableSchema "-1"
        after 10000
        # TODO: this might stuck in infinite loop, confirm
        # getAvailableSchema will either return schema name or -1
        set output [catch {getAvailableSchema $version $tdbh $poolDBserver} availableSchemas ]
        set availableSchema [lindex $availableSchemas 0]
        set version [lindex $availableSchemas 0]
        puts_debug "after calling getAvailableSchema again output : $output , availableSchema : $availableSchema"
        if {$availableSchema == $lastSchema} {
            error "Caught in a loop: got the same invalid schema again"
        }
    }
    puts_info $availableSchema
    return [list $availableSchema $version]
}

## <B>
# The function is responsible for changing the status of a schema in CSP table
# </B>
# @author   Tarun Arya / Vinay Aswal
# @param    schemaName  name of the schema for which staus is being changed
# @param    poolDBserver (poolDBserver)     short db name for pool DB server, db09
# @param    status               new status for the schema
# @param    tdbh               data base handler for DB releng (where CSP table resides)
# @param    lifeTimeHour   default life time for a schema is 24 hours (1 day), after 24 hours schema will be dropped
# @return   Nothing             The function maintains the schema pool, does not return anything
proc updateRelengEntry { schemaName  status tdbh { poolDBserver "db09" } {lifeTimeHour "24"} } {
    puts_debug "inside proc [info level 0]"
    set result ""

    #checking DB handle validity
    if { [checkDBHandle $tdbh ] < 0 } {
        puts_error "Database handle invalid !!"
        return -1
    }

    #removed: if already locked, it will get skipped: double check if the schema is there and lock the row before updating

    # checking if the status is valid for the schema
    if { [ p_statusChangeControl $schemaName $status $tdbh ] ==  -1 } {
        puts_error "status is invalid for schema ! could not change status of schema $schemaName !!"
        return -1
    }

    if { $status == "INUSE" } {
        # CSP_LAST_USED = sysdate + lifetime
        set SQL_Statement "update CSP_CONVERSION_SCHEMA_POOL
        set CSP_STATUS = '$status',
        CSP_LAST_USED = SYSDATE + interval '$lifeTimeHour' Hour
        where CSP_SCHEMA_NAME = '$schemaName'
        and CSP_SERVER_TNS = '$poolDBserver' "
    } elseif { $status == "DROPPING" } {
        # CSP_LAST_USED = sysdate
            set SQL_Statement "update CSP_CONVERSION_SCHEMA_POOL
            set CSP_STATUS = '$status',
            CSP_LAST_USED = SYSDATE
            where CSP_SCHEMA_NAME = '$schemaName'
            and CSP_SERVER_TNS = '$poolDBserver' "
    } else {
        # if status is PENDING/AVAILABLE/DROPPED do not update CSP_LAST_USED date
        set SQL_Statement "update CSP_CONVERSION_SCHEMA_POOL
        set CSP_STATUS = '$status'
        where CSP_SCHEMA_NAME = '$schemaName'
        and CSP_SERVER_TNS = '$poolDBserver' "
    }

    puts_debug "[info level 0]: updating schema $schemaName as $status on server $poolDBserver"
    catch {execsql use $tdbh $SQL_Statement} result 

    catch {execsql use $tdbh "COMMIT"} res2
    if {$result != 0 || $res2 != 0} {
        puts_error "Unable to change the status of schema $schemaName!! $result"
        return -1
    }
    puts_debug "[info level 0]: sql query results $result $res2"
    
    return $result
}

## <B>
# The function is responsible for dropping the schema no longer needed.
# Jenkins job dropSchema will be called to drop the schema
# </B>
# @author   Parminder Singh / Vinay Aswal
# @param    schemaName list of version needs to be maintained
# @param    poolDBserver        short db name for pool DB server
# @param    tdbs                data base handler for DB releng
# @return   Nothing             The function maintains the schema pool, does not return anything
proc setSchemaToBeDropped {schemaName {poolDBserver ""} {tdbs "" } {lifeTimeHour "1" }  } {
    if {$tdbs == ""} {
        set tdbs [spm::getRelengString]
    }
    puts_debug "inside proc [info level 0]"
    set status ""

    # TODO  : check if provided DB server names have only tns , else show usage.

    # find server here from sql
    set tdbh [safeLogon $tdbs ]
    if {$tdbh == -1 } {
        puts_error "Unable to connect to DB $tdbs"
        logoff $tdbh
        return -1
    }

    if {$poolDBserver == ""} {
        set SQL_Statement "select CSP_SERVER_TNS, CSP_STATUS into :poolDBserver, :status from CSP_CONVERSION_SCHEMA_POOL
        where CSP_SCHEMA_NAME = '$schemaName' for update skip locked "

    } else {
        set SQL_Statement "select CSP_STATUS into :status from CSP_CONVERSION_SCHEMA_POOL
        where CSP_SCHEMA_NAME = '$schemaName' for update skip locked "
    }

    catch {execsql use $tdbh $SQL_Statement} result

    if {$poolDBserver == "" || $status == ""} {
        puts_error "Could not find server details for schema $schemaName!! Schema not available or locked"
        execsql use $tdbh "commit"
        logoff $tdbh
        return -1
    }

    puts_warning "Adding schema $schemaName to dropList !!!"
    set status [updateRelengEntry $schemaName "DROPPING" $tdbh $poolDBserver]
    execsql use $tdbh "commit"
    if {$status == -1} {
        puts_error "Could not update status of schema $schemaName"
        logoff $tdbh
        return -1
    }
    logoff $tdbh
    return 0
}

proc getAvalailableSchemasForVersions {dbh versionList {poolDBserver db09} {mask ""}} {
    set availableSchemaVersionList ""
    array set arrayVals ""
    if {$mask != ""} {
        set sql "select CSP_VERSION, CSP_SERVER_TNS
        into :availableSchemaVersionList, :poolServers
        from CSP_CONVERSION_SCHEMA_POOL, DFL_DUMP_FILE_LIST 
        where CSP_VERSION like ('$mask')
        and CSP_STATUS = 'AVAILABLE'
        and CSP_SERVER_TNS like '$poolDBserver'
        and DFL_VERSION = CSP_VERSION
        order by CSP_VERSION desc"
    } else {
        set sql "select CSP_VERSION, CSP_SERVER_TNS
        into :availableSchemaVersionList, :poolServers
        from CSP_CONVERSION_SCHEMA_POOL, DFL_DUMP_FILE_LIST 
        where CSP_VERSION in ('[join $versionList "','"]')
        and CSP_STATUS = 'AVAILABLE'
        and CSP_SERVER_TNS like '$poolDBserver'
        and DFL_VERSION = CSP_VERSION
        order by CSP_VERSION desc " 
    }
    execsql use $dbh $sql
    foreach v $availableSchemaVersionList p $poolServers {
        set arrayVals($v) $p
    }
    # puts $availableSchemaVersionList
    return [array get arrayVals]
}
## <B>
# this proc can be used to list all the available schema
# </B>
# @author   Vinay Aswal
# @param    versionList         list of version needs
# @param    poolDBserver        short db name for pool DB server
# @param    tdbs                data base handler for DB releng
# @return   list of available schema
proc getSchemasForVersions {versionList {poolDBserver "db09"} {tdbs ""}} {
    puts_debug "inside proc [info level 0]"
    if {$tdbs == ""} {
        set tdbs [spm::getRelengString]
    }
    set availableSchemaVersionList "-1"
    set commandResult ""
    set Queryresult "-1"
    set totalCount "0"

    set status [catch {safeLogon $tdbs } tdbh ]

    if {$status == 1 || $tdbh == -1 } {
        puts_error "Unable to connect to server $tdbs, Check the server details !!"
        logoff $tdbh
        return -1
    }

    # Check the return status of logon command
    if { $tdbh == -2 } {
        puts_error "Unable to login on on server $tdbs, check the user credentials !!"
        logoff $tdbh
        return -1
    }

    if { [ regsub -all {[^0-9 ,]+} $versionList {} versionList ] } {
        puts_warning "No special characters allowed ! removing alphabets and special characters !!! "

    }
    regsub -all {^[ ,]+|[ ,]+$} $versionList {} versionList
    regsub -all {[ ,]+} $versionList {,} versionList

    set sqlQuery "select CSP_VERSION, count(*) into :availableSchemaVersionList, :totalCount
    from CSP_CONVERSION_SCHEMA_POOL
    where CSP_VERSION in ($versionList)
    and CSP_STATUS = 'AVAILABLE'
    and CSP_SERVER_TNS = '$poolDBserver'
    group by CSP_VERSION
    order by CSP_VERSION "

    catch { execsql use $tdbh $sqlQuery } Queryresult
    puts_debug "availableSchemaVersionList $availableSchemaVersionList totalCount $totalCount Queryresult $Queryresult"

    if {$Queryresult == -1 || $Queryresult == 100} {
        puts_warning "No available schema found for version(s) $versionList"
        set availableSchemaVersionList "-1"
    }

    logoff $tdbh
    return  $availableSchemaVersionList
}

## <B>
# This proc is responsible for calling Jenkins job to maintain schema version
# </B>
# @author   LAQ
# @param    url         list of version needs
# @param    user        username for jenkins server
# @param    passwd      token to run the job on Jenins Server
# @param    jobPath     job name to run
# @param    params      parameters for the Jenkins job
# @return   nothing
proc startJenkinsJob {url user passwd jobPath params} {
    # need to grab a "crumb" with Jenkins 2.0+ - hence the call to crumbIssuer
     if {$params != {}} {
        append jobPath /buildWithParameters
    }
    set header  [list Host $url/crumbIssuer/api/xml Authorization "Basic [base64::encode $user:$passwd]"]
    set query ""
    foreach {name value} $params {
        regsub -all {[\s]} "$name=$value" "%20" q
        lappend query $q
    }
    set query [join $query "&"]
    catch {http::geturl $url/ -headers $header } token
    # note: state is an array
    # need to parse the crumb out: todo there is supposed to be a way to xpath directly to the token (in the get) but i could not get it to work
    upvar #0 $token state
    # puts $state(body)
    regexp {\("Jenkins-Crumb",.*?"\)} $state(body) crumb ;#"
    regsub -all {\(|\)|"|,} $crumb "" crumb ;#"
    set crumb [lindex [split $crumb] 1]
    # puts $url/$jobPath/buildWithParameters
    # now we can make the call using the crumb - not that you still need to send authentication
    set header [list Host $url/api/xml Authorization "Basic [base64::encode $user:$passwd]" Jenkins-Crumb $crumb]
    catch {http::geturl $url/$jobPath -headers $header -query $query} token
    # upvar #0 $token state
    # puts $state(body)
    # puts http-$state(http)
    return 0
}

## <B>
# This proc is responsible for setting up parameters for Jenkins job calling
# </B>
# @author   LAQ
# @param    build      Jenkins job name to run
# @param    args       parameters for the Jenkins job
# @return   -1 if failed to run Jenkins job, else 0
proc callJenkinsJob {build args}  {
    if {[spm::getServerName] == "FRODO"} {
        puts_debug "Jenkins Server is FRODO"
        # Jenkins server is cic-re-frodo.corp.exlservice.com [10.157.201.14]
        set url     "http://10.157.201.14:8080"
        set user    reservice
        set passwd  6ab31e98924cf5086d36f0e8652bee32
    } elseif {[spm::getServerName] == "SAURON"} {
        puts_debug "Jenkins Server is SAURON"
        set url     "http://10.157.201.138:8080"
        set user    reservice
        set passwd  6ab31e98924cf5086d36f0e8652bee32
    }
    puts_debug "starting Jenkins Job with parameters $url $user $passwd $build [join $args]"
    catch {startJenkinsJob $url $user $passwd $build [join $args]} err
    if {$err != 0} {
        puts_debug "$err"
    } 
    return $err
}

## <B>
# function getSchema is responsible for finding a requested schema from schema pool or create a new one if needed
# default schema life time is 24 hours (one day)
# </B>
# @author   Tarun Arya / Vinay Aswal
# @param    versions            version or list of version
# @param    poolDBserver        short db name for pool DB server
# @param    tdbs                data base handler for DB releng
# @param    lifeTimeHour        schem life time
# @return   available schema or first available schema from passed list
proc getSchema {versions {poolDBserver "db09"} {lifeTimeHour "24" } {tdbs ""} {createLocally "Y" } }  {
    puts_debug "inside proc [info level 0]"
    set maxlifeTimeHour $::SCHEMAMAXLIFETIME_HOUR
    set commandResult ""
    set result "-1"
    set availableSchema ""
    if {$tdbs == ""} {
        set tdbs [spm::getRelengString]
    }
    if {$lifeTimeHour > $maxlifeTimeHour } {
        puts_warning "Maximum allowed lifetime for schema is $maxlifeTimeHour Hours ([expr $maxlifeTimeHour / 24] days) only !! changing life time to [expr $maxlifeTimeHour / 24] days"
        set lifeTimeHour $maxlifeTimeHour
    }
    set status [catch {safeLogon $tdbs } tdbh ]

    if {$status == 1 || $tdbh == -1 } {
        puts_error "Unable to connect to server $tdbs, Check the server details !!"
        logoff $tdbh
        return -1
    }
    # Check the return status of logon command
    if { $tdbh == -2 } {
        puts_error "Unable to login on on server $tdbs, check the user credentials !!"
        logoff $tdbh
        return -1
    }

    # TODO : check if provided DB server names have only tns , else show usage.

    ## the Proc getAvailableSchema() will be called to get a schema name from pool
    # This will return a availableSchema name
    foreach version $versions {
        set result [getAvailableSchema $version $tdbh $poolDBserver]
        if {$result != -1} {
            # Pass this schema to runConversion/unitTest
            set availableSchema [lindex $result 0]
            set version [lindex $result 1]
            puts_info "available Schema for version $version is $availableSchema"
            break
        } else {
            execsql use $tdbh "commit" ;#release lock
        }
    }

    #no schema was available in pool, now creating a new schema locally
    if {$result == -1} {
        puts_info "No schema for version $version is available, Creating a new Schema"
        # calling function createSch to create a new schema
        if {$createLocally == "N"} {
            set status [ catch { createSchema $version $poolDBserver $tdbs "N" } newSchema ]
        } else {
            set status [ catch { createSch $version $tdbs $poolDBserver } newSchema ]
        }
        puts_debug "[info level 0]: new schema: $newSchema status $status"

        if {$status == 1 || $newSchema == -1 } {
            puts_error "Could not create schema for version $version"
            logoff $tdbh
            return -1
        } else {
            puts_info "$newSchema"
            set availableSchema $newSchema
        }
        execsql use $tdbh "commit" ;#release lock
    } else {
        set result [updateRelengEntry $availableSchema "INUSE" $tdbh $poolDBserver $lifeTimeHour]
        if {$result == -1} {
            # return the schema for use anyway
            puts_error "Could not update status of schema $availableSchema"
            execsql use $tdbh "commit" ;#release lock
        }
    }
    execsql use $tdbh "commit" ;#release lock
    
    puts_info $availableSchema
    logoff $tdbh
    return $availableSchema
}


## before creating a schema we are checking dmp file existence here
# @author Vinay Aswal
# @param basefile dmp file name
# @param tdbs SCP table credentials
# @return 0 when dump file is available in DFL table else -1
proc checkDmp { version tdbh } {
    puts_debug "inside proc [info level 0]"
    puts_debug " version is $version"
    set dmpFileName ""
    puts_debug "checking dump file for existence"
    set baseDmpQuery "select DFL_NAME into :dmpFileName from DFL_dump_file_list where DFL_VERSION = '$version'"
    set status [ catch {execsql use $tdbh $baseDmpQuery} Queryresult]
    if {$Queryresult == -1 || $Queryresult == 100 || $dmpFileName == "" || $status < 0 } {
        puts_warning "No dump file $dmpFileName.dmp found for version $version in table DFL_dump_file_list, Please check the version again !"
        return -1
    }
    puts_debug "dump file $dmpFileName found for version $version"
    return [lindex $dmpFileName 0]
}

## the proc is responsible for creating schema by calling either Jenkins job or script createSchema.tcl locally to create schema.
# @author Tarun Arya / Vinay Aswal
# @param version version of the schema to be created
# @param poolDBserver DB server name where pool is created
# @param tdbs DB server creadentials where SCP table resides
# @param silent weather to create schema locally or on server (Takes "Y" or "N" as options)
# @return Created schema name or -1 if operation fails
proc createSchema {version {poolDBserver "db09"} {tdbs ""} {silent "N"}} {
    puts_debug "inside proc [info level 0]"
    if {$tdbs == ""} {
        set tdbs [spm::getRelengString]
    }
    set scriptOutput ""
    set schemaName ""
    set dmpFileName ""
    catch {safeLogon $tdbs } tdbh
    if {$tdbh == -1 } {
        logoff $tdbh
        return -1
    }
    if {[checkDmp $version $tdbh] == ""} {
        logoff $tdbh
        return -1
    }
    if { [pingDBinstance $poolDBserver] != 0 } {
        puts_error "Unable to connect to server $poolDBserver , please check the server entered !!"
        logoff $tdbh
        return -1
    }
    logoff $tdbh
    if {$silent == "Y"} {
        set maxSchemaLimit $::MAXSCHEMAONDB
    } else {
        set maxSchemaLimit $::MAXSCHEMAONDB_LOCAL
    }

    #count all CRPOOL* schema and stop creation of new schema if exceeds max allowed schema
    set schemaAndcount [allPresentSchemaOnDB $poolDBserver]
    set allSchemaCount [lindex $schemaAndcount 0]
    puts_debug "count $allSchemaCount, schema names [lindex $schemaAndcount 1]"

    if { $allSchemaCount >= $maxSchemaLimit } {
        puts_error "Max schema count exceeded!! $allSchemaCount schema present on DB $poolDBserver. No new schema will be created for version $version. Please contact your Admin !!"
        return -1
    }
    if {$silent == "Y"} {
        # launch_build.tcl will execute the Jenkins job 
        catch {callJenkinsJob job/RE/job/dash/job/createSchema "version $version" "poolDBserver $poolDBserver" "tdbs $tdbs" } schemaName
        if {$schemaName != 0} {
            puts_error "Jenkins job could not create schema for version $version.  Check the jenkins builds.!!"
        } 
    } else {
        set schemaName  [createSch $version $tdbs $poolDBserver ]
        puts_debug "Available schema name is $schemaName "
        puts_info "$schemaName"
        if {$schemaName == -1 } {
            puts_warning "Could not create schema for version $version"
        }
    }
    return $schemaName
}

##will calculate and return the count of schemas available
# @author   Vinay Aswal
# @param    version schema version
# @param    tdbh DB handle
# @return   Count of perticualr schema found available in SCP table
proc countOfSchemas {version tdbh } {
    set count 0
    set totalSchema ""
    set basefile "BASE_CR$version"

    puts_debug "Counting number of schemas for version $version"

    set numberOfAvailableSchema "select CSP_SCHEMA_NAME into :totalSchema from CSP_CONVERSION_SCHEMA_POOL where CSP_STATUS = 'AVAILABLE' and CSP_VERSION = '$version'"

    catch {execsql use $tdbh $numberOfAvailableSchema} result1

    puts_debug "result from total schema query is $result1"

    set count [llength $totalSchema]

    puts_debug "found $count schema(s) AVAILABLE for version $version , names are $totalSchema , last command status is $result1"

    return $count
}

## <B>
# cleanUpCSP proc is responsible for cleaning up CSP table by marking schema "DROPPING" based on rules:
# 1) schemas in "PENDING" state for more then 1 Hour
# 2) schemas in "INUSE" state for more then 1 Day/Or specified in LAST_USED
# 3) delete all entries from CSP table for "DROPPED" schemas older then 1 Hour
# schema which are marked "DROPPING" will be dropped by schemapoolmanager
# </B>
# @author   Anurag Tripathi / Vinay Aswal
# @param    poolDBserver        short db name for pool DB server
# @param    tdbh               data base handler for DB releng
# @return   Nothing
proc cleanUpCSP {tdbh {poolDBserver "db09"}} {
    puts_debug "inside proc [info level 0]"

    set schemaList ""
    set serverList ""
    set schemaName ""
    set server ""
    set result ""

    #checking DB handle validity
    if { [checkDBHandle $tdbh ] < 0 } {
        puts_error "Database handle invalid !!"
        return -1
    }

    puts_info "Cleanup in progress, please wait..."
    set availableSchemaQuery "select CSP_SCHEMA_NAME, CSP_SERVER_TNS , CSP_PASSWORD into :schemaList , :serverList , :passwords from CSP_CONVERSION_SCHEMA_POOL where CSP_STATUS in ('INUSE','AVAILABLE','DROPPING')"

    catch {execsql use $tdbh $availableSchemaQuery} Queryresult

    foreach schemaName $schemaList server $serverList password $passwords {
        set err [safeLogon $schemaName/$password@$server]
        catch {logoff $err}
        if {$err == -2} {
            set SQL_Statement_delete "delete from CSP_CONVERSION_SCHEMA_POOL where CSP_SCHEMA_NAME = '$schemaName'"
            catch {execsql use $tdbh $SQL_Statement_delete} result
            catch {execsql use $tdbh commit}
            puts "removed dead entry for $schemaName from csp table as schema does not exist."
        } 
    }
    #------------------------------------
    # Cleanup Logic :
    # 1) dropping all schemas with status INUSE and last used date is less then current time (CSP_LAST_USED is more of an expiry date)
    # 2) schemas which are in pending state since 1 Hour are being dropped here
    # 3) after 30 days (720 Hours) all available schema will be dropped.
    set SQL_Statement " SELECT CSP_SCHEMA_NAME, CSP_SERVER_TNS into :schemaList, :serverList
    from (
        select CSP_SCHEMA_NAME, CSP_SERVER_TNS
        from CSP_CONVERSION_SCHEMA_POOL
        where CSP_LAST_USED <= SYSDATE
        and csp_status = 'INUSE'
        union
        select CSP_SCHEMA_NAME, CSP_SERVER_TNS
        from CSP_CONVERSION_SCHEMA_POOL
        where CSP_CREATE_DATE <= SYSDATE - interval '1' Hour
        and  csp_status = 'PENDING'
        union
        select CSP_SCHEMA_NAME, CSP_SERVER_TNS
        from CSP_CONVERSION_SCHEMA_POOL
        where CSP_LAST_USED <= SYSDATE - interval '1' Hour
        and  csp_status = 'LOCKED'
        union
        select CSP_SCHEMA_NAME,CSP_SERVER_TNS
        from CSP_CONVERSION_SCHEMA_POOL
        where CSP_CREATE_DATE <= SYSDATE - interval '720' hour
        and CSP_STATUS = 'AVAILABLE'
      ) "

    set status [catch {execsql use $tdbh $SQL_Statement} result ]

    puts_debug "ran $SQL_Statement \n result from sql is : $result with return status :$status \n schemaList $schemaList serverList $serverList  "
    if {$result == 100 } {
        puts_info "No old schema found to be dropped  ! DB is clean!!"
    }

    foreach schemaName $schemaList server $serverList {
        puts_info "As per clean-up rules adding schema $schemaName to dropList"
        set status [updateRelengEntry $schemaName "DROPPING" $tdbh $server]

        if {$status == -1} {
            puts_error "Could not update status of schema $schemaName"
            return $status
        }
    }

    set deleteSchemaNames ""
    #------------------------------------
    # delete all entries which are older then 1 hour from CSP tble for the dropped schemas
    puts_info "deleting entries for dropped schemas from CSP table older then 1 Hour"
    set SQL_schema_delete_names "select CSP_SCHEMA_NAME into :deleteSchemaNames from CSP_CONVERSION_SCHEMA_POOL
        where CSP_STATUS = 'DROPPED' and CSP_LAST_USED <= SYSDATE - interval '1' hour for update skip locked"
    catch {execsql use $tdbh $SQL_schema_delete_names} result

    foreach schemaname $deleteSchemaNames {
        set SQL_Statement_delete "delete from CSP_CONVERSION_SCHEMA_POOL where CSP_SCHEMA_NAME = '$schemaname'"
        set output [ catch {execsql use $tdbh $SQL_Statement_delete} result ]
        puts_debug "sql $SQL_Statement_delete result $result output $output"

    }
    catch {execsql use $tdbh "COMMIT"} result
    if {$result != 0 } {
        puts_error "Unable to update the table : $result"
        return -1
    }

    return 0
}

#usase : will show a syntax to use this file
proc usage {} {

    puts "This script contains the procedure getSchema and setSchemaToBeDropped which can be used to :"
    puts "--------------------------------"
    puts "get a schema"
    puts "--------------------------------"
    puts "\texa: getSchema <schema version>"
    puts "\texa: etSchema <schema version> <server>"
    puts "--------------------------------"
    puts "drop a schema"
    puts "--------------------------------"
    puts "\texa: setSchemaToBeDropped <schema version>"
    puts "\texa: setSchemaToBeDropped <schema version> <server>"
    puts "--------------------------------"
    puts "to find the location of SPM logs"
    puts "--------------------------------"
    puts "\texa: fileLog"

}

## Drop excess schemas from DB here
# more than 3 schema for a perticular version will be dropped here
# @author   Vinay Aswal
# @param tdbh DB handle
# @param poolDBserver name of the pool db
# @param maxAllowedSchema maximum number of schema present on pool db
# @return 0 when operation was sucessful or else -1
proc dropExcessSchemas { tdbh {poolDBserver "db09"} maxAllowedSchema  } {
    puts_debug "inside proc [info level 0]"

    set tnsList ""
    set versionList ""
    set statusList ""
    set countList ""
    set schemaList ""

    set sqlStatement "select CSP.CSP_SERVER_TNS ,
    CSP.CSP_VERSION ,
    CSP.CSP_STATUS ,
    count (*) ,
    LISTAGG(CSP.CSP_SCHEMA_NAME, ',') WITHIN GROUP (ORDER BY CSP.CSP_SCHEMA_NAME)
    into :tnsList, :versionList , :statusList , :countList , :schemaList
    from CSP_CONVERSION_SCHEMA_POOL CSP
    where CSP.CSP_STATUS = 'AVAILABLE'
    having count(*) > $maxAllowedSchema
    group by CSP.CSP_VERSION, CSP.CSP_SERVER_TNS, CSP.CSP_STATUS
    order by count (*) desc"

    #checking DB handle validity
    if { [checkDBHandle $tdbh ] < 0 } {
        puts_error "Database handle invalid !!"
        return -1
    }

    puts_debug "running $sqlStatement"
    catch {execsql use $tdbh $sqlStatement} output

    puts_debug "output $output tnsList $tnsList versionList $versionList statusList $statusList countList $countList"
    puts_info "Dropping excess available schemas , i.e. versions which have more then $maxAllowedSchema schemas available "

    puts_debug "\n tns $tnsList \n version $versionList \n status $statusList \n count $countList \n schemaNames $schemaList"

    foreach tns $tnsList version $versionList status $statusList count $countList schemaNames $schemaList {
        regsub -all "," $schemaNames " " schemaNames
        set schemaNames [lsort $schemaNames]
        puts_debug "total $count schema(s) are in status $status for version $version on server $tns"
        if { $count > $maxAllowedSchema } {
            puts_warning "There are $count schemas available for version $version on server $tns , schema names are $schemaNames\n excess schemas will be dropped!! "
            for {set i 0 } {$i < $count - $maxAllowedSchema } {incr i } {
                set schemaTempName [lindex $schemaNames $i ]
                puts_warning "Adding extra schema $schemaTempName to dropList"
                set status [updateRelengEntry $schemaTempName "DROPPING" $tdbh $tns]
                if {$status == -1} {
                    puts_error "Could not update status of schema $schemaTempName"
                    return $status
                }
            }
        }
    }
    return 0
}

## the proc checks the DB connectivity by pininging the DB server
# @author       Vinay Aswal
# @param dbName name of the db to be pinged
# @return 0 when DB is up and running else -1
proc pingDBinstance {dbName} {
    puts_debug "inside proc [info level 0]"

    set output ""
    set status ""

    set status [ catch { exec tnsping $dbName } output ]

    if {$status != 0 } {
        puts_debug "ping to DB server $dbName failed : $output "
        return -1
    }

    puts_debug  "successfully pinged to DB $dbName"
    return 0
}

## proc will check the DB connectivity first by pinging then call the function logon
# @author   Vinay Aswal
# @param dbHandle : db name exa : releng@db08
# @returns dbhandle  , -1 when DB is unavailable , -2 DB credentials are invalid
proc safeLogon {dbHandle} {
    puts_debug "inside proc [info level 0]"

    # separate db name and ping first
    regexp {@([^ \n]*)} $dbHandle dbName
    regsub -all {@} $dbName "" dbName

    puts_debug "DB name to ping test is $dbName"

    # check DB connectivity first
    if { [ pingDBinstance $dbName ] < 0 } {
        puts_error "unable to ping to DB $dbName !! please check the DB server entered."
        return -1
    }

    set status [ catch {logon $dbHandle } dbh ]

    if { $dbh == "-1" || $dbh == "" } {
        puts_error "unable to connect to $dbHandle !! please check the DB credentials entered."
        return -2
    }

    puts_debug "Connection successful to DB $dbName"
    return $dbh
}

##DB handles can be checked for validity
# @author   Vinay Aswal
# @param dbh  db handle to be checked
# @return 0 when dbh is valid else -1
proc checkDBHandle {dbh} {

    set SQL_Statement "select CURRENT_DATE from DUAL"
    set status [catch {execsql use $dbh $SQL_Statement} result ]

    puts_debug "result from sql is : $result with return status :$status"
    if { $status < 0 || $result < 0} {
        puts_debug "Database handle invalid !!"
        return -1
    } else {
        puts_debug "DB handle is valid "
        return 0
    }
}

## check wheather a table exists or not
# @author   Vinay Aswal
# @param tablename table to be checked
# @param dbh db handle
# @return difffrom list A and list B
proc checkTable {tablename dbh } {
    set SQL_Statement "select count(*)
    from all_objects
    where object_type in ('TABLE','VIEW')
    and object_name = 'VRI_VERSION_RELEASE_INFO'"

    set status [catch {execsql use $dbh $SQL_Statement} result ]
    puts_debug "result from sql is : $result with return status :$status"
    if { $status < 0 || $result < 0} {
        puts_error "Table does not exist!!"
        return -1
    } else {
        puts_debug "Table exists"
        return 0
    }
}

## compare two lists and return the difference
#default seperator are ' " , ;
# @author   Vinay Aswal
# @param listA first list to be compared
# @param listB second list to be compared with
# @param seperator seperator for the lists
# @return difffrom list A and list B
proc listcomp {listA listB {seperator ""} } {
    set diff {}

    if {$seperator == ""} {
        set seperator {'",;} ; #" for editor
    }

    regsub -all \[$seperator\] $listA " " listA
    regsub -all \[$seperator\] $listB " " listB

    foreach i $listA {
        if {[lsearch -exact $listB $i] == -1} {
            lappend diff $i
        }
    }

    foreach i $listB {
        if {[lsearch -exact $listA $i] == -1} {
            lappend diff $i
        }
    }

    set diff [lsort -unique $diff]
    return $diff
}


## drop schema function
# dropSch <schemaName>
# exa : dropSchema CRPOOL01061800_7484
# @author   Vinay Aswal
# @param schemaName table to be checked
# @param tdbh table db credential : exa : releng@db08
# @param pumpPath full path for the pump.tcl
# @return 0 Sucessfull , -1 : invalid DB or unable to update row, or -2 schema name provided doesnt exists
proc dropSch {schemaName poolDBserver} {
    set result 0
    set tdbs [spm::getRelengString]
    set tdbh [safeLogon $tdbs ]
    if {$tdbh == -1 } {
        puts_error "Unable to connect to DB $tdbs"
        logoff $tdbh
        return -1
    }
    set sql "select CSP_SCHEMA_NAME, CSP_STATUS into :availableSchema, :status
        from CSP_CONVERSION_SCHEMA_POOL
        where CSP_SCHEMA_NAME = '$schemaName'
        and CSP_SERVER_TNS = '$poolDBserver'
        and rownum <= 1
        for update skip locked"
    catch {execsql use $tdbh $sql} err
    if {$err == 0} {
        execsql use $tdbh "Update CSP_CONVERSION_SCHEMA_POOL set CSP_STATUS = 'LOCKED  where CSP_SCHEMA_NAME = '$schemaName' and CSP_SERVER_TNS = '$poolDBserver'"
        execsql use $tdbh "commit"
        set result [updateRelengEntry $schemaName "DROPPING" $tdbh $poolDBserver]
    } else {
        puts "Cannot update releng entry, will delete anyway"
    }
    catch {pump -x $schemaName $poolDBserver} result
    if {$result != 0} {
         puts_error "Could not drop $schemaName $result"
    } else {
        set result [updateRelengEntry $schemaName "DROPPED" $tdbh $poolDBserver]
    } 
    return $result
}

proc ::spm::getSchemaName {tdbh version} {
        #get sequence value from table dual
    set seq ""
    catch { execsql use $tdbh "select CSP_SEQUENCE.NEXTVAL into :seq from dual" } Queryresult
    #check the output
    if {$Queryresult < 0 || $seq == "" } {
        puts_error "Unable to get sequence value !!"
        return -1
    }
    # schema name is generated here
    return "CRPOOL$version\_$seq"
}

## create schema function
# createSch <version>
# exa :  CRPOOL01061800_7484
# @author   Vinay Aswal
# @param version version of schema to be created
# @param basefile dmp file name
# @param tdbh table db credential : exa : releng@db08
# @param pumpPath full path for the pump.tcl
# @return schemaName if Sucessfull , -1 : invalid DB or unable to insert row
proc createSch {version tdbs {poolDBServer "db09"} } {
    puts_debug "inside proc [info level 0]"
    set seq ""
    #checking DB handle validity
    if {$tdbs == ""} {
        set tdbs [spm::getRelengString]
    }
    if { [catch {logon $tdbs} tdbh ] < 0 } {
        puts_error "cannot logon !!"
        return -1
    }
    set dmpTest [checkDmp $version $tdbh]
    if { $dmpTest < 0 } {
        puts_error "Could not find a dump file for version $version, Please check the version !!"
        logoff $tdbh
        return -1
    }
    set basefile [file rootname $dmpTest]
    set schemaName [spm::getSchemaName $tdbh $version]
    puts_debug "current directory is [pwd]"
    puts_debug "entry for schema $schemaName will be inserted in CSP table"

    #inserting a row for the schema in SCP table
    set insertstatus [insertRelengTable $schemaName $version $basefile $poolDBServer $tdbh]
    execsql use $tdbh "commit"
    #check the status of DB insertion, if failed return
    if {$insertstatus == -1 } {
        puts_error "Unable to insert new row into CSP table !!! No Schema will be created. Please contact your admin !"
        puts_debug "schemaName $schemaName version $version basefile $basefile poolDBServer $poolDBServer"
        logoff $tdbh
        return -1
    }

    puts_info "Calling to create schema $schemaName on server $poolDBServer"
    set rval [pump -ito $schemaName@$poolDBServer $basefile ]
    puts_debug "pump.tcl logs : $rval"

    ## If $queryResult < 0, Schema is invalid, proc validateSchema will drop invalid schema automatically
    # status of invalid schema will be set to "DROPPED"
    if { [validateSchema $poolDBServer $schemaName] < 0 } {
        puts_error "Failed to login on schema $schemaName@$poolDBServer"
        logoff $tdbh
        return -1
    } else {
        puts_info "schema $schemaName has been successfully created, updating the status to AVAILABLE"
        # Schema is valid update Status in Database
        set result [updateRelengEntry $schemaName "AVAILABLE" $tdbh $poolDBServer]
        if {$result == -1} {
            puts_error "Could not update status of schema $schemaName !!"
            logoff $tdbh
            return -1
        }
        puts_info "$schemaName"
        #using puts for the purpose of renaming the Jenkins job to include schema name
        puts "$schemaName"
    }
    logoff $tdbh
    return $schemaName
}

## function to insert new row for the newly created schema
# used by create schema function
# @author   Vinay Aswal
# @param schemaName schema name to be inserted into table
# @param version version of schema to be created
# @param basefile dmp file name
# @param poolDBServers pool db server shaort name : exa : db09
# @param tdbh table db credential : exa : releng@db08
# @return sql output
proc insertRelengTable {schemaName version basefile poolDBServers tdbh} {
    puts_debug "inside proc [info level 0]"

    #checking DB handle validity
    if { [checkDBHandle $tdbh ] < 0 } {
        puts_error "Database handle invalid !!"
        return -1
    }

    set insertStatement "insert into CSP_CONVERSION_SCHEMA_POOL
        (CSP_SCHEMA_NAME,CSP_PRODUCT,CSP_VERSION,CSP_SERVER_TNS,CSP_BASE_DUMP,CSP_STATUS,CSP_PASSWORD,CSP_CREATE_DATE,CSP_LAST_USED)
        values ('$schemaName', 'CR', '$version', '$poolDBServers', '$basefile', 'PENDING', '$schemaName', sysdate, '')"

    set outStatus [ catch {execsql use $tdbh $insertStatement} resultCheck ]
    # Check the result
    if { $resultCheck == -1 || $outStatus < 0 } {
        puts_error "could not insert the row in CSP table!!"
        puts_debug "[info level 0]: $insertStatement sql query result $resultCheck sql output Status $outStatus"
        return -1
    }
    catch {execsql use $tdbh "COMMIT"} res2

    #checking inserted row in CSP table to make sure its there
    set SQLstatement "select CSP_SCHEMA_NAME into :tmpName from CSP_CONVERSION_SCHEMA_POOL where CSP_SCHEMA_NAME = '$schemaName' "
    set outStatus [ catch {execsql use $tdbh $SQLstatement} resultCheck ]
    # Check the result
    if { $resultCheck == -1 || $outStatus < 0 } {
        puts_error "could not find inserted row in CSP table for schema $schemaName !!"
        puts_debug "[info level 0]: $SQLstatement sql query result $resultCheck sql output Status $outStatus"
        return -1
    } else {
        puts_info "successfully inserted entry for schema $schemaName"
        puts_debug "[info level 0]: $SQLstatement sql query result $resultCheck sql output Status $outStatus , tmpName $tmpName"
    }

    return $resultCheck
}

## <B>
# the list of all schema present on db with name CRPOOL* will be returned
# version can also  be passed to the function to get list of specific version schema
# </B>
# @author   Vinay Aswal
# @param    poolDBserver pool data base credentials
# @param    version any version
# @return   returns schema name list with count or "-1"
proc allPresentSchemaOnDB { {poolDBserver "db09"} {version ""}} {

    set count "0"
    set presentSchemaList ""
    set dbh [ safeLogon redba@$poolDBserver ]
    set maxSchemaLimit $::MAXSCHEMAONDB

    set sql "select count(*),
    LISTAGG(username, ',') WITHIN GROUP (ORDER BY username) end
    into :count, :presentSchemaList
    from all_users
    where username like 'CRPOOL%$version%'"

    catch {execsql use $dbh $sql} err
    #dbh no longer needed , logoff
    logoff $dbh

    puts_debug "[info level 0]: sql $sql returned error : $err"

    if {$err == -1 || $err == 100 } {
        puts_warning "No schema found with name CRPOOL$version*"
        return -1
    }

    if {$count >= $maxSchemaLimit } {
        puts_warning "schema limit has reached on db $poolDBserver ! There are $count schema present on $poolDBserver, maxlimit is $maxSchemaLimit"

        # call email Jenkins job here
        if [catch {callJenkinsJob job/RE/job/dash/job/SPM_Email_notification "Body $count" "header 'SPM_schema_count_overflow'" } output] {
            puts_error "Unable to send warning email for schema overflow !!, $output"
        } else {
            puts_info "Called Jenkins job to send emails to admins about schema limit cross!!"
        }
    }
    puts_debug "count $count presentSchemaList $presentSchemaList"
    return "$count $presentSchemaList"
}

## <B>
# Schema which are present on DB but there is no entry in CSP table should be dropped
# </B>
# @author   Vinay Aswal
# @param    poolDBserver pool db server crentials
# @param    tdbh CSP table DB handler
# @param    pumpPath full path to the file pump.tcl
# @return   Nothing
proc dropOrphanSchema {poolDBserver tdbh} {

    #checking DB handle validity
    if { [checkDBHandle $tdbh ] < 0 } {
        puts_error "Database handle invalid !!"
        return -1
    }

    set schemaAndcount [allPresentSchemaOnDB $poolDBserver]
    set allSchemaCount [lindex $schemaAndcount 0]
    set allSchemaNames [lindex $schemaAndcount 1]
    puts_debug "count $allSchemaCount, schema present on $poolDBserver $allSchemaNames "

    set availableSchemaQuery "select CSP_SCHEMA_NAME into :cspSchemaList from CSP_CONVERSION_SCHEMA_POOL
        where CSP_STATUS in ('AVAILABLE', 'DROPPING', 'PENDING', 'INUSE', 'LOCKED', 'NABBED')"
    # set availableSchemaQuery "select CSP_SCHEMA_NAME into :schemaList from CSP_CONVERSION_SCHEMA_POOL where CSP_STATUS = 'AVAILABLE' for update skip locked"

    catch {execsql use $tdbh $availableSchemaQuery} Queryresult
    if {$Queryresult < 0} {
        puts_error "Unable to run query $availableSchemaQuery , query result is: $Queryresult  "
        return -1
    }

    puts_debug "schema List from CSP table : $cspSchemaList"
    set orphanSchemaList [listcomp $allSchemaNames $cspSchemaList ","]

    foreach schemaName $orphanSchemaList {
        if { [setSchemaToBeDropped $schemaName $poolDBserver] == -1 } {
            puts_warning "No entry found in CSP table for schema $schemaName, Dropping it !!"

            # Important : we can not call dropSchema , as it wont work without an entry in CSP table. Calling pump directly
            # syntax is: exec tclsh C:\\Tcl\\lib\\tcl8.6\\SPM1.0\\pump.tcl -x $schemaName $poolDBserver
            puts_info "executing pump -x $schemaName $poolDBserver"
            catch {pump -x $schemaName $poolDBserver} result
            puts_debug "dropSchema result is : $result"
        }
    }
}

## <B>
# Find the client versions from table CVR_CLIENT_VERSIONS and format the version
# from 3.1.2.2 2.4.12 2.00.04 to 03010202 02041200 02000400
# </B>
# @author   Vinay Aswal
# @param    dbhReleng           data base handler for DB releng
# @return   List of Client version
proc p_getClientVersionList {dbhReleng} {
    set clientVersionList ""
    set t_list ""

    #checking DB handle validity
    if { [checkDBHandle $dbhReleng ] < 0 } {
        puts_error "Database handle invalid !!"
        return -1
    }

    # --------------------------
    # START: Client version logic
    set clientVersionQuery "select CVR_VERSION  into :clientVersionList from CVR_CLIENT_VERSIONS where CVR_ACTIVE_YN = 'Y'
        and CVR_PRD_ID = 'CR' "

    catch {execsql use $dbhReleng $clientVersionQuery} result
    if {$result < 0} {
        puts_error "Unable to run query $clientVersionQuery , query result is: $result  "
        return -1
    }

    # changing version format from 3.1.2.2  2.4.12 2.00.04 to 03010202 02041200 02000400
    foreach i $clientVersionList {
        if { [ regexp -all {\.} $i ] < 3 } {
            set i  $i.0
        }
        append t_list "0" $i " "
    }
    set clientVersionList $t_list
    regsub -all {([.])([0-9]{2})} $clientVersionList {\2} clientVersionList
    regsub -all {([.])([0-9]{1})} $clientVersionList {0\2} clientVersionList

    set clientVersionList [lsort -unique $clientVersionList]

    puts_debug "Client versions are $clientVersionList "
    # END: Client version logic
    # ------------------------

    return $clientVersionList
}


proc p_statusChangeControl {schemaName newStatus dbhReleng} {
    set currentStatus ""

    # checking DB handle validity
    if { [checkDBHandle $dbhReleng ] < 0 } {
        puts_error "Database handle invalid !!"
        return -1
    }

    set schemaStatusQuery "select CSP_STATUS into :currentStatus from CSP_CONVERSION_SCHEMA_POOL where CSP_SCHEMA_NAME = '$schemaName'"

    catch {execsql use $dbhReleng $schemaStatusQuery} Queryresult
    puts "Current status $currentStatus , new status $newStatus"

    if {[string toupper $currentStatus] eq [string toupper $newStatus] } {
        puts_error "Current status and new Status are same !!"
        return 0
    }

    # more steps will be added here, like status can not go backwards
    # only allowed is : PENDING --> AVAILABLE --> INUSE --> DROPPING --> DROPPED
}

#============================
#------------MAIN------------
#============================
puts_debug "Inside Script SPM"

set computerName $::env(COMPUTERNAME)
# exec svn up https://cic-svr-svn01:18080/svn/releng/trunk/retools/re_internal/localEnv/
# exec svn export --force https://cic-svr-svn01:18080/svn/releng/trunk/retools/re_internal/localEnv/$computerName/local_env.tcl

catch {package provide SPM 3.7.1}