#!/opt/hpws/apache/cgi-bin/mtclsh

set info(logFile) [open schemaReqMain.log a]
set logPath [pwd]
set logFile $info(logFile)
puts $info(logFile) "Start of log file..."

package require cgi
package require otc
package require uri
package require xml
package require dom::tcl


puts $info(logFile) "After package requires..."
cgi_debug -on
cgi_admin_mail_addr Brian.Palmer@exlservice.com
cgi_input; # DLIBES version is in place now. process CGI input into "hidden"

puts $info(logFile) "Sourcing XMLprocs.tcl..."
source "C:\\svn_local\\releng\\trunk\\package\\scripts\\XMLprocs.tcl"
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
set info(maxtrax) "mxtproto/mxtproto@cic-svr-db05-orcl"
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
    return "newDVT sitOpval procedure product formid INSERT_DATA UPDATE_DATA DELETE_DATA"
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
    # Populate info array
    populateInfoArray info $::argv
    #puts "Input Array: [array get info]"
    # Add vars to System Env so that these can be used to determine overall status of SysDataReq and miscellaneous actions
    set ::env(SDR_STATUS) "PASSED"
    set ::env(SDR_FAIL_MESSAGE) ""
    if {[string length [lindex $::argv 0]] <=0 } {
        append info(errorMessage) "Script received no arguments"
		markAsFailed "Jenkins job received no arguments!"
    }
    if {![hasFailed]} {
        if {[catch {source "[file join ./mail mailGroups.tcl]"} err]} {
            markAsFailed "Failed to source mail information: $err"
            append info(errorMessage) "Failed to source mail info $err"
        }
    }
    if {![hasFailed]} {
        if {[catch {source "[file join . dbConnections.tcl]"} err]} {
            markAsFailed "Failed to source mail information: $err"
            append info(errorMessage) "Failed to source connections info $err"
        }
    }

    set info(workingDir) [pwd]/working/$info(tabPrefix)123456
	puts $info(logFile) "WorkingDir: $info(workingDir)"

	if {![hasFailed]} {
        if [catch {exec svn export --force $info(SVN_REMOTE)/$info(branch)/Data/Source/sql/[string tolower $info(tabPrefix)].sql $info(workingDir)/[string tolower $info(tabPrefix)].sql} foo] {
        	set info(TABLE_NAME) $info(tabPrefix) ;# temporary in case we cannot set it from .sql file here - it well be set later in getSysDataSources.
        } else {
            puts $info(logFile) "Passing to parsesql: [catl $info(workingDir)/[string tolower $info(tabPrefix)].sql]"
            array set info [parseSQLfile [catl $info(workingDir)/[string tolower $info(tabPrefix)].sql]]
        }
        # catch {exec svn export --force $info(SVN_REMOTE)/$info(branch)/Data/Source/sql/fdd.sql $info(workingDir)/fdd.sql} fddfoo
    }
    if {![hasFailed]} {
        getSysDataSources info $info(SVN_REMOTE) $info(SVN_LOCAL) $info(branch) $info(workingDir) $info(modFileName) $info(tabPrefix)
        # generate the full model file in repo and check in updates to SVN 00T branch
        set err [form2 info]
        if {$err != "" && $err != "0"} {
            puts "Failed at step 5"
            markAsFailed $err
        }
    }
    # markAsFailed "**************** Testing Fail"
    if {![hasFailed]} {
        puts $info(logFile) "exporting [array get info]"
        foreach element $info(versionList) {
            append packageVer $element
        }
        # Check if build-number exist in packaging directory
        catch {set buildNmbr [fetchBuildnumber $info(versionList)]} err
        if {$buildNmbr != ""} {
            append packageVer $buildNmbr 
            set here [pwd]
            foreach version $info(versionList) {append verListApp $version}
            set versionXmlpath "C:\\svn_local\\releng\\trunk\\retools\\tests\\tcl\\config\\versions\\"
            cd $versionXmlpath
            
            # Check for the version file in $versionXmlpath for CR$verListApp 
            
            catch {set CheckversionXmlfile [glob -nocomplain CR$verListApp.xml*]} err
            
            if {$CheckversionXmlfile != ""} {
                set versionFile "$versionXmlpath$CheckversionXmlfile"
            } else {
                append err "ERROR: Cannot find Version file for CR$verListApp version!"
                puts $err
                markAsFailed $err
            }

            catch {set schemaVer [schemaVersion $versionFile]} err

            if {$schemaVer != ""} {
            puts "Using Schema Version: $schemaVer for runconversion job"
            } else {
                append err "ERROR: Schema version not found !"
                puts $err
                markAsFailed $err
            }
          cd $here
          catch {runconversion CR $packageVer 01 $schemaVer info} runcnverr
          if {$runcnverr!="PASSED"} {
            set err "Runconversion could not be executed due to $runcnverr"
            markAsFailed $err
          } else {
          }
        } else {
            append err " : Build number could not be found in the Packaging directory!"
            markAsFailed $err
        }
    }
    if {![hasFailed]} {
        puts "Need to add process to do svn merge from 00T branch to Main branch"
        # Need to add process to do svn merge from 00T branch to Main branch
    }
    if [hasFailed] {
        puts "End of Main Script: Main has failed: [hasFailed]\n Error : $::env(SDR_FAIL_MESSAGE)"
    }
} bad
if {$bad != "" || $::env(SDR_STATUS) == "FAILED"} {
    #parray info
    # puts "************* $info([string tolower $info(tabPrefix)].SQL)"
    set file [open $logPath/infoArray.txt w]
    puts $file [array get info]
    close $file
  
    set fh  [open $logPath/env.properties a]
    puts $fh "Job_Status=$::env(SDR_STATUS)"
    if {[info exists info(insertSQL)] == 1} {
      #set ::env(insertSQL) "info(insertSQL)"
      puts $fh "Insert_SQL=$info(insertSQL)"
    }
    if {[info exists info(deleteSQL)] == 1} {
      #set ::env(deleteSQL) "info(deleteSQL)"
      puts $fh "delete_SQL=$info(deleteSQL)"
    }
    close $fh
    puts "Job_Status=$::env(SDR_STATUS)\n"
    puts "Failure Reason: $bad\n"
    puts "Calling Rollback\n"
    rollback info
    #exit 1
} else {
    set file [open $logPath/infoArray.txt w]
    puts $file [array get info]
    close $file
    set fh  [open $logPath/env.properties a]
    puts $fh "Job_Status=$::env(SDR_STATUS)"
    if {[info exists info(insertSQL)] == 1} {
      puts $fh "Insert_SQL=$info(insertSQL)"
    }
     if {[info exists info(deleteSQL)] == 1} {
      #set ::env(deleteSQL) "info(deleteSQL)"
      puts $fh "delete_SQL=$info(deleteSQL)"
    }
    close $fh
    puts "Job_Status=$::env(SDR_STATUS)\n"
}
