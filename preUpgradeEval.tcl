#//##########################################################################################################################
# Script Name   preUpgradeEval.tcl
# @author       Anna Devore
# @since        October 2, 2002
# Purpose       Automatically evaluate all scripts and certification involved in a upgrade.
#
# Usage:    mtclsh preUpgradeEval.tcl <Database Connect String> <Driver File> [Email Address] [SILENT]
#
#
# Description:
#   Include logon information, Driver file , optionally e-mail address.
#
#
# MODIFICATION LOG
# Who   When        Comments
# ---   ----------  ----------------------------------
#
#//##########################################################################################################################

# ===========================================================================================================================
#   Sources
# ===========================================================================================================================

if {[catch {getInfo _common_utilities_loaded}]} {
    if [catch {glob common_utilities.tcl} err] {
        puts "The file common_utilities.tcl is not in the current directory."
        puts "This script cannot run without it."
        puts "Please obtain this file and copy it into this directory."

        return 2
    } else {
        puts "Sourcing common_utilities.tcl..."
        source common_utilities.tcl
    }
}

# ===========================================================================================================================
#   Procedures
# ===========================================================================================================================

# @return   string  PreUpgradeEval Version Number
proc preUpgradeEval.version {} {return "5"}

# @return   string  PreUpgradeEval Revision Number
proc preUpgradeEval.revision  {} {return "1"}

# <p>
#   <br> Print Usage to stdout
# </p>
#
# @return   number  0
proc pueUsage {} {
    puts ""
    puts "USAGE:   mtclsh preUpgradeEval.tcl <Database Connect String> "
    puts "         <Driver File> \[Email Address\]"
    puts ""
    puts "<Database Connect String> - "
    puts "  This can either be the complete string (e.g. prodDB/myPass@serverName)"
    puts "  or the XAct Interface name (e.g. M2PROD)."
    puts ""
    puts "<Driver File> -"
    puts "  For CareRadius to CareRadius conversions use \'AutoConversion.txt\' "
    puts "  For MaxMC to CareRadius conversions use \'AutoConversionMCtoCR.txt\'"
    puts ""
    puts "\[Email Address\] (optional) -"
    puts "  This is an optional parameter.  If included a notification email will"
    puts "  be sent to this address containing information about the evaluation."
    puts ""
    puts ""
    puts "EXAMPLE: mtclsh preUpgradeEval.tcl prodDB/myPass@serverName"
    puts "         AutoConversion.txt maxadmin@site.com"
    puts ""

    return 0
}

# <p>
#   <br> Print Help to stdout
# </p>
#
# @return   number  0
proc pueHelp {} {
    puts ""
    puts "============================================================================"
    puts " preUpgradeEval.tcl"
    puts "============================================================================"
    puts ""
    puts [preUpgradeEval.getDescription]
    puts "During the evaluation process, several reports will be generated"
    puts "which require review. In some instances, one or more steps may be"
    puts "required in order to prepare the target database for the conversion."

    pueUsage

    return 0
}
proc preUpgradeEval.getDescription {} {
 return "preUpgradeEval.tcl determines the readiness of the target database
in terms of schema certification and tablespace resources."

}
# <p>
#   <br> Print Header to stdout and log
# </p>
#
# @param    log     Log File Handle
# @param    text    Text to add to the header
# @return   number  0
proc printHeader {log text} {
    append  header " * * $text * * \n"

    putt $log $header

    return 0
}

# <p>
#   <br> Print Result to stdout and log
# </p>
#
# @param    log     Log File Handle
# @param    text    Text to add to the result
# @return   number  0
proc printResult {log text} {
    append  result " = = $text = =\n"

    putt $log $result

    return 0
}

# <p>
#    <br> Generate the PreUpgradeEval footer text
# </p>
#
# @param    displayDB       The Database
# @param    currentVersion  Current Product Version Number
# @param    targetVersion   Target Prodcut Version Number
# @param    outdir          Output Report Directory
# @param    total_minutes   Script Runtime (Minutes)
# @param    total_seconds   Script Runtime (Seconds)
# @return   string          The footer text
proc printPueFooter {displayDB currentVersion targetVersion outdir total_minutes total_seconds} {
    set     footer "============================================================================\n"
    append  footer "preUpgradeEval.tcl version [preUpgradeEval.version], revision [preUpgradeEval.revision] has completed.\n"
    append  footer "Pre-Conversion analysis reports for the $currentVersion to $targetVersion conversion\n"
    append  footer "are in the $outdir directory\n"
    append  footer "\n"
    append  footer "Questions about the pre-conversion analysis reports should be directed to the\n"
    append  footer "EXL Healthcare Support Department: (800) 669-4629 or EXLHealthcareSupport@exlservice.com.\n"
    append  footer "\n"
    append  footer "Run Time was $total_minutes minutes, $total_seconds seconds.\n"
    append  footer "============================================================================\n"

    return $footer
}

# <p>
#    <br> Run TblspAnalysis against the input Database Handle
# </p>
#
# @param    log                 Log File Handle
# @param    puedbh              Database Connection Handle
# @param    update_table_lst    List of tables to check
# @return   number              Success: 0; Warning: 1; Error: 2
proc analyzeTblsp {log puedbh update_table_lst} {
    upvar act_tblsp_lst act_tblsp_lst
    upvar tblsp_lst tblsp_lst

    printHeader $log "Analyzing Tablespace and Rollback Usage"

    set TRA "Rollback & Tablespace Analysis"
    set tra "\{$TRA\}"

    source TblspAnalysis.tcl

    set return_value [TblspAnalysis $puedbh $update_table_lst]
    updateInfo default_channel [getInfo preUpgradeEval.REPORT_HANDLE]
    if {$return_value != 0} {
        putt $log ""
        printResult $log "Warning"

        return 1
    } else {
        printResult $log "OK"

        return 0
    }
}

# <p>
#    <br> Checks indexes on the target db
# </p>
#
# @param    currentMod  Current version mod file (source)
# @param    targetMod   Target version mod file (to check)
# @param    puedbh      Database Connection Handle
# @param    log         Log File Handle
# @param    driverFile  File to filter the check
# @return   number      Success: 0; Warning: 1; Error: 2
proc checkIndexes {currentMod targetMod puedbh log {driverFile ""} } {
    printHeader $log "Checking Indexes"

    set return_value [p_indCheck $currentMod $targetMod $puedbh $log $driverFile]

    if {$return_value != 0} {
        putt $log ""
        printResult $log "Warning"

        return 1
    } else {
        printResult $log "OK"

        return 0
    }
}

# <p>
#    <br> Check the the user has appropriate permissions
# </p>
#
# @param    log             Log File Handle
# @param    currentMod      Current version mod file
# @param    puedbh          Database Connection Handle
# @param    short_current   Version Number to use in the CertXX.lst file name
# @return   number          Success: 0; Warning: 1; Error: 2
proc checkSchemaCertification {log currentMod puedbh short_current} {
    printHeader $log "Analyzing Schema Certification Status"

    source dbCompare.tcl

    set schemaValid [dbCompare $currentMod [getInfo connectString] "cert$short_current.lst"]
    updateInfo default_channel [getInfo preUpgradeEval.REPORT_HANDLE]
    if {$schemaValid != 0} {
        putt $log "\ndbCompare.tcl reports that schema differences exist. See cert$short_current.lst\n"

        putt $log ""
        printResult $log "Warning"

        return 1
    } else {
        printResult $log "OK"

        return 0
    }
}

# <p>
#    <br> Check the the user has appropriate permissions
# </p>
#
# @param    log         Log File Handle
# @param    puedbh      Database Connection Handle
# @param    database    The Target Database name/server
# @param    currentMod  Current version mod file
# @param    outdir      Output Directory
# @return   number      Success: 0; Warning: 1; Error: 2
proc checkSchemaData {log puedbh database currentMod outdir} {
    printHeader $log "Analyzing System Data Status"

    source SysDataGen.tcl

    set dataValid [sysDataGen $puedbh $database $currentMod $outdir "no" "no" 1]
    updateInfo default_channel [getInfo preUpgradeEval.REPORT_HANDLE]
    if {    [lindex $dataValid 0] == 0
        &&  [lindex $dataValid 1] == 0
        &&  [lindex $dataValid 2] == 0
    } then {
        printResult $log "OK"

        return 0
    } else {
        putt $log ""
        printResult $log "Warning"

        return 1
    }
}

# <p>
#    <br> Check the the user has appropriate permissions on the db
# </p>
#
# @param    log     Log File Handle
# @param    puedbh  Database Connection Handle
# @return   number  Success: 0; Warning: 1; Error: 2
proc checkPermissions {log puedbh} {
    printHeader $log "Checking User Permissions"
    set ret 0
    catch {GrantCheck $log $puedbh} err
	if {$err != "0"} {
        putt $log " = = ERROR - User does not have sufficient privileges on the database."
        set ret 2
    }
	catch {FunctionalGrantCheck $log $puedbh} err
	if {$err != "0"} {
        putt $log " = = ERROR - User is missing privileges required to run this conversion.\n"
        incr ret
    }
    if {$ret == 0} {
        printResult $log "OK"
    }
	return $ret
}

# <p>
#    <br> Check for enabled invalid triggers
# </p>
#
# @param    puedbh  Database Connection Handle
# @param    log     Log File Handle
# @return   number  Success: 0; Warning: 1;
proc checkTriggers {puedbh log} {
    printHeader $log "Checking for enabled invalid triggers"
    set ret 0
    set triggerLst [getInvalidTriggers $puedbh]
    if {$triggerLst != 0} {
        putt $log " = = ERROR - The following triggers are invalid and enabled:\n"
        putt $log \t[join $triggerLst \n\t]\n
        putt $log " = = SQL to disable the triggers is as follows:"
        foreach item $triggerLst {
            putt $log "\tALTER TRIGGER $item DISABLE;"
        }
        set ret 1
        putt $log \n
        printResult $log "warning"
    }
    if {$ret == 0} {
        printResult $log "OK"
    }
    return $ret
}

# <p>
#    <br> Compare codes between two models for conflicts
# </p>
#
# @param    log         Log File Handle
# @param    currentMod  Current version mod file
# @param    targetMod   Target version mod file (to check)
# @return   number      Success: 0; Warning: 1; Error: 2
proc compareModelCodes {log currentMod targetMod} {
    printHeader $log "Comparing Model Codes"

    set codes [compareCodes $currentMod $targetMod "" $log]

    if {[string length $codes] > 1} {
        set     error_message "preUpgradeEval.tcl detected a code conflict between your two models.\n"
        append  error_message "The following code(s) is/are conflicted:\n\n"

        putt $log $error_message

        foreach code $codes {
            putt $log "$code\n"
        }

        printResult $log "Warning"
        return 1
    } else {
        printResult $log "OK"
        return 0
    }
}

# <p>
#    <br> Validate that all script entries in the SHS table have completed successfully
# </p>
#
# @param    log     Log File Handle
# @param    puedbh  Database Connection Handle
# @return   number  Success: 0; Warning: 1; Error: 2
proc validateShsEntries {log puedbh} {
    printHeader $log "Validating Previous Script Entries"

    set message ""

    append message [validateSHS $puedbh ""]

    if {[string length $message] > 1} {
        append message " = = ERROR - A previously run script did not complete correctly.\n"
        append message " Contact EXL Healthcare Support prior to proceeding.\n"

        putt $log $message

        printResult $log "Error"
        return 2
    } else {
        printResult $log "OK"
        return 0
    }
}

# <p>
#    <br> Checks for model files in the directory
# </p>
#
# @param    log             Log File Handle
# @param    currentMod      Current version mod file
# @param    short_target    Target Version Number for the Model Files
# @param    targetProduct   Target Product
# @param    target_model    Target Model File
# @return   number          Success: 0; Warning: 1; Error: 2
proc checkModelResources {log currentMod short_target targetProduct target_model} {
    printHeader $log "Checking for Required Model Files"

    if { [file exists "[file join [getInfo MODEL_FILES_DIRECTORY] $currentMod]" ] == 0 } {
        # then try the new style
        set     error_message " = = ERROR - Model Files for starting version are missing.\n\n"
        append  error_message " Copy them from the CD and restart preUpgradeEval.tcl.\n"

        putt $log $error_message

        return 2
    }

    # Check for the existence of model files for the TARGET version
    if  { [file exists "[file join [getInfo MODEL_FILES_DIRECTORY] $target_model]" ] == 0 } {
        set target_model "[file join [getInfo MODEL_FILES_DIRECTORY] Mod$targetProduct$short_target]"

        if { [file exists $target_model] == 0 } {
            set     error_message " = = ERROR - Model Files for target version are missing.\n"
            append  error_message " Checked for Mod$short_target and $target_model directories\n"
            append  error_message " Copy them from the CD and restart preUpgradeEval.tcl.\n"

            putt $log $error_message

            return 2
        }
    }

    printResult $log "OK"
    return 0
}

# <p>
#    <br> Verify all the companion tool scripts are available
# </p>
#
# @param    log             Log File Handle
# @param    targetProduct   The Target product (Short)
# @return   number          Success: 0; Warning: 1; Error: 2
proc checkToolResources {log targetProduct} {
    printHeader $log "Checking for Required Tools"

    set missing_tool "no"

    # Set tools list
    if { $targetProduct != "CR" } {
        set tcl_tools "dbCompare SysDataGen SysDeleteEval sy_load TblspAnalysis seqfix TaskImport"
    } else {
        set tcl_tools "dbvalid dbCompare SysDataGen SysDeleteEval sy_load TblspAnalysis seqfix"
    }

    # Check for tools
    foreach tool $tcl_tools {
        if { [file exists $tool.tcl] == 0 } {
            set missing_tool "yes"

            putt $log " = = ERROR - $tool.tcl is missing.\n"
        }
    }

    if {$missing_tool == "yes" } {
        set     error_message " The above named file(s) must be in the current directory.  Copy them from the\n"
        append  error_message " CD and restart preUpgradeEval.tcl.\n"
        append  error_message " \n"
        append  error_message " Please contact EXL Healthcare support for assistance locating the files.\n"

        putt $log $error_message

        return 2
    }

    printResult $log "OK"
    return 0
}

# <p>
#    <br> The main logic for preUpgradeEval.tcl
# </p>
#
# @param    puedbh      Database Connection Handle
# @param    ConvTxt     Driver File
# @param    email       Email Address to send completion email
# @param    silent      Silent tag (no input if set)
# @param    database    Target Database Handle
# @param    outdir      Output Directory
# @return   number      Success: 0; Warning: 1; Error: 2
proc preUpgradeEval {puedbh ConvTxt email silent database {outdir ""}} {
    global log
    set toolName preUpgradeEval
    setStartTime "$toolName"
    puts "\n[getInfo HR]"
    set here                "[pwd]/"
    set there               $here
    setInfo here $here

    if { [string range $here 0 0] != "/" } {
        regsub -all / $here \\ there
    }

    # Valid and currently used variables
    set errorFlag 0
    set failureFlag 0
    set warnFlag 0
    set message z
    set m_index_lst ""
    set m_table_lst ""
    set m_ind_col_lst ""
    set c_index_lst ""
    set c_table_lst ""
    set c_ind_col_lst ""
    set t_index_lst ""
    set t_table_lst ""
    set t_ind_col_lst ""
    set client_ind_col_lst ""
    set conflict_ind_col_lst ""
    set conflict_ind_lst ""
    set c_index_name ""
    set rpt z
    set fdb z
    set index_name z
    set index_lst z
    set tblsp_lst z
    set suffix z
    set preUpgradeEval z
    set displayDB [getDisplayConnection $database]
    set productName [getSchemaProduct $puedbh]
    set currentProduct [getProductPrefix $productName]
    set currentVersion [getSchemaVersion $puedbh]
    # validate currentVersion against old/ new versioning
    # prior to CR 1.6, used MR version, with no EBs.
    # set currentVersion [getCurrentVersion $currentProduct $currentVersion]
    set conversionInfo [getConversionInfo $ConvTxt $currentProduct $currentVersion]
    set short_current [join [p_unpad_version $currentVersion] ""]
    set filesuff "$currentProduct-$short_current"
    set suff [clock format [clock seconds] -format "%m%d%H%M" ]
    set reportfile $filesuff-Pre-Conversion-$suff.rpt

    set     error_message ""
    if [catch {getCurrentDriverRow $ConvTxt $currentVersion $currentProduct} currentInfo] {
        append  error_message " = = ERROR - $currentInfo"
        append  error_message " = = ERROR - preUpgradeEval.tcl cannot continue the evaluation."
        append  error_message ""
        append  error_message "\'$ConvTxt\' may be the wrong driver file for your start version or you may"
        append  error_message "need to run an EB script to bring your schema to a valid start version."
        append  error_message ""
        append  error_message "Currently your system is at version $currentVersion"
        append  error_message ""
        append  error_message "For assistance, please contact EXL Healthcare support:"
        append  error_message "[getInfo SupportContact]"
        set failureFlag [expr $failureFlag + 1]
    }
    set currentMod [lindex $currentInfo 4]
    set targetProduct [getFinalProduct $ConvTxt]
    set targetInfo [getTargetDriverRow $ConvTxt]
    set targetVersion [lindex $targetInfo 2]
    set targetMod [lindex $targetInfo 4]
    set short_target [join [p_unpad_version $targetVersion] ""]

    regexp {[0-9]+} $targetMod short_target
    set fullOutDateSuff [clock format [getStartTime $toolName] -format "%Y.%m.%d-%H.%M.%S"]
    if {$outdir == ""} {
        set cDotVir [join [p_unpad_version $currentVersion] "."]
        set tDotVir [join [p_unpad_version $targetVersion] "."]
        set outdir "$fullOutDateSuff\_CR$short_target-Eval"
    }
    setInfo $toolName.OUTDIR $outdir
    set log [getReportFile $toolName [getInfo $toolName.OUTDIR] $reportfile]
    updateInfo $toolName.REPORT_HANDLE $log
    updateInfo default_channel $log
    printInitialHeader $toolName [$toolName.getDescription] [$toolName.version].[$toolName.revision]
    putt $log $error_message

    if {$failureFlag ==  0} {
        if { [catch {open $ConvTxt r} scripts ] } {
            set     err " = = ERROR - $scripts.\n"
            append  err " Confirm that \'$ConvTxt\' exists and that you have read permissions.\n"

            putt $log $err

            set failureFlag [expr $failureFlag + 1]
        }

        if {$failureFlag ==  0} {
            set scripts_lst [split [read $scripts] \n]

            close $scripts
        }
    }

    # ------------------------------------------------------------------------------
    # Test for special characters in logon string
    # ------------------------------------------------------------------------------
     if {$failureFlag ==  0} {
        if [catch {testOracleScriptLogon $database} scriptLogonString] {
            putt "Cannot continue with conversion. $scriptLogonString. Unable to log on to sqlplus via command line."
            set failureFlag [expr $failureFlag + 1]
        }
        setInfo scriptLogonString $scriptLogonString
    }
    # ------------------------------------------------------------------------------
    # Check for User Permissions
    # ------------------------------------------------------------------------------
    if {$failureFlag ==  0} {
        set upval [checkPermissions $log $puedbh]
        if {$upval == 2} {
            set failureFlag [expr $failureFlag + 1]
        } elseif {$upval != 0 && ! [regexp {^01} $targetVersion]} {
            set failureFlag [expr $failureFlag + 1]
        }
    }

    # ------------------------------------------------------------------------------
    # Check for Tool Resources
    # ------------------------------------------------------------------------------
    if {$failureFlag ==  0} {
        if {[checkToolResources $log $targetProduct] == 2} {
            set failureFlag [expr $failureFlag + 1]
        }
    }

    # ------------------------------------------------------------------------------
    # Check for Model Resources
    # ------------------------------------------------------------------------------
    # target model now modGRMR

    if {$failureFlag ==  0} {
        if {[checkModelResources $log $currentMod $short_target $targetProduct $targetMod] == 2} {
            set failureFlag [expr $failureFlag + 1]
        }
    }

    # ------------------------------------------------------------------------------
    # Test for special handling of @ symbol
    # ------------------------------------------------------------------------------
    if {$failureFlag ==  0} {
        if {[catch {battyExecTest $scriptLogonString} sign] || $sign == 0 || $sign == ""} {
            putt "Error: Your environment cannot execute conversion scripts: $sign"
             set failureFlag [expr $failureFlag + 1]
        }
        setInfo sign $sign
    }
    # ------------------------------------------------------------------------------
    # If no failures, run tests
    # ------------------------------------------------------------------------------
    if {$failureFlag ==  0} {
        # ------------------------------------------------------------------------------
        # Compare codes between current model and target model files
        # ------------------------------------------------------------------------------
        if {[compareModelCodes $log $currentMod $targetMod] > 0} {
            set errorFlag [expr $errorFlag + 1]
        }

        # ------------------------------------------------------------------------------
        # Validate SHS
        # ------------------------------------------------------------------------------
        if {[validateShsEntries $log $puedbh] > 0} {
            set errorFlag [expr $errorFlag + 1]
        }

        # ------------------------------------------------------------------------------
        # checkIndexes
        # ------------------------------------------------------------------------------
        if {[checkIndexes $currentMod $targetMod $puedbh $log $ConvTxt] > 0} {
            set errorFlag [expr $errorFlag + 1]
        }

        # ------------------------------------------------------------------------------
        # p_checkscript
        # ------------------------------------------------------------------------------
        set scr_lst [lindex [getSHSscripts $puedbh] 1]
        set update_table_lst ""
        set tblsp_lst ""
        set pot_table ""
        set create_object ""

        set SQL_Statement  "select  distinct tablespace_name
                            into    :act_tblsp_lst
                            from    user_tables where tablespace_name is not null"
        execsql $SQL_Statement SQL_Error

        set SQL_Statement  "select  distinct tablespace_name
                            into    :add_tblsp_lst
                            from    user_indexes where tablespace_name is not null"
        execsql $SQL_Statement SQL_Error

        foreach tblsp $add_tblsp_lst {
            if {[ lsearch $act_tblsp_lst $tblsp ] < 0 } {
                lappend act_tblsp_lst $tblsp
            }
        }
        # ------------------------------------------------------------------------------
        # Analyze Tablespace using TblspAnalysis.tcl
        # ------------------------------------------------------------------------------
        if {[analyzeTblsp $log $puedbh $update_table_lst] > 0} {
            set errorFlag [expr $errorFlag + 1]
        }
         updateInfo default_channel [getInfo $toolName.REPORT_HANDLE]
        # ------------------------------------------------------------------------------
        # Checking for CTX and LOB Tablespaces
        # ------------------------------------------------------------------------------
        # if the conversion is to version 02.01.00.00 or greater, validate the existence of the max2_ctx_ts and max2_lob_ts tablespaces
        if {$targetVersion >= "02.01.00.00" && ($currentVersion < "02.01.00.00" || $currentProduct == "MC")} {
            printHeader $log "Checking for CTX and LOB Tablespaces"
            set ctxTS [validateCTXTableSpace $puedbh]
            set lobTS [validateLOBTableSpace $puedbh]
            set temp_string "\n"
            if {$ctxTS == 0} {
                append temp_string "WARNING: Please run CTXCreateTablespace.sql before running the conversion process.\n"
                set errorFlag [expr $errorFlag + 1]
            }
            if {$lobTS == 0} {
                append temp_string "WARNING: Please run LDSCreateTablespace.sql before running the conversion process.\n"
                set errorFlag [expr $errorFlag + 1]
            }
            if {$ctxTS == 0 || $lobTS == 0} {
                putt $log $temp_string
            } else {
                printResult $log "OK"
            }
            # report that the conversion will need at least twice the LDS table size
            printHeader $log "Checking LDS Table Size"
            set ldsSizeMB [GetLdsSize $puedbh $database]
            putt "LDS table size: $ldsSizeMB MB\n"
            set lobSizeMB [GetLobTblspcSize $puedbh]
            putt "LOB tablespace size: $lobSizeMB MB\n"
            if {[llength $lobSizeMB] == 1 && $ldsSizeMB >= $lobSizeMB} {
                putt "\n**********************************IMPORTANT*********************************"
                putt "The current LDS_LARGE_DATA_STORAGE table will be copied to a new tablespace"
                putt "during the course of this conversion."
                putt "Currently your LOB tablspace is $lobSizeMB MB and your LDS_LARGE_DATA_STORAGE"
                putt "table is $ldsSizeMB MB.  You must increase the size of the MAX2_LOB_TS"
                putt "tablespace by [expr {$ldsSizeMB - $lobSizeMB}] MB prior to running your"
                putt "conversion or the conversion will fail."
                putt "Ensure the datafile that supports the new tablespace has sufficient disk"
                putt "space.\n"
            } elseif {[llength $lobSizeMB] == 1 && $ldsSizeMB < $lobSizeMB} {
                printResult $log "OK"
            } elseif {[lindex $lobSizeMB 0] == -1} {
                putt "\n**********************************IMPORTANT*********************************"
                putt [lindex $lobSizeMB 1]
                putt "The current LDS_LARGE_DATA_STORAGE table will be copied to a new tablespace"
                putt "during the course of this conversion."
                putt "Your DBA will need to run LDSCreateTablespace.sql to create this tablespace."
                putt "Your DBA will need to ensure the tablespace is greater than or equal to"
                putt "$ldsSizeMB MB, preferably 10 percent larger to allow for future growth."
                putt "Ensure the datafile that supports the new tablespace has sufficient disk"
                putt "space.\n"
            } elseif {[lindex $lobSizeMB 0] == -1} {
                putt "\n**********************************IMPORTANT*********************************"
                putt [lindex $lobSizeMB 1]
                putt "The current LDS_LARGE_DATA_STORAGE table will be copied to a new LOB"
                putt "tablespace during the course of this conversion."
                putt "The LDSCreateTablespace.sql has been run but, the CareRadius default LOB"
                putt "tablespace name of MAX2_LOB_TS does not exist.  It may be that your DBA"
                putt "has set up a LOB tablespace of a different name onto which the LDS table"
                putt "will be moved.  Your DBA will need to ensure the tablespace is greater than"
                putt "or equal to $ldsSizeMB MB, preferably 10 percent larger to allow for"
                putt "future growth."
                putt "Ensure the datafile that supports the new tablespace has sufficient disk"
                putt "space."
                putt "The LDSMove.sql script will need to be modified by replacing all references"
                putt "to MAX2_LOB_TS prior to running the conversion with the tablespace name"
                putt "set up by your DBA, or the conversion will fail.\n"
            } else {
                putt "\n**********************************IMPORTANT*********************************"
                putt "Unknown result trying to determine status of LOB tablespace, MAX2_LOB_TS by"
                putt "default."
                putt "The current LDS_LARGE_DATA_STORAGE table will be copied to a new tablespace"
                putt "during the course of this conversion."
                putt "Your DBA may need to run LDSCreateTablespace.sql to create this tablespace."
                putt "Your DBA will need to ensure the tablespace is greater than or equal to"
                putt "$ldsSizeMB MB, preferably 10 percent larger to allow for future growth."
                putt "Ensure the datafile that supports the new tablespace has sufficient disk"
                putt "space.\n"
            }
        }

        # ------------------------------------------------------------------------------
        # Check EB Scripts
        # ------------------------------------------------------------------------------
        printHeader $log "Checking EB Scripts"

        set ebScripts_todo [getEBScripts $puedbh "ug_patch" $currentVersion $currentProduct]

        if {[llength $ebScripts_todo] != 0} {
            set     temp_string "\n"
            append  temp_string "WARNING: There are EB scripts that need to run before your schema\n"
            append  temp_string "can be certified.  Please run the following before beginning the\n"
            append  temp_string "conversion process.\n"

            foreach eb $ebScripts_todo {
                append temp_string "* $eb\n"
            }

            append  temp_string "\nPlease run these scripts using sqlplus as instructed in the readme file\n"
            append  temp_string "located in the \'ug_patch\' directory.\n\n"
            append  temp_string "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
            append  temp_string "        Skipping certification checks until EB scripts have been run\n"
            append  temp_string "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"

            putt $log $temp_string

            set warnFlag [expr $warnFlag + 1]
        } else {
            printResult $log "OK"

            # ------------------------------------------------------------------------------
            # Check Schema Certification (dbCompare)
            # ------------------------------------------------------------------------------
            if {[checkSchemaCertification $log $currentMod $puedbh $short_current] > 0} {
                putt [getInfo $toolName.REPORT_HANDLE] "STATUS: FAIL\n"
                set failureFlag [expr $failureFlag + 1]
            }
            updateInfo default_channel [getInfo $toolName.REPORT_HANDLE]
            # ------------------------------------------------------------------------------
            # Check Data Status (SysDataGen)
            # ------------------------------------------------------------------------------
            if {[checkSchemaData $log $puedbh $database $currentMod $outdir] > 0} {
                putt [getInfo $toolName.REPORT_HANDLE] "STATUS: FAIL\n"
                set failureFlag [expr $failureFlag + 1]
            }
            updateInfo default_channel [getInfo $toolName.REPORT_HANDLE]
        }
    }


    # TODO: What is del_append for?
    # set del_append ""

    # TODO: Fix this email structure CJC 7/30/12
    # if {$email != "" } {
        # if { [string first / [pwd]] == 0 } {
            # exec echo $message$del_append | mailx -s "preUpgradeEval.tcl complete" $email
        # } else {
            # LOGMess AutoScript $message$del_append
        # }
    # }

    # Print footer to the log (last thing to do to the log before moving to outdir)
    # putt $log [printPueFooter $displayDB $currentVersion $targetVersion $outdir $total_minutes $total_seconds]

    # ------------------------------------------------------------------------------
    # Move report files to the output directory
    # ------------------------------------------------------------------------------
    set delList ""
        putt " * * Moving Report Files to Output Directory * * "

        lappend delList [MoveOutput *_ug_new_tblsp* $outdir]
        lappend delList [MoveOutput cert*lst $outdir]
        lappend delList [MoveOutput *Analysis_*txt $outdir]

    # ------------------------------------------------------------------------------
    # Close the Log File and Delete Leftover Files
    # ------------------------------------------------------------------------------
    foreach del $delList {
        if {[file isfile $del]} {
            catch {file delete -force $del}
        }
    }

    # ------------------------------------------------------------------------------
    # Return
    # ------------------------------------------------------------------------------
    putt      [getInfo HR]
    if {$failureFlag > 0} {
        putt  "$toolName.tcl version [$toolName.version], revision [$toolName.revision] exited with major errors.\n"
        set     error_message "Failure: Prior to upgrading from $currentVersion to $targetVersion please review all of the\n"
        append  error_message "files created by preUpgradeEval.tcl in the $outdir directory.\n\n"
        append  error_message "This script exited with execution failure!"
        putt "$error_message"
        set RESULTS 2
        set STATUS "FAIL"
    } elseif {$errorFlag > 0} {
        set     error_message "Error: Prior to upgrading from $currentVersion to $targetVersion please review all of the\n"
        append  error_message "files created by preUpgradeEval.tcl in the $outdir directory.\n\n"
        append  error_message "This script exited with validation errors!"
        putt  "$toolName.tcl version [$toolName.version], revision [$toolName.revision] exited with errors.\n"
        putt "$error_message"
        set RESULTS 2
        set STATUS "ERROR"
    } elseif {$warnFlag > 0} {
        set     error_message "\n"
        append  error_message "WARNING: There are EB scripts that need to run before your schema\n"
        append  error_message "can be certified.  Please run the following before beginning the\n"
        append  error_message "conversion process.\n"
        append  error_message "\nPlease run these scripts using sqlplus as instructed in the readme file\n"
        append  error_message "located in the \'ug_patch\' directory.\n\n"
        append  error_message "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
        append  error_message "        Skipping certification checks until EB scripts have been run\n"
        append  error_message "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
        putt  "$toolName.tcl version [$toolName.version], revision [$toolName.revision] completed with warnings.\n"
        putt "$error_message"
        set RESULTS 1
        set STATUS "WARN"
    } else {
        putt  "$toolName.tcl version [$toolName.version], revision [$toolName.revision] successfully completed.\n"
         set RESULTS 0
         set STATUS "PASS"
    }
    putt "Pre-Conversion analysis reports for the $currentVersion to $targetVersion conversion"
    putt "are in directory $outdir"
    putt "Questions about the pre-conversion analysis reports should be directed to the "
    putt [getInfo SupportContact]
    set duration [getDuration [getStartTime $toolName]]
    putt      "Run Time was [prettyTime [hms $duration]]."
    putt      "END: [clock format [clock seconds] -format "[getInfo dateFormat] [getInfo timeFormat]"]"
    putt      [getInfo HR]
    putt    "RESULTS: $RESULTS"
    putt   "STATUS: $STATUS"
    setlog off $log
    unsetInfo preUpgradeEval*
    return $RESULTS
}

# <p>
#    <br> Proccess command line inputs
# </p>
#
# @param    argc    argc from command line
# @param    argv    argv from command line
# @return   list    {database driverFile emailAddr silent} from command line
proc getPUEInputs {argc argv} {
    set silent [lindex $argv end]

    if {[regexp -nocase "silent" $silent]} {
        set silent 1

        incr argc -1

        puts "Running in silent mode, user input will be suppressed."

        catch {putt $log "Running in silent mode, user input will be suppressed."}
    } else {
        set silent 0
    }

    if {$argc == 0} {
        pueHelp

        error "Insufficient arguments"
    } elseif { $argc < 2 } {
        pueUsage

        error "Insufficient arguments"
    }

    set dbase [lindex $argv 0]
    set ConvTxt [lindex $argv 1]

    if {![file exists $ConvTxt]} {
        set     err_mess "\n"
        append  err_mess " = = ERROR - The conversion driver file \'$ConvTxt\' does not exist.\n"
        append  err_mess " Please check your spelling and verify that it exists."

        error $err_mess
    }

    if {$argc == 3} {
        set email [lindex $argv 2]
    } else {
        set email ""
    }

    return [list $dbase $ConvTxt $email $silent]
}

# ===========================================================================================================================
#   Main Execution
# ===========================================================================================================================
if {[info exists argv0] && [string tolower [file tail $argv0]] == "preupgradeeval.tcl"} {
    if [catch  {set argv [getPUEInputs $argc $argv]} err] {
        puts $err
        exit 1
    }

    set log ""

    set database [lindex $argv 0]
    setInfo connectString $database

    set displayDB [getDisplayConnection $database]
    setInfo displayConnection $displayDB

    set ConvTxt [lindex $argv 1]

    set email [lindex $argv 2]
    setInfo email $email

    set silent [lindex $argv 3]
    setInfo silent $silent

	if {[catch {getLogonHandle $database} puedbh] || $puedbh < 0} {
        puts ""
        puts " = = ERROR - Could not login to $displayDB"
        puts ""
        puts " Check your spelling and try again.  Use either the complete string (e.g. proddb/mypass@servername) or the XAct Interface"
        puts " name (for example, M2PROD)."

        exit 2
    }
	setInfo DATABASE_HANDLE $puedbh
    # if client wants email notification, check that it works.
    if { $email != "" } {
        if [catch {checkEmail $email} err] {
            puts "Email Check has failed. $::errorInfo\n$err"
        }
    }

    exit [preUpgradeEval $puedbh $ConvTxt $email $silent $database]
}
