#!/opt/hpws/apache/cgi-bin/mtclsh

set info(logFile) [open schemaReq.log a]
set logFile $info(logFile)
puts $info(logFile) "Start of log file..."

package require cgi
package require otc
package require uri

puts $info(logFile) "After package requires..."
cgi_debug -on
cgi_admin_mail_addr Brian.Palmer@exlservice.com
cgi_input; # DLIBES version is in place now. process CGI input into "hidden"

puts $info(logFile) "Sourcing emp.tcl..."
source ./emp.tcl
puts $info(logFile) "Sourcing sysdatareqprocs.tcl..."
source ./sysdatareqprocs.tcl
puts $info(logFile) "Sourcing makeforms.tcl..."
source ./makeforms.tcl
puts $info(logFile) "Sourcing getSystemData..."
source getSystemData.tcl
set info(FORM_NAME) sysdatareq
puts $info(logFile) "done sourcing files" 
#todo utilize package version of this.
proc SQLError {} {
    global info
    set msg "SLQ Error occurred during the processing of selected Table request for parent DVT $info(parentDvt).
    <br>$info(SQL_Statement)<br>[getinfo all]
    <br>Your dvt was not created.<br>Please notify RE."
    puts "<h4>$msg</h4>"
    exit
}
proc getVarList {} {
    return "newDVT sitOpval procedure product formid INSERT_DATA UPDATE_DATA DELETE_DATA TABLE_NAME"
}
proc importAll {} {
    set r ""
    catch {set r [cgi_import info_array]}
    foreach name [cgi_import_list] {
        #"info" is held in a variable named "info_array" todo: modify?
        puts $::logFile "importing name = $name"
        if {$name == "info_array"} {
            continue
        } else {
            lappend r "$name"
            lappend r "[cgi_import $name]"
            
        }
    }
    # ANOTHER option regsub {info_array} $r info r
     return $r
}
proc setOrImportArrayVals {arrayName} {
    upvar $arrayName AN
    set counter 0
    #set null values.
    foreach n [getVarList] {
        if {![info exists AN($n)]} {
            set AN($n) ""
        }
    }
    array set AN [importAll]
    return $counter
}
####################
####### MAIN #######
####################
puts $info(logFile) "Before MAIN catch statement..."
catch {
puts $info(logFile) "In MAIN catch statement..."
    if [catch {source "[file join ./mail mailGroups.tcl]"} err] {
        append info(errorMessage) "failed to source mail info $err"
    }

    if [catch {source "[file join . dbConnections.tcl]"} err] {
        append info(errorMessage) "Failed to source connections info $err"
    }

    cgi_eval {
        if {![info exists info(errorMessage)]} {
            set info(errorMessage) ""
        }
        puts $info(logFile) "Import Val?"
        setOrImportArrayVals info
        set info(logFile) $logFile
        puts $info(logFile) [array get info]

        set userEmail ""
        # todo move this to "setup" area
        if {![info exists info(SVN_LOCAL)]} {
            set info(SVN_LOCAL) c:/svn_local/releng
        }
        if {![info exists info(SVN_REMOTE)]} {
            set info(SVN_REMOTE) "https://cic-svr-svn01:18080/svn/releng/"
        }
        
        # Set basic html body information
        # HTML
        cgi_body_args link=#AAAAFF bgcolor=#FFFFFF text=#800000 font=arial font-size=3pt onload="getFreshPage()"; 
        cgi_title "System Data Request Form"
        cgi_body 
        writeJavaScriptSDR
        # get type of system data
        
        if {$info(formid) == ""} {
            MakeForm info dva
        } else {
               
        puts $info(logFile) "info(formid) $info(formid) [cgi_import_list] "
            switch $info(formid) {
                page1 {
                    # get type of data
                    puts $info(logFile) "******************** PAGE 1 ********************"
                    puts $info(logFile) "[Now] INFO: [array get info]"
                   
                    if {$info(dataTypeSelect) == "System Data"} {
                        set info(sysDataYN) Y
                    } else {
                        set info(sysDataYN) N
                    }
                    puts $info(logFile) "[Now] INFO: sysDataYN is $info(sysDataYN)"
                    # get entered by
                    # get parent DVT
                    puts $info(logFile) "[Now] INFO: parentDvt = $info(parentDvt)"
                    # get table               
                    
                    # get delete YN
                    if {$info(sysDataYN) == "Y"} {
                        if {[catch {cgi_import deleteDataYN} err]} {
                            if {[cgi_debug] == "-on"} {
                                puts $info(logFile) "[Now] WARN: DEBUG: $err"
                            }
                            set info(deleteDataYN) N
                        } else {
                            set info(deleteDataYN) Y
                        }
                        puts $info(logFile) "[Now] INFO: deleteDataYN = $info(deleteDataYN)"
                    }
                    
#todo :move to validation proc
            ### data entry validation for selectedTable page###
                    # validate selected user
                    if {$info(emp_ent) == "NULL" || [string length $info(emp_ent)] < 1 } {
                        set info(errorMessage) "Please identify youself as Requester."
                        MakeForm info dva
                        exit
                    } 
                    
                    # see if a parent DVT was entered
                    if {$info(parentDvt) == "NULL" || [string length $info(parentDvt)] < 1 } {
                        set info(errorMessage) "Please enter a parent DVT."
                        MakeForm info dva
                        exit
                    }

                    # set the table uppercase if system data
                    if {$info(sysDataYN) == "Y"} {
                        if {$info(tabPrefix) == "NULL" || [string length $info(tabPrefix)] < 1 } {
                            set info(errorMessage) "Please enter a table name or 3 letter prefix."
                            MakeForm info dva
                            exit
                        } 
                        set info(tabPrefix) [string toupper $info(tabPrefix)]
                        puts $info(logFile) "[Now] INFO: tabPrefix = $info(tabPrefix)"
                    }
                    
                    # set database connection info
                    set info(mtx) [logon [getconnection "maxtrax"]]
                    set info(releng) [logon [getconnection "releng"]]
                    if {![regexp {oratcl.+} $info(mtx)]} {
                        set info(errorMessage) "MAXTRAX not available now, please try later."
                        MakeForm info dva
                        exit
                    }
                    if {![regexp {oratcl.+} $info(mtx)]} {
                        set info(errorMessage) "RELENG not available now, please try later."
                        MakeForm info dva
                        exit
                    }
                    
                    #  Test to see if a valid DVT was entered 
                    set info(SQL_Statement) "select count(*) into :dvtParentCount from dvt_development_task where dvt_id = $info(parentDvt)"
                    execsql use $info(mtx) $info(SQL_Statement) SQLError
                    if {$dvtParentCount < 1} {
                        set info(errorMessage) "Please enter a valid parent DVT."
                        logoff $info(mtx)
                        logoff $info(releng)
                        MakeForm info dva
                        exit
                    }

                    # Get employees email (currently from maxtrax)
                    set info(SQL_Statement) "select emp_email_address into :userEmail from emp_employee where emp_id = '$info(emp_ent)'"
                    execsql use $info(mtx) $info(SQL_Statement) SQLError
                    set info(userEmail) $userEmail
                    puts $info(logFile) "[Now] INFO: userEmail = $info(userEmail)"
                    
                    # get dva list
                    set info(SQL_Statement) "select dvl_dva_id into :dvaLst from DVL_DVA_DVT_LINK where DVL_DVT_ID = $info(parentDvt)"
                    execsql use $info(mtx) $info(SQL_Statement) SQLError
                    if {[llength $dvaLst] == 0} {
                        set info(errorMessage) "[Now] ERROR: Please provide a parent DVT that has one or more CR DVA records attached."
                        logoff $info(mtx)
                        logoff $info(releng)
                        MakeForm info dva
                        exit
                    }
# todo: move to getversioninfo proc
                    # get version info from dva list
                    # setup an array dva with a list that consists of the following:
                    # vri_version, vri_devel_schema, vri_proto_schema, vri_svn_base
                    set info(errorMessage) ""
                    set vriVer ""
                    set vriDevSchema ""
                    set vriProtoSchema ""
                    set vriSvnBase ""
                    puts $logFile "dvaLst = $dvaLst"
                    set listVersionDots ""
                    foreach item $dvaLst {
                      set info(SQL_Statement) "select nvl(vri_version, 'NONE'), nvl(vri_devel_schema, 'NONE'), nvl(vri_proto_schema, 'NONE'), nvl(vri_svn_base, 'NONE'), vri_prd_id into :vriVer, :vriDevSchema, :vriProtoSchema, :vriSvnBase, :prd_id from VRI_VERSION_RELEASE_INFO where vri_dva_id = $item and vri_prd_id = 'CR'"
                      execsql use $info(releng) $info(SQL_Statement) SQLError
                      if {$vriVer != ""} {
                          if {$vriVer != "NONE" && $vriDevSchema != "NONE" && $vriProtoSchema != "NONE" && $vriSvnBase != "NONE"} {
                              puts "vriSvnBase: $vriSvnBase"
                              # the following if is to set the svn base to the new Test location
                              if {$vriSvnBase == "trunk/CareRadius"} {
                                  set vriSvnBase "branches/CareRadius/V03/02/00/00T"
                              } else {
                                  append $vriSvnBase T
                              }
                              lappend listVersionDots [p_interpose $vriVer "."]
                              set dva([p_interpose $vriVer "."]) $item
                        } else {                                
                              set info(errorMessage) "[Now] ERROR: Have RE correct the following data that contains 'NONE' for DVA $item:\nvri_version = $vriVer\nvri_devel_schema = $vriDevSchema\nvri_proto_schema = $vriProtoSchema\nvri_svn_base = $vriSvnBase"
                              logoff $info(mtx)
                              logoff $info(releng)
                              MakeForm info dva
                        }
                      }  
                    }
                    set info(versionDots) [lindex [lsort $listVersionDots] end]
                    set item $dva($info(versionDots))
                    #puts "item: $item"
                    
                    #foreach item $dvaLst {
                        set info(SQL_Statement) "select nvl(vri_version, 'NONE'), nvl(vri_devel_schema, 'NONE'), nvl(vri_proto_schema, 'NONE'), nvl(vri_svn_base, 'NONE'), vri_prd_id into :vriVer, :vriDevSchema, :vriProtoSchema, :vriSvnBase, :prd_id from VRI_VERSION_RELEASE_INFO where vri_dva_id = $item and vri_prd_id = 'CR'"
                        execsql use $info(releng) $info(SQL_Statement) SQLError
                        if {$vriVer != ""} {
                            if {$vriVer != "NONE" && $vriDevSchema != "NONE" && $vriProtoSchema != "NONE" && $vriSvnBase != "NONE"} {
                                puts "vriSvnBase: $vriSvnBase"
                                # the following if is to set the svn base to the new Test location
                                if {$vriSvnBase == "trunk/CareRadius"} {
                                    set vriSvnBase "branches/CareRadius/V03/02/00/00T"
                                } else {
                                    append $vriSvnBase T
                                }
                                set info(versionDots) [p_interpose $vriVer "."]
                                puts "info(versionDots): $info(versionDots)"
                                set info(versionList) [p_pad_version $info(versionDots)]
                                set info(versionShort) [join [p_unpad_version $info(versionDots)] ""]
                                set info(modFileName) Mod$info(versionShort)
                                set info(prd_id) $prd_id
                                set info(branch) $vriSvnBase
                                #todo: temp for testing
                                #puts "[Now] INFO: info(versionDots) = $info(versionDots)"
                                set info(branch) trunk/PBS/Epic1
                                puts $info(logFile) "[Now] INFO: info(versionDots) = $info(versionDots)"
                                puts $info(logFile) "[Now] INFO: vriVer = $vriVer info(versionShort) = $info(versionShort)"
                                puts $info(logFile) "[Now] INFO: info(versionList) = $info(versionList)"
                                puts $info(logFile) "[Now] INFO: vriProtoSchema = $vriProtoSchema"
                                puts $info(logFile) "[Now] INFO: vriSvnBase = $vriSvnBase"
                                set dva($item) [list $vriVer $vriDevSchema $vriProtoSchema [string trim $vriSvnBase /]]
                            } else {                                
                                set info(errorMessage) "[Now] ERROR: Have RE correct the following data that contains 'NONE' for DVA $item:\nvri_version = $vriVer\nvri_devel_schema = $vriDevSchema\nvri_proto_schema = $vriProtoSchema\nvri_svn_base = $vriSvnBase"
                                logoff $info(mtx)
                                logoff $info(releng)
                                MakeForm info dva
                            }
                        }
                    #}
                    if {[array size dva] == 0} {
                        set info(errorMessage) "[Now] ERROR: Your parent DVT $info(parentDvt) either does not<br>contain any CareRadius DVA assignments<br>or the DVA is missing version information.<br>Please correct the issue and try again."
                        logoff $info(mtx)
                        logoff $info(releng)
                        MakeForm info dva
                        exit
                    }
                    set info(PROTO) GETSYSDATA3200/GETSYSDATA3200@cic-svr-db09-site
                    if {$info(sysDataYN) == "Y"} {
                       
                        set info(tableColumnList) ""
                        if {[string length $info(tabPrefix)] < 3} {
                            set info(errorMessage) "Please provide the first three characters of the table name."
                            MakeForm info dva 
                            exit
                        } else {
			#  Test to see if a valid TABLE PREFIX was entered
                            set info(SQL_Statement) "select count(*) into :tabCount from USER_TABLES where TABLE_NAME like '$info(tabPrefix)%'"
                            set f [logon $info(PROTO)]
                            execsql use $f $info(SQL_Statement) SQLError
                            logoff $f
                            if {$tabCount < 1} {
                                set info(errorMessage) "Please enter a valid 3 character Table Prefix."
                                MakeForm info dva
                                exit
                            }
                        }
                    }
                    # If system data, get the full tablename 
                    # Get table info such as columns, primary key, not null constraints
                    set info(DEV) crtrunk/crtrunk@cic-svr-db05-site
                    set info(workingDir) [pwd]/working/$info(tabPrefix)123456
                    puts $info(logFile) "*** Creating dir - $info(workingDir)"
                    catch {file mkdir $info(workingDir)} op
                    puts $info(logFile) "mkdir output: $op"
					if [catch {exec svn export --force $info(SVN_REMOTE)/$info(branch)/Data/Source/sql/[string tolower $info(tabPrefix)].sql $info(workingDir)/[string tolower $info(tabPrefix)].sql} foo] {
						puts $info(logFile) "While exporting SVN file to working dir, caught error: $foo"
                        set info(errorMessage) "$info(tabPrefix).sql does not exists in SQL directory, caught error: $foo"
						MakeForm info dva
						exit
						set info(TABLE_NAME) $info(tabPrefix) ;# temporary in case we cannot set it from .sql file here - it well be set later in getSysDataSources.
                    } else {
                        puts $info(logFile) "No errors in exporting SVN files to local workspace"
                        array set info [parseSQLfile [catl $info(workingDir)/[string tolower $info(tabPrefix)].sql]]
                        puts $info(logFile) $info(UNIQUE)
                    }
					# FORM 2 ENTRY OF DATA
                    setTableName info
                    entryForm info 
                    cgi_export info_array=[array get info]
                    logoff $info(mtx)
                    logoff $info(releng)
                    unset info(mtx)
                    unset info(releng)
                    catch {file delete -force [pwd]/working/$info(tabPrefix)123456}
                }
                page2 {
                    set infoList "\("
                    foreach {name val} [array get info] {
                        if {[regexp "SQL_Statement" $name] || [regexp "WHERE" $name]} {
                            append infoList "[set name]::::\}\{"
                        } else {
                            append infoList "[set name]::::[set val]\}\{"
                        }
                    }
                    set infoList [string trimright $infoList "\{" ]
                    set infoList [string trimright $infoList "\}" ]
                    append infoList "\)"
                    set infoList [string map {"%" "\%"} $infoList]
                    set infoList [string map {" " %20} $infoList]
                    regsub -all {\n} $infoList "" infoList
                    puts $info(logFile) "Argument infoList: $infoList"
                    puts $info(logFile) "Calling Jenkins job: exec tclsh launch_build.tcl job/RE/job/RE_TESTING/job/runSysDataRequests/ infoList $infoList"
                    # set home [pwd]
                    # set jarPath "C:\\Program Files (x86)\\Jenkins\\war\\WEB-INF"
                    # cd $jarPath
                    # if [catch {exec java -jar jenkins-cli.jar -s http://localhost:8080/ build runSysdataReq -p infoList=$infoList} errInside] {
                        # puts $info(logFile) "Error in Jenkins job: $errInside \nPlease contact RE."
                    # }
                    if [catch {exec tclsh launch_build.tcl job/RE/job/RE_TESTING/job/runSysDataRequests/ "infoList $infoList userEmail $info(userEmail)"} errInside] {
                        puts $info(logFile) "Error in Jenkins job: $errInside \nPlease contact RE."
                        cgi_puts "Error in Jenkins job: $errInside \nPlease contact RE."
                    }
                    # cd $home
                    puts $info(logFile) "Back from Jenkins job"
                    form3 info
                }
            }   
        }
        puts $info(logFile) "exporting [array get info]"
        
    } 
} bad
puts $info(logFile) $bad


 #todo:    
                # finally, validate against whole model - revised: this will have to happen with a trigger such as a jenking watcher or such. (this should happen as a background process), and email the results; to RE and submitter.
               
                # run sysdatagen.
                # if pass?
                