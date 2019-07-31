# Common_utilities.tcl
# TOC:
# STATIC GLOBAL CONSTANT
# LEGAL
# PRODUCT FUNCTIONS
# VERSION FUNCTIONS
# DRIVER FILE/ MODFILE FUNCTIONS
# DATABASE FUNCTIONS
# DATE / TIME FUNCTIONS
# DRIVER MODFILE FUNCTIONS
# INDEX
# SYSDATA
# I/O FUNCTIONS
# STRING/LIST FUNCTIONS
# SQL/DATABASE FUNCTIONS
# --------------------------------------------------------------------------#
# SECTION:            STATIC GLOBAL CONSTANTS
# --------------------------------------------------------------------------#
# set up the info array, if it doesn't exist at source time
if {![array exists DBS_INFO]} {
    array set DBS_INFO ""
}
# ##########
# @proc getInfo
# @ returns the values of a (static) global variable
# these should be set once, and should be fully qualified names to avoid collisions
# as array names does glob style matching, more than one value may be returned.
# Example: autoscript may set database logon handle here, or database display connction string
# ##########
# @author LAQ
# @param name the name of the element in the info array
# @exception none
# @see none
# @return the value of the array element, " if none"
# ##########
proc getInfo {name} {
    global DBS_INFO
    if {[string toupper $name] == "ALL"} {
        return [showArray DBS_INFO]
    }
    if {[set names [array names DBS_INFO $name]] != ""} {
        if {[llength $names] > 1} {
            foreach n $names {
                lappend retval $DBS_INFO($n)
            }
        } else {
            set retval $DBS_INFO($names)
        }
    } else {
        set retval ""
    }
    return $retval
}
# ##########
# @proc setInfo
# @ sets the name value pair into the info array
# # these should be set once, and should be fully qualified names to avoid collisions
# ##########
# @author LAQ
# @param name -element name
# @param value - element value
# @exception throws error, returns the value already set if that array element already exists.
# @see
# @return - new value that was set
# ##########
proc setInfo {name value} {
    global DBS_INFO
    if {[array names DBS_INFO $name] != "" } {
        error $DBS_INFO($name)
    } else {
        set DBS_INFO($name) $value
    }
    return $value
}
# ##########
# @proc unsetInfo
# @ unsets an info element, element pattern, or the whole array if "all" is passed.
# ##########
# @author LAQ
# @param name - the element name
# @exception
# @see
# @return 0
# ##########
proc unsetInfo {name} {
    global DBS_INFO
    if {$name == ""} {
    } elseif {$name == "all"} {
        unset DBS_INFO
    } elseif {[array names DBS_INFO $name] != ""} {
        foreach n [array names DBS_INFO $name] {
            unset DBS_INFO($n)
        }
    }
    return 0
}
# ##########
# @proc updateInfo
# @Update ths gloabl info array element to new value.  This should not be abused!
# ##########
# @author LAQ
# @param name element name
# @param value - new element value
# @exception - error if name doesn't exist
# @see
# @return error status
# ##########
proc updateInfo {name value} {
    global DBS_INFO
    catch {set DBS_INFO($name) $value} err
    return $err
}
proc isInfo {name} {
    global DBS_INFO
    if {[array names DBS_INFO $name] != "" } {
        return 1
    } else {
        return 0
    }
}
proc addInfo {args} {
    foreach {n v} [join $args] {
        if {![isInfo $n]} {
            updateInfo $n $v
        }
    }
}
# --------------------------------------------------------------------------#
# SECTION:    LEGAL
# --------------------------EXL Healthcare Information-------------#
if {[getInfo SupportContact] == ""} {
    set     contact_info "  Email:    EXLHealthcareSupport@exlservice.com\n"
    append  contact_info "  Phone:    (800) 669-4629\n"
    append  contact_info "  Website:  https://support.exlhealthcare.com"

    setInfo SupportContact $contact_info
}

if {[getInfo copyright] == ""} {
    setInfo copyright "Copyright ExlService Technology Solutions, LLC [clock format [clock seconds] -format "%Y"]"
}


# --------------------------------------------------------------------------#
# SECTION:    PRODUCT FUNCTIONS
# --------------------------------------------------------------------------#
# ##########
# @proc getSchemaProduct
# @Retrieves the database product information from SYS table
# ##########
# @author
# @param dbh database connection handle
# @exception (should return ) error if sql fails
# @see
# @return product
# ##########
proc getSchemaProduct {dbh} {
    set sysname ""
    set tabcount 0
    # CareFind has no SYS_SYSTEM_CONFIGURATION so, if the table doesn't exist, assume CAREFIND
    # This should be corrected so that application name can be queried.
    set sql "select count(*)
    into :tabcount
    from user_tab_columns where table_name = 'SYS_SYSTEM_CONFIGURATION'
    and column_name = 'SYS_APPLICATION_NAME'"
    catch {execsql use $dbh $sql} err
    if {$err < 0} {
        error "Could not query database."
    } elseif {$err == 100 || $tabcount == 0} {
        return "CAREFIND"
    }
    set sql "select sys_application_name
    into :sysname
    from sys_system_configuration
    where nvl(sys_last_update_date, sys_create_date) =
    (select max(nvl(sys_last_update_date, sys_create_date)) from sys_system_configuration)"
    execsql use $dbh $sql
    return $sysname
}
# ##########
# @proc getProductName
# @translates the product prefix to a product name
# ##########
# @author LAQ
# @param prefix
# @exception none
# @see
# @return product full (but condensed) name
# ##########
proc getProductName {prdPrefix} {
    switch $prdPrefix {
        "MC" {set product MaxMC}
        "M2" {set product Maxsys2}
        "CR" {set product CareRadius}
        "CF" {set product CareFind}
        default {set product $prdPrefix}
    }
    return $product
}
# ##########
# @proc getProductPrefix
# @translates the product name to the product prefix.
# ##########
# @author LAQ
# @param prodcut name
# @exception none
# @see
# @return prefix
# ##########
proc getProductPrefix {product} {
    switch [string toupper $product] {
        "MAXMC" {set prdPrefix MC}
      "MAXSYS II" -
        "MAXSYS2" {set prdPrefix M2}
        "CARERADIUS" {set prdPrefix CR}
        "CAREFIND" {set prdPrefix CF}
        default {set prdPrefix $product}
    }
    return $prdPrefix
}
# ##########
# @proc getFinalProduct
# @returns the final (target) product of the conversion
# this handles both new and old Autoconverison....txt styles.
# ##########
# @author LAQ
# @param driverFile name of driver file
# @exception
# @see this.srange
# @see this.getLines
# @return final product name
# ##########
proc getFinalProduct {driverFile} {
    if {[regexp {^autoconversion} [string tolower [file tail $driverFile]]]} {
        set finalInfo [getLines $driverFile]
        set finalProduct [lindex [lindex $finalInfo end] 3]
    }  else {
        set final [srange between "_" [file tail $driverFile] ]
        regexp {^[A-Za-z]{2,3}} $final finalProduct
        if {$finalProduct == "M" && [string range $final 1 1] == "2"} {
            set finalProduct "M2"
        }
    }
    return $finalProduct
}
# ##########
# @proc getScriptProduct
# @parses the script name to return the product prefix embedded in the beginning of the file name.
# ##########
# @author LAQ
# @param scriptName
# @exception none
# @see
# @return product prefix
# ##########
proc getScriptProduct {scriptName} {
    set prefix ""
    regexp -nocase {^([A-Za-z]{2,3})|(M2)} $scriptName prefix
    return $prefix
}
# --------------------------------------------------------------------------#
# SECTION:            VERSION FUNCTIONS
# --------------------------------------------------------------------------#
# ##########
# @proc getCurrentVersion
# @does special logic parsing to determine the version to use for validation
# based on the product and version string
# ##########
# @author LAQ
# @param product The product name (full)
# @param version version with decimals
# @see this.oldVersion
# @see this.p_unpad_version
# @return version string "MR" version, modfile version appended

proc getCurrentVersion {current_product version} {
    set cv_lst [p_pad_version $version]
    #for each product, have a defined cutoff version
# old versioning - plus special cases.
    if {$current_product == "MC"} {
        if {[lindex $cv_lst 0] < "09"} {
            return [oldVersion $cv_lst]
        } elseif {[lindex $cv_lst 0] == "09"} {
            if  {[lindex $cv_lst 1] == "00" && [lindex $cv_lst 2] < "05"} {
                return [oldVersion $cv_lst]
            # finally this special case..
            } elseif {[lindex $cv_lst 1] == "00" && [lindex $cv_lst 2] == "05"} {
                return "09.04.05"
            }
        }
    } elseif {$current_product == "M2"} {
        if {[lindex $cv_lst 0]  < "09"} {
            return [oldVersion $cv_lst]
        } elseif {[lindex $cv_lst 0]  == "09"} {
            if {[lindex $cv_lst 1]  == "00" && [lindex $cv_lst 2] < "10"} {
                return [oldVersion $cv_lst]
            }
        }
    }
    set CGR [lindex $cv_lst 0]
    set CMR [lindex $cv_lst 1]
    set CEB [lindex $cv_lst 2]
    if {$CEB == ""} {set CEB "00"}
    set cgr [p_unpad_version $CGR]
    set cmr [p_unpad_version $CMR]
    set ceb [p_unpad_version $CEB]
    set short_current $cgr$cmr$ceb
    if {$current_product == "CR" && "$CGR$CMR" < "0106"} {
        set currentMR "$CGR.$CMR.00"
    } else {
        set currentMR "$CGR.$CMR.$CEB"
    }
    return $currentMR
}
# ##########
# @proc oldVersion
# @translates version into old (pre- DB version numbers drop) version
# ##########
# @author LAQ
# @param cv_lst list of separate version elements
# @exception
# @see this.p_unpad_version
# @return version to use in validation
# ##########
proc oldVersion {cv_lst} {
    set CGR [lindex $cv_lst 0]
    set zeros [lindex $cv_lst 1]
    set zero [p_unpad_version $zeros]
    set CMR [lindex $cv_lst 2]
    set CEB [lindex $cv_lst 3]
    if {$CEB == ""} {set CEB "00"}
    set cgr [p_unpad_version $CGR]
    set cmr [p_unpad_version $CMR]
    set ceb [p_unpad_version $CEB]
    set short_current $cgr$zero$cmr
    set currentMR $CGR$zeros$CMR
    return  $CGR.$CMR.$CEB
}
# ##########
# @proc getEBscriptMRVersion
# @translates older versions to include digits 5,6 in check for EB scripts
# ##########
# @author LAQ
# @param product - product of schema.
# @param cv_lst list of separate version elements
# @exception
# @see this.p_unpad_version
# @return version to use for checking for EB script for a particular MR
# ##########
proc getEBscriptMRVersion {product versionString} {
        set cv_lst [p_pad_version $versionString]
# old versioning - plus special cases.
    if {$product == "MC"} {
        if {[lindex $cv_lst 0] < "09"} {
            set MRversion [join $cv_lst ""]
        } elseif {[lindex $cv_lst 0] == "09"} {
            if  {[lindex $cv_lst 1] == "00" && [lindex $cv_lst 2] < "05"} {
                set MRversion [join $cv_lst ""]
            # finally this special case..
            } elseif {[lindex $cv_lst 1] == "00" && [lindex $cv_lst 2] == "05"} {
                set MRversion "090004"
            }
        } else {
            set MRversion "[lindex $cv_lst 0][lindex $cv_lst 1]"
        }
    } elseif {$product == "M2"} {
        if {[lindex $cv_lst 0]  < "09"} {
            set MRversion [join $cv_lst ""]
        } elseif {[lindex $cv_lst 0]  == "09"} {
            if {[lindex $cv_lst 1]  == "00" && [lindex $cv_lst 2] < "10"} {
                set MRversion [join $cv_lst ""]
            }
        } else {
            set MRversion "[lindex $cv_lst 0][lindex $cv_lst 1]"
        }
    } else {
        set MRversion "[lindex $cv_lst 0][lindex $cv_lst 1]"
    }
    return $MRversion
}
# ##########
# @proc validateStartVersion
# @validates that the version passed in is a valid starting point for the driver file
# ##########
# @author
# @param driverFile
# @param currentProduct
# @param currentVersion
# @exception driver file not found
# @see p_pad_version
# @see getDriverInfo
# @return 0 = current version is already at target; 1 - valid start version; -1 cannot determine conversion path
# ##########
proc validateStartVersion {driverFile currentProduct currentVersion} {
    set cv  [p_pad_version $currentVersion]
    set test -1
    if {[regexp {^autoconversion} [string tolower [file tail $driverFile]]]} {
        set testvs [join [lrange $cv 0 end-1] "."]
        set testvf [join $cv "."]
        set versioninfo [getDriverInfo $driverFile]
        set versions [lindex $versioninfo 2]
        set prds [lindex $versioninfo 3]
        for {set i 0} {$i < [llength $versions]} {incr i} {
            if {$currentProduct != [lindex $prds $i]} {continue}
            set v [lindex $versions $i]
            set vl [p_pad_version $v]
            set vs [join [lrange $vl 0 end-1] "."]
            set vf [join $vl "."]
            if {$vs <= $testvs} {
                set test 0
            }
            if {$vf > $testvf} {
                if {$test == 0} {
                    set test 1
                    break
                }
            }
        }
    } else {
        #old style driver file
        set testvs [join [lrange $cv 0 end-1] ""]
        set testvf [join $cv ""]
        set df [file tail $driverFile]
        set vlist [split $driverFile "_"]
        regexp {\d{4}} $[lindex $vlist 0] vs
        regexp {\d{6}} $[lindex $vlist 1] vf
        if {$vs == "" || $vf == ""} {
            error "Invalid driver file name."
        }
        if {$vs <= $testvs && $testvf < $vf} {
            set test $testvs
        } elseif {$testvf >= $vf} {
            set test 0
        }
    }
    return $test
}
# ##########
# @proc getSHSscripts
# @ gets all SHS script entries of type ('CREATE','UPDATE','EB','CUSTOM')
# ##########
# @author BCP
# @param dbh -database handle
# @exception on database error.
# @see
# @return list of lists [SHS_VERSION_NEW, SHS_SSQL_SCRIPT_NAME, SHS_RESULTS] that have been run.
# TODO: pass script types as param?
# ##########
proc getSHSscripts {dbh} {
    set scr_lst ""
    set SQL "select shs_version_new, shs_sql_script_name, shs_results
    into :ver_lst,
         :scr_lst,
         :res_lst
    from shs_schema_history where shs_type in ('CREATE','UPDATE','EB','CUSTOM')
    order by shs_uid desc"
    catch {execsql use $dbh $SQL} err
    if {$err < 0} {error "Unable to get schema history. $::errorInfo \n$[getinfo all]"}
    return [list $ver_lst $scr_lst $res_lst]
}
# ##########
# @proc getScriptHistory
# @ like getSHSscripts, but only gets non null version
# ##########
# @author
# @param
# @exception
# @see
# @return list {version_new scriptname}
# todo: catch sql error, reconcile to above
# ##########
proc getScriptHistory {dbh} {
    set SQL "select shs_version_new, shs_sql_script_name
    into :version_lst, :scr_lst
    from shs_schema_history where shs_type in ('CREATE','UPDATE','EB')
    and shs_version_new is not null order by shs_uid desc"
    execsql use $dbh $SQL
    return [list $version_lst $scr_lst]
}

# ##########
# @proc validateSHS
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# todo: get it working!
# ##########
proc validateSHS {DBH {modelVersion ""}} {
    set message ""
set SQL_Statement "select count(*) into :ct_ex from user_tables where table_name =  'EXCEPTIONS'"
    execsql use $DBH $SQL_Statement SQL_Error
    if { $ct_ex == 1 } {
         append message "*** Error *** Exceptions Table found on [getInfo displayConnection].\n\n"
     }
    set SQL_Statement "select shs_sql_script_name into :err_name from shs_schema_history where
        shs_type in ('CREATE', 'UPDATE', 'EB') and shs_results not like 'Success%'"
    if { [execsql use $DBH $SQL_Statement SQL_Error] == 0 } {
         append message $err_name
    }
    catch {checkBackTables $DBH} err
    if {$err != ""} {
        append message $err
    }

    return $message
}

# ##########
# @proc getPLSQLFileVersion
# @
# ##########
# @author LAQ
# @param PlSQL package body filename
# @exception none
# @see
# @return list package version , package revision ; default 0 0
# ##########
proc getPLSQLFileVersion {fileName} {
    set packageVersion 0
    set packageRevision 0
    set conts ""
    catch {set fid [open $fileName r]
    set conts [read $fid]
    close $fid
    }
    if {[regexp {LC_PACKAGE_VERSION\s*:=\s*[^\s]+} $conts packageVersion]} {
        regsub {.*:=} $packageVersion "" packageVersion
        regsub {;\s*} $packageVersion "" packageVersion
        regsub -all {'} $packageVersion "" packageVersion
        set packageVersion [string trim $packageVersion]
    }
    if {[regexp {LC_PACKAGE_REVISION\s*:=\s*[^\s]+} $conts packageRevision]} {
        regsub {.*:=} $packageRevision "" packageRevision
        regsub {;\s*} $packageRevision "" packageRevision
        set packageRevision [string trim $packageRevision]
    }
    return [list $packageVersion $packageRevision]
}
proc loadLandaPackage {DBH workingDir outDir log} {
        set sql "select count(table_name) into :tcount from user_tables where table_name = 'SCH_CHANGE_HISTORY'"
        execsql use $DBH $sql
        if {$tcount > 0} {
            set packageVersion [lindex [getPLSQLFileVersion [file join $workingDir "Packages" LANDA_CONVERSION_BODY.sql]] 0]
            set sql "select SCH_ID, SCH_SCH_ID_PARENT into :plversion, :plrevision from SCH_CHANGE_HISTORY where SCH_UID < 0 and SCH_SHS_SCRIPT = 'PACKAGE_VERSION'"
            execsql use $DBH $sql
            if {$plversion == {} || $plversion < "$packageVersion"} {
                set pscripts [lsort [glob -nocomplain -tails -directory [file join $workingDir "Packages"] LANDA_PACKAGE_UPDATE*.sql]]
                if {$pscripts != ""} {
                    foreach pscript $pscripts {
                        set sql "select SHS_RESULTS into :status from SHS_SCHEMA_HISTORY where SHS_SQL_SCRIPT_NAME = '$pscript'"
                        execsql use $DBH $sql
                        if {$status != "Successful"} {
                            putt "running LANDA_PACKAGE UPDATE script $pscript..."
                            catch {run_SQL_Script [getInfo scriptLogonString] "$pscript" "LANDA_PACKAGE_UPDATE.bat" [file join $workingDir "Packages"] [getInfo sign]} err
                            if {$err != 0} {
                                putt $log "Failure running $pscript"
                                putt $log $err
                                return -1
                            }
                            lappend delete_it_lst [MoveOutput "[file rootname $pscript]*.lst" $outDir]
                            file delete [file join $workingDir "Packages" LANDA_PACKAGE_UPDATE.bat]
                        }
                    }
                }
            }
    }
    puts "Loading LANDA_CONVERSION Package..."
    catch {run_SQL_Script [getInfo scriptLogonString] "LANDA_CONVERSION_SOURCE.sql" "LANDA_CONVERSION_SOURCE.bat" [file join $workingDir "Packages"] [getInfo sign]} err
    if {$err != 0} {
        putt $log "Failure on loading LANDA_CONVERSION package."
        putt $log $err
        unsetInfo WORKING_DIRECTORY
        setInfo WORKING_DIRECTORY $workingDir
        return -1
    }
    lappend delete_it_lst [MoveOutput "LANDA_CONVERSION_SOURCE*.lst" $outDir]
    file delete -force [file join $workingDir "Packages" LANDA_CONVERSION_SOURCE.bat]
    return 0
}
proc loadTextStorage {workingDir outDir log} {
    puts "Loading text storage preference..."
    catch {run_SQL_Script [getInfo scriptLogonString] "CTXTextStorage.sql" "CTXTextStorage.bat" [file join $workingDir "Scripts"]  [getInfo sign]} err
    if {$err != 0} {
        putt $log "Failure on creating text storage preference."
        putt $log $err
        unsetInfo WORKING_DIRECTORY
        setInfo WORKING_DIRECTORY $workingDir
        return -1
    }
    lappend delete_it_lst [MoveOutput "CTXTextStorage_*.lst" $outDir]
    lappend delete_it_lst [MoveOutput "Scripts/CTXTextStorage.bat" $outDir]
    file delete -force Scripts/CTXTextStorage.bat
    return 0
}
# --------------------------------------------------------------------------#
# SECTION:            DRIVER FILE/ MODFILE FUNCTIONS
# --------------------------------------------------------------------------#
# ##########
# @proc getDriverInfo
# @gets all info from the driver file
# ##########
# @author
# @param driverFile
# @exception none
# @see
# @return list {linenumbers scriptnames versions products moddirectories}
# todo catch file not found
# ##########
proc getDriverInfo {driverFile} {
        set autoConLines [getLines $driverFile]
        #split the data up into line number, scriptname, shs_version, product, and Mod directory
        foreach line $autoConLines {
            if {$line == ""} {continue}
            lappend autoConlineNums [lindex $line 0]
            lappend autoConScriptNames [lindex $line 1]
            lappend autoConVerNums [lindex $line 2]
            lappend autoConProducts [lindex $line 3]
            lappend autoConModDirs [lindex $line 4]
        }
    return  [list $autoConlineNums $autoConScriptNames $autoConVerNums $autoConProducts $autoConModDirs]
}

proc readFileArgs {fileName} {
    set lines ""
    set err ""
    catch {set lines [getLines $fileName]} err
    if {$err != "" && $lines == ""} {
        error "$err"
    }
    foreach line $lines {
        set args [split $line "="]
        updateInfo [string trimleft [lindex $args 0]] [string trimright [lindex $args 1]]
    }
    
}

proc p_getParams {args scriptName} {
    set paramFile "input_params.txt"
    set newargs [p_getInputParams $args]
    if {$newargs == ""} {
        if {$args == ""} {
            catch {readFileArgs $paramFile} err
            if {$err != ""} {
                error "$err"
            }
        } else {
            if {[getInfo INPUTFILE] != ""} {
                catch {readFileArgs [getInfo INPUTFILE]} err
                if {$err != ""} {
                    error "$err"
                }
            } else {
                error "ERROR - Please pass parameter inputFile=fileName.txt"
            }
        }
        set missingVals ""
        if {[getInfo CARERADIUS_SCHEMA_NAME] == "" } {
            lappend missingVals "A value needed for CARERADIUS_SCHEMA_NAME"
        }
        if {[getInfo CARERADIUS_SCHEMA_PASSWORD] == "" } {
            lappend missingVals "A value needed for CARERADIUS_SCHEMA_PASSWORD"
        }
        if {[getInfo DB_HOST_INFO] == "" } {
            lappend missingVals "A value needed for DB_HOST_INFO"
        }
        set connString "[getInfo CARERADIUS_SCHEMA_NAME]/[getInfo CARERADIUS_SCHEMA_PASSWORD]@[getInfo DB_HOST_INFO]"
        switch $scriptName {
            dbCompare {
                set newargs [list [getInfo MODEL_DIR] $connString [getInfo OUTPUT_FILE]]
            }
            AutoScript {
                if {[getInfo AUTOCONVERSION_FILE] != "" && [getInfo AUTO_DROP_COLUMNS] != ""} {
                    set newargs [list $connString [getInfo AUTOCONVERSION_FILE] [getInfo AUTO_DROP_COLUMNS] [getInfo EMAIL] [getInfo SILENT]]
                } else {
                    error "AUTOCONVERSION_FILE and AUTO_DROP_COLUMNS can't be null in Input File.\nPlease provide correct input."
                }
            }
        }
        if {$missingVals != ""} {
            error "Invalid argument list $missingVals"
        }
    }
    return $newargs
}

# Description : return parameter if passed a filename as a input parameter
# @author   Anurag Tripathi 
# @param    inputs passed to passing script
# @param    if inputs will have a filename passed in format "file=filename" it will read parameter written in the file and will return
# @return   inputs
proc p_getInputParams {args} {
    set newargs ""
    set args [join $args]
    foreach arg [split $args] {
      if {[regexp {=} $arg]} {
          set nv [split $arg "="]
          updateInfo [string toupper [string trimleft [lindex $nv 0] "-"]] [lindex $nv 1]
      } else {
          lappend newargs $arg
      }
    }
    return $newargs
}

# p_getCurrModDir: Procedure to get the current mod file directory
# inputs: conversion text file name, current version of the schema (as is in shs table, 01.06.05), short Current version (165)
# returns the current model file directory name or -1 if error.
proc p_getCurrModDir {driverFile currentVersion shortCurrVersion} {
    if {[regexp {^autoconversion} [string tolower [file tail $driverFile]]]} {
        if {$currentVersion == ""} {
            return -1
        }
        set lines [getLines $driverFile]
        if {$lines == -1} {
            return -1
        }
        set indices ""
        set indices [lsearch -glob $lines "*$currentVersion*"]
        if {$indices == -1} {
            puts "Could not find version information in [file tail $driverFile] for $currentVersion."
            return -1
        }
        set index [lindex $indices end]
        set line [lindex $lines $index]
        set modFileDir [lindex $line 4]
        return $modFileDir
    } else {
        set modFileDir "Mod$shortCurrVersion"
        return $modFileDir
    }
}

# p_getTargetModDir: Procedure to get the target mod file directory
# inputs: conversion text file name, short target version (165)
# returns the current model file directory name or -1 if error.
proc p_getTargetModDir {driverFile shortTargetVersion} {
    if {[regexp {^autoconversion} [string tolower [file tail $driverFile]]]} {
        set lines [getLines $driverFile]
        if {$lines == -1} {
            return -1
        }
        foreach line $lines {
            set line [lindex $lines end]
            set modFileDir [lindex $line 4]
            return $modFileDir
        }
    } else {
        set modFileDir "Mod$shortTargetVersion"
        return $modFileDir
    }
}
# ##########
# @proc getConversionInfo
# @finds the last line in the driver file associated with the current version, and returns the contents after that
# ##########
# @author LAQ
# @param driverFile
# @param currentProduct of schema
# @param currentVersion or schema
# @exception noe
# @see this.lrange
# @return driverFile contents after current version listings
# ##########
proc getConversionInfo {driverFile currentProduct currentVersion} {
    if {[catch {set lines [getLines $driverFile]} err]} {
        error $err
    }
    set index "-1"
    for {set i 0} {$i < [llength $lines]} {incr i} {
        set currline [lindex $lines $i]
        if {[regexp "^[lindex $currline 2]\$" "$currentVersion"]} {
            if {[llength $currline] > 3} {
                if {[lindex $currline 3] != $currentProduct} {continue}
            }
            set index $i
            break
        } elseif {[regexp "^[lindex $currline 2]\$"  "$currentVersion"]} {
            if {[llength $currline] > 3} {
                if {[lindex $currline 3] != $currentProduct} {continue}
            }
            if {[lindex $currline 1] == "START"} {
            set index $i
            break
            }
        }
    }
    if {$index == -1} {
        putt "Could not find an entry in [file tail $driverFile] for $currentVersion."
        set lines ""
    } else {
        # break above and following line comment by BCP.  I think we want to validate current version scripts have been run.
        #incr index
        set lines [lrange $lines $index end]
    }
    return $lines
}
proc getDriverFile {{workingdir ""}} {
    return [join [glob -nocomplain [filejoinx $workingdir AutoConversion.txt]]]

}
# ##########
# @proc getFirstDriverRowInfo
# @finds the first line in the driver file that matches the token
# ##########
# @author LAQ
# @param targetToken search token
# @param getItem optional default all which item from the line {script version, prd or moddir}
# @param currentVersion or schema
# @exception noe
# @see this.getLines
# @see this.getDriverFile
# @return first driverFile line matching token
# ##########
proc getFirstDriverRowInfo {targetToken {getitem all}} {
    if {[catch {set lines [getLines [getDriverFile [getInfo WORKING_DIRECTORY]]]} err]} {
        error "Could not find a Driver file $err"
    }
    set index [lsearch $lines *$targetToken*]
    set line [lindex $lines $index]
    switch $getitem {
        "all" {return $line}
        ID {return [lindex $line 0]}
        scriptName {
            set names [lindex $line 1]
            while {[lsearch [lindex $lines [incr index]] $targetToken] > 0} {
                lappend names [lindex $line 1]
            }
            return $names
        }
        schemaVersion {return [lindex $line 2]}
        prd {return [lindex $line 3]}
        ModDir {return [lindex $line 4]}
    }
}
# getCurrDriverRow: Procedure to get the current row of the driverFile
# inputs: driver file name, current version of the schema (as is in shs table, 01.06.05)
# returns the current model file directory name
# @author bcp
proc getCurrentDriverRow {driverFile currentVersion {currentProduct ""}} {
    if {[catch {set lines [getLines $driverFile]} err]} {
        error $err
    }
    set index -1
    for {set i 0} {$i < [llength $lines]} {incr i} {
        if {[regexp "^[lindex [lindex $lines $i] 2]\$" "$currentVersion"]} {
            set index $i
        }
    }
    if {$index == -1} {
        error "Could not find a line in [file tail $driverFile] for $currentVersion."
    } elseif {$currentProduct != ""} {
    if {![regexp $currentProduct [lindex [lindex $lines $index] 3]]} {
        error "Could not find a line [file tail $driverFile] for $currentVersion."
    }
  }
    set line [lindex $lines $index]
    return $line
}
# getCurrDriverRows: Procedure to get all the rows that pertain to the current version
# inputs: driver file name, current version of the schema (as is in shs table, 01.06.05)
# returns all rows of driver file that pertain to the current version.
# @author bcp
proc getCurrentDriverRows {driverFile currentVersion {currentProduct ""}} {
    if {[catch {set lines [getLines $driverFile]} err]} {
        error $err
    }
    set lineLst ""
    for {set i 0} {$i < [llength $lines]} {incr i} {
        if {[regexp "^[lindex [lindex $lines $i] 2]\$" "$currentVersion" ] && [lindex [lindex $lines $i] 3] == $currentProduct && [lindex [lindex $lines $i] 1] == "START"} {
            lappend lineLst [lindex $lines $i]
        } elseif {[regexp "^[lindex [lindex $lines $i] 2]\$" "$currentVersion"]  && [lindex [lindex $lines $i] 3] == $currentProduct && [lindex [lindex $lines $i] 1] != "START"} {
            lappend lineLst [lindex $lines $i]
        }
    }
    if {$lineLst == ""} {
        error "Could not find a line in [file tail $driverFile] for $currentVersion."
    }
    return $lineLst
}
# getPrevDriverRow: Procedure to get the current row of the driverFile
# inputs: driver file name, script name
# returns the driver file line prior to the line containing the provided script name (excluding START lines).
# @author bcp
proc getPrevDriverRow {driverFile currentScript} {
    if {[catch {set lines [getLines $driverFile]} err]} {
        error $err
    }
    set i 0
    set j 1
    set done false
    set temp_line ""
    for {set i 0} {$i < [llength $lines]} {incr i} {
        if {$currentScript == [lindex $lines $i 1] && [lindex $lines $i 1] != "START"} {
            while {!$done} {
                if {[expr $i - $j] < 0} {
                    set temp_line -1
                    puts "$currentScript is the first script in [file tail $driverFile]."
                    return -1
                } else {
                    set temp_line [lindex $lines [expr $i - $j]]
                    if {[lindex $temp_line 1] == "START"} {
                        incr j
                    } else {
                        set done true
                    }
                }
            }
        }
    }
    if {[llength $temp_line] == 0} {
        puts "Could not locate $currentScript in [file tail $driverFile]."
        return -1
    }
    return $temp_line
}

# ##########
# @proc checkModelFileResources
# @Checks that all model files referenced in the autoconversion driver file exist.
# ##########
# @author LAQ
# @param conversionInfo information from the driver file
# @param path (optional) path to model file directories
# @exception
# @see
# @return "" or list of items not found
# todo: check for file existence?
# ##########
proc checkModelFileResources {conversionInfo {path ""}} {
    set notfound ""
    foreach line $conversionInfo {
        set modfile [file join $path [lindex $line 4]]
        if {![file exists $modfile]} {
            if {[lsearch $notfound $modfile] < 0} {
                lappend notfound $modfile
            }
        }
    }
    return $notfound
}
# getModFileVer: Procedure to get version from MODEL_VERSION file
# input: model folder directory structure
# returns the current model file's version from the MODEL_VERSION file
# @author bcp

proc getModFileVer {modDir} {
    set inf [getLines "$modDir/MODEL_VERSION"]
    if {$inf == ""} {
        error "\nFile does not contain version information or is not formatted correctly."
    } else {
        return [string trim [lindex $inf 0]]
    }
}

# getTargetDriverRow: Procedure to get the target mod file directory
# inputs: conversion text file name
# returns the last row of the driver file
# @author bcp
proc getTargetDriverRow {driverFile {version ""}} {
    if {[catch {set lines [getLines $driverFile]} err]} {
        error $err
    }
    if {$version != ""} {
          set line [lindex $lines [lsearch $lines *$version*]]
      } else {
           set line [lindex $lines end]
      }
    return $line
}

# getScriptsToRun: Procedure to determine which scripts in the driver file to run
# inputs: driver file, db connection, current product (optional), current version (optional)
# returns list of driver file lines from the first current version line to the end of the file that have not been run against the schema.
# @author bcp
# todo: this is less than optimal - focus on base functionality of checking scripts
# recommend send in scripts to run as parameter, (use getConversionInfo )
# send in current product and version as hard params, have calling script supply
# rename to reflect better the validation of scripts to run. (BCP - Done)
proc scriptsToRun {scriptLines dbScripts} {
    set toRun ""
    set index ""
    foreach scriptLine $scriptLines {
        if {[lindex $scriptLine 1] != "START"} {
            # check for Creation script of same name
            set test_scriptname [lindex $scriptLine 1]
            if {[lsearch [lindex $dbScripts 1] CR$test_scriptname] >= 0} {
                puts "Found creation script $test_scriptname"
            } else {
                # search all instances of the AutoConversion script in the list of run scripts and store list indices in dbScriptsInd
                set dbScriptsInd [lsearch -all [lindex $dbScripts 1] $test_scriptname]
                if {$dbScriptsInd != "" } {
                    if {$test_scriptname != ""} {
                        # set add to 1 assuming we will need to add current script to the list of scripts to run
                        set add 1
                        # for each list index check to see if the script(s) for the current version has/have been run to completion.
                        # This allows the current driver script and/or the FDD script for the current version to be run again without
                        # immediatly causing a failed conversion if restart is not set.
                        # If all these conditions meet, don't add the script to the list of scripts to run, set the add variable to 0.
                        foreach ind $dbScriptsInd {
                            # puts "[lindex $dbScripts 1 $ind] == $test_scriptname && [lindex $dbScripts 0 $ind] == [lindex $scriptLine 2] && [lindex $dbScripts 2 $ind] == \"Successful\""
                            if {[lindex $dbScripts 1 $ind] == $test_scriptname && [lindex $dbScripts 0 $ind] == [lindex $scriptLine 2] && [lindex $dbScripts 2 $ind] == "Successful"} {
                                set add 0
                            }
                        }
                        if {$add == 1} {
                            lappend toRun $scriptLine
                        }
                    }
                } else {
                    lappend toRun $scriptLine
                }
            }
        }
    }
    return $toRun
}
# ##########
# @proc getEBScripts
# @Determines if the current schema has eb scripts that must be run
# Checks the ug_patch directory for scripts that match the mr version
# ##########
# @author LAQ
# @param dbh database handle
# @param ugDir directory EB scripts are housed
# @param currentMR version to compare to
# @param prd current product
# @exception
# @see
# @return list of EB scripts that must be run.
# ##########
proc getEBScripts {dbh ugDir currentMR prd {short_current ""} } {
set ebScripts_todo ""
set eb_scripts ""
    if  [file exists "$ugDir"] {
        set patchFile [glob -directory $ugDir patches.txt]
        set conts [getLines $patchFile]
        foreach line $conts {
            if {[regexp [lindex $line 2]  "$currentMR"]} {
                lappend eb_scripts [lindex $line 1]
            }
        }
        set i 0
        foreach seb $eb_scripts {
            set SQL_Statement "select count(*) into :ebcount from shs_schema_history where shs_sql_script_name = '[file tail $seb]'"
            catch {execsql use $dbh $SQL_Statement SQL_Error} err
            if {$err == 100  || $ebcount == 0} {
                lappend ebScripts_todo "EB$i $seb $currentMR"
            }
            incr i
        }
    } else {
        #may not be an error=
        # todo = decide how to handle this
    }
    return $ebScripts_todo
}
# --------------------------------------------------------------------------#
# SECTION:            DATABASE FUNCTIONS
# --------------------------------------------------------------------------#
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getLogonHandle {connectionString} {
    if {[catch {logon $connectionString} DBH ] || $DBH < 0} {
        if {$DBH < 0} {
            error "Failed to logon to [getDisplayConnection $connectionString]:\n$DBH"
        }
        error "Error while connecting [getDisplayConnection $connectionString]:\n$DBH "
    }
    return $DBH
}
# ##########
# @proc getSQLplus
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getSQLPLUS {} {
    if {[set sqlplus [getInfo sqlplus]] == ""} {
        if {[catch {exec sqlplus -version} err] } {
            if {!([info exists ::env(ORACLE_HOME)])} {
                set oracleHome ""
                set ocs [lsort [array names ::env ORACLE_HOME*]]
                foreach oc $ocs {
                        if {[regexp -nocase {EXE$} $oc] == 1} {continue}
                        set oracleHome $::env($oc)
                }
                regsub -all {\\} $oracleHome "/" path
                set sqlplus [glob -nocomplain  $path/BIN/sqlplus*]
                set i [lsearch $sqlplus *.sh]
                if {$i < 0 } {
                    set i [lsearch $sqlplus *sqlplus]
                    if {$i < 0} {
                        set i [lsearch $sqlplus *.exe]
                    } else {set sqlplus $path/BIN/sqlplus}
                }
                if {$i < 0} {error "Cannot find executable sqlplus.exe or sqlplus.sh This must be defined for this script to run."}
                set sqlplus [lindex $sqlplus $i]
            } else {
                if {![catch {glob "[file join $::env(ORACLE_HOME) BIN sqlplus.exe]"} sqlplus]} {
                } elseif {![catch {glob "[file join $::env(ORACLE_HOME) BIN sqlplus.sh]"} sqlplus]} {
                } elseif {![catch {glob "[file join $::env(ORACLE_HOME) BIN sqlplus]"} sqlplus]} {
                } else {
                    error "Cannot find executable sqlplus.exe or sqlplus.sh This must be defined for this script to run."
                }
            }
        } else {
            set sqlplus sqlplus
        }
        setInfo sqlplus $sqlplus
    }
    set ::errorInfo ""
    return $sqlplus
}
# --------------------------------------------------------------------------#
# SECTION:            DATE / TIME FUNCTIONS
# --------------------------------------------------------------------------#
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc date_now {} {
    return [clock format [clock seconds] -format "%m/%d/%Y"]
}
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc time_now {} {
    return [clock format [clock seconds] -format "%H%M"]
}
# calculates time differential of end time from start time (in seconds)
# params
# end - end time (seconds)
# start - start time (second)
# type
#   all: hours:mins:secs
#   secs: seconds
#note: does no padding.
proc getDuration {start {end -1}} {
    if {$end < 0} {set end [clock seconds]}
    return [expr $end - $start]
}
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getDurationDots {end start {type all}} {
    set duration [getDuration $start $end]
    if {$type == "secs"} {return $duration}
    set hours [expr $duration / 3600]
    set secs [expr $duration % 3600]
    set mins [expr $secs / 60]
    set secs [expr $secs % 60]
    return $hours.$mins.$secs
}

# formatting function
# returns duration x hours, y minutes, z seconds
#     or y minutes, z seconds
#       or z seconds
proc prettyTime {hms} {
    set hours [lindex $hms 0] ; set mins [lindex $hms 1] ; set secs [lindex $hms 2];
    if {$hours != 0} {set hours "$hours hours, "} else {set hours ""}
    if {$mins != 0 || $hours != ""} {set mins "$mins minutes, "} else {set mins ""}
    set secs "$secs seconds"
    return $hours$mins$secs
}
# p_getDbDate
# author laq
# convenience function to get formatted date from database
# params
# dbh = database handle
# returns space separated string (can be used as list)
proc p_getDbDate {dbh} {
    set SQL_Statement "select to_char(sysdate, 'YYYY MON DD') into :date_cell from dual"
    execsql use $dbh $SQL_Statement SQL_Error
    return [lindex $date_cell 0]
}
# calculates time differential in hours minutes seconds
#note: does no padding.
proc hms {duration} {
    if {[regexp {^([0-9]+)$} $duration]} {
        set hours [expr int($duration / 3600)]
        set duration [expr $duration % 3600]
        set mins [expr int ($duration / 60)]
        set secs [expr $duration % 60]
        return "$hours $mins $secs"
    } else {
        return "Not a valid Input"
    }
}
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getDurationHMS {startTime {endTime -1}} {
    return [hms [getDuration $startTime $endTime ]]
}
proc prettyDuration {startTime  format {endTime -1}} {

}
# --------------------------------------------------------------------------#
# SECTION:            DRIVER MODFILE FUNCTIONS
# --------------------------------------------------------------------------#
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getModelConstraints {modelConstraints table} {
  set index [lsearch -glob $modelConstraints $table*]
  if {$index < 0} {
   set retval ""
  } else {
    set retval [lindex $modelConstraints $index]
  }
  return $retval
}
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getModelConstraintColumns {modelConsColumns tabPrefix} {
    set retval ""
    set found 0
    foreach line $modelConsColumns {
      if [regexp "^$tabPrefix" $line] {
        lappend retval $line
        set found 1
      } elseif {$found == 1} {
        # will be in order, no point parsing rest of file.
         break
      }
    }
    return $retval
}
proc getVersionModDirName {schemaVersion {workingdir ""}} {
    if {$workingdir == "" } {set workingdir [getInfo WORKING_DIRECTORY]}
    set driverFile [glob -nocomplain [filejoinx $workingdir AutoConversion.txt]]
    set driverFile [lindex $driverFile 0]
    set modDir [p_getCurrModDir $driverFile $schemaVersion ""]
    if {$modDir == -1} {
        set modDir ""
    }
    return $modDir
}
proc getVersionModel {modelsDir schemaVersion {workingdir ""}} {
    set modDir [getVersionModDirName $schemaVersion $workingdir]
    if {![file exists [file join $modelsDir $modDir]]} {
        set modDir ""
    }
    return $modDir
}
proc getExcludedTables {} {
    return [list SCH_CHANGE_HISTORY SCD_SCH_DETAILS SCL_CONVERSION_LOG]
}
proc validateTor {arrayName} {
    set torUpdate 0
    upvar $arrayName temp
    if {$temp(source) == "DATABASE"} {
        if {$temp(modDirName) == "" } {
            set temp(modDirName) [getVersionModDirName [getSchemaVersionsPLSQL $temp(connectionString) [getInfo WORKING_DIRECTORY] ]]
        }
        if {$temp(modDirName) == ""} {
            return -1
        }
        if {$temp(modDirName) != ""} {
            if {$temp(ModDir) == ""} {
                set temp(ModDir) "[filejoinx [getInfo MODEL_FILES_DIRECTORY] $temp(modDirName)]"
            }
            set torUpdate [updateTor $temp(scriptLogonString) $temp(ModDir)]
        } else {
            set torUpdate [updateTorSchemaTables $temp(scriptLogonString)]
        }
    }
    return $torUpdate
}


proc checkUserModelTablesToTor {dbh modelDir} {
    set modelTables [lindex [getLines [file join $modelDir USER_TABLES]] 0]
    set SQL_Statement "Select TOR_TABLE_NAME
    into :torNames
    from TOR_TABLE_ORDER
    order by TOR_TABLE_NAME"
    execsql use $dbh $SQL_Statement
    set extraTables ""
    set missingTables ""
  foreach sch_table $torNames  mod_table  $modelTables {
    set sch_table [string trim $sch_table]
    set mod_table [string trim $mod_table]
    set i 0
    set j 0
    if {$sch_table != $mod_table} {
      if {[set i [lsearch $modelTables $sch_table]] < 0} {
        lappend extraTables $sch_table
      }
      if {[set j [lsearch $torNames $mod_table]] < 0} {
        lappend missingTables $mod_table
      }
    }
  }
  return  [list $extraTables $missingTables]
}
proc missingFromListB {listA listB} {
    set diff ""
    foreach tab $listA {
        if {[lsearch $listB $tab] < 0} {
            lappend diff $tab
        }
    }
    return $diff
}


proc updateTor {scriptLogonString modDir} {
    set tableList [getTorTables $modDir]
    if {$tableList != ""} {
        set scriptName [getTorinsertScript $tableList TOR_UPDATE]
        catch {run_SQL_Script $scriptLogonString $scriptName.sql "tor.bat" "[getInfo WORKING_DIRECTORY]" } err
        if {$err != 0} {
            putt "Failed to update TOR table: $err"
            return -1
        }
    }
    catch {file delete -force $scriptName.sql}
    catch {file delete -force $scriptName.lst}
    catch {file delete -force "tor.bat"}
    return 0
}
# note: this requires the scriptLogonString
proc updateTorSchemaTables {scriptLogonString} {
    set scriptName TOR_UPDATE
    set ok [getSchemaTablesForTor $scriptName]
    catch {run_SQL_Script $scriptLogonString $scriptName.sql "tor.bat" "[getInfo WORKING_DIRECTORY]" } err
    if {$err != 0} {
        putt "Failed to update TOR table"
        return -1
    }
    catch {file delete -force $scriptName.sql}
    catch {file delete -force $scriptName.lst}
    catch {file delete -force "tor.bat"}
    return 0
}
proc getSchemaTablesForTor {{scriptName TOR_INSERTS}} {
    set fid [open $scriptName.sql w]
    puts $fid "set echo on"
    puts $fid "spool [getInfo WORKING_DIRECTORY]/$scriptName.lst"
    puts $fid "DELETE from TOR_TABLE_ORDER;\nCOMMIT;\n\n"
    puts $fid "CREATE SEQUENCE TOR_SEQUENCE start with 1;
insert into TOR_TABLE_ORDER (
   tor_id,
   tor_table_name,
   tor_create_date,
   tor_usr_uid_created_by,
   tor_record_version
)
select TOR_SEQUENCE.NEXTVAL,
table_name,
sysdate,
-4,
0
from (
    select table_name,sysdate, -4, 0 from (select table_name, count(table_name) from (select table_name from user_tab_columns where column_name in (
    substr(table_name,1,4)||'USR_UID_UPDATED_BY',
    substr(table_name,1,4)||'USR_UID_CREATED_BY',
    substr(table_name,1,4)||'LAST_UPDATE_DATE',
    substr(table_name,1,4)||'CREATE_DATE',
    substr(table_name,1,4)||'RECORD_VERSION')) having count(table_name) = 5 group by table_name)
    where table_name not in ('[join [getExcludedTables] "','"]')
    order by table_name
);
commit;
SELECT TOR_TABLE_NAME from TOR_TABLE_ORDER order by TOR_ID;
DROP SEQUENCE TOR_SEQUENCE;
-- shs update here?
spool off
exit
"
    close $fid
    return 0
}
proc getTorTables {path} {
    set userTables ""
    if {[file exists $path/TOR_TABLE_ORDER]} {
        set fid [open $path/TOR_TABLE_ORDER r]
        set conts [split [string trim [read $fid] ]]
        close $fid
        foreach tab $conts {
            if {[lsearch [getExcludedTables] $tab] < 0} {
                lappend userTables $tab
            }
        }
    }
    return $userTables
}

proc getTorinsertScript {tableList {scriptName "TOR_INSERTS"}} {
    set fid [open $scriptName.sql w]
    puts $fid "set echo on"
    puts $fid "spool \"[getInfo WORKING_DIRECTORY]/$scriptName.lst\""
    puts $fid "DELETE from TOR_TABLE_ORDER;\nCOMMIT;\n\n"
    puts $fid [join [getTORinserts $tableList] \n]
    puts $fid "COMMIT;\n\n"
    puts $fid "spool off"
    puts $fid "EXIT"
    close $fid
    return $scriptName
}
proc getTORinserts {tableList} {
    set i 1
    set sql ""
    foreach tab $tableList {
        lappend sql "INSERT INTO TOR_TABLE_ORDER (TOR_ID,TOR_TABLE_NAME,TOR_RECORD_VERSION,TOR_CREATE_DATE,TOR_USR_UID_CREATED_BY) values ($i, '$tab', 0, sysdate, -4);"
        incr i
    }
    return $sql
}

proc getTorUpdates {dbh modelDir} {
    set sql "select count(*)
        into :recordVersion
    from user_tab_columns where column_name =
        'TOR_RECORD_VERSION' and table_name = 'TOR_TABLE_ORDER'"
    execsql use $dbh $sql
    set torSQL "Delete from TOR_TABLE_ORDER;\nCommit;\n"
    set torTables [lindex [getLines [file join $modelDir TOR_TABLE_ORDER]] 0]
    set id 1
    foreach t $torTables {
        if {[lsearch [getExcludedTables] $t] >= 0} {
            continue
        }
        append torSQL "insert into TOR_TABLE_ORDER
        (TOR_ID, TOR_TABLE_NAME, TOR_CREATE_DATE, TOR_USR_UID_CREATED_BY"
        if {$recordVersion} {
            append torSQL ", TOR_RECORD_VERSION"
        }
        append torSQL ") \nvalues
        ($id,'$t',sysdate,-4"
        if {$recordVersion} {
            append torSQL ", 0"
        }
        append torSQL ");\n"
        incr id
    }
    append torSQL "COMMIT;\n"
}
# -----------------------#
# SECTION:            INDEX
# -----------------------#
# Model File Index list
# ############################ getModelIndexes

# retrieves index descriptions from a given user_indexes model file.
# @author LAQ
# @param indexModFile file containing the index name table name and colum names
# @return list of names*columns*tables - columns can be a list of lists
proc getModelIndexes {indexModFile} {
    # Read the current version user_ind_columns model file
    set mdb [open "[file join [getInfo MODEL_FILES_DIRECTORY] $indexModFile]" r]
    gets $mdb index_names_lst
    if {[regexp -nocase "^#header" $index_names_lst]} {
        return [getNewModelIndexes $indexModFile]
    }
    gets $mdb index_tables_lst
    gets $mdb index_columns_lst
    close $mdb
    if {[llength $index_names_lst] == 0} {return ""}
    set temp_ind_name_current [lindex $index_names_lst 0]
    set names [lindex $index_names_lst 0]
    set tables [lindex $index_tables_lst 0]
    set columns ""
    set current_ind_col_lst ""
    foreach index_name $index_names_lst index_table $index_tables_lst index_column $index_columns_lst {
        if {$index_name != $temp_ind_name_current} {
            lappend columns $current_ind_col_lst
            lappend names $index_name
            lappend tables $index_table
            set current_ind_col_lst $index_column
            set temp_ind_name_current $index_name
        } else {
            lappend current_ind_col_lst $index_column
        }
    }
    lappend columns $current_ind_col_lst
    return [list $names $columns $tables]
}

# ############################ getNewModelIndexes

# retrieves index descriptions from a given user_indexes in case the models files are of the versions 3.0+.
# @param indexModFile file containing the index name table name and colum names
# @return list of names*columns*tables - columns can be a list of lists
proc getNewModelIndexes {indexModFile} {
    # Read the current version user_ind_columns model file
    set mdb [open "[file join [getInfo MODEL_FILES_DIRECTORY] $indexModFile]" r]
    set file_data [read $mdb]
    close $mdb
    #removing header line
    regsub "^.*?\n->" $file_data "" file_data
    set allIndexData [split $file_data "->"]
    set temp_ind_name_current ""
    foreach indexData $allIndexData {
        set counter 0
        set lineData [split $indexData "\n"]
        foreach line $lineData {
            if {$counter==0} {
                lappend tables $line
                incr counter
                continue
            }
            regexp {^(.*?)#(.*?)!} $line temp index_name column_name
            if {$index_name!="" && $index_name==$temp_ind_name_current} {
                lappend columns $column_name
            } else {
                lappend names $index_name
                lappend columns $column_name
                set temp_ind_name_current $index_name
            }
        }
    }
    return [list $names $columns $tables]
}
# ############################ getIndexDelta

# retrieves the delta between the client schema model's version index definition and the target model
# includes indexes that may be added and dropped in between conversion end points.
# @author LAQ
# @param known_ind_col_lst starting point of known index/column
# @param ModDirList list of mod file directories from and up to target model
# @return list of names columns and tables that are added during the conversion
proc getIndexDelta {known_ind_col_lst ModDirList} {
    set diffnames ""
    set diffcols ""
    set difftabs ""
    # create a list of multi column indexes from the current model files

    foreach ModDir $ModDirList {
        set consolidated [getModelIndexes $ModDir/USER_IND_COLUMNS]
        set fm_index_lst [lindex $consolidated 0]
        set fm_ind_col_lst [lindex $consolidated 1]
        set fm_ind_table_lst [lindex $consolidated 2]
        for {set i 0}  {$i < [llength $fm_ind_col_lst]} {incr i} {
            if {[lsearch $known_ind_col_lst [lindex $fm_ind_col_lst $i]] < 0} {
                lappend known_ind_col_lst [lindex $fm_ind_col_lst $i]
                lappend diffnames [lindex $fm_index_lst $i]
                lappend diffcols [lindex $fm_ind_col_lst $i]
                lappend difftabs [lindex $fm_ind_table_lst $i]
            }
        }
    }
    return [list $diffnames $diffcols $difftabs]
}
# Incorrect index name check.
# inputs: currentModDir -current version mod file
# - targetModDir - target version mod file
# - dbh - database connection handle
# - log - logging file handle
# returns  - list of indexs-columns
proc p_indCheck {currentModDir targetModDir dbh log {driverFile ""}} {
    # Get non-EXL Healthcare named Indexes and regular Indexes from Target schema
    puts "\nRetrieving list of schema indexes..."
    set SQL_Statement "select index_name, column_name, table_name, column_position
        into :c_ind_lst, :c_ind_col_lst, :c_ind_table_lst, :c_ind_col_pos_lst
        from user_ind_columns where
        table_name in (select tor_table_name from tor_table_order) order by table_name, index_name, column_position"
    if {[catch {execsql $SQL_Statement} err] || $err < 0} {
        error "There was an error trying to generate a list of indexes:\n$err"
    }
    puts "\nExtracting client-created index definitions..."

    set temp_ind_name_current [lindex $c_ind_lst 0]
    set client_index_lst ""
    set client_ind_table_lst ""
    set client_ind_col_lst ""
    set current_ind_col_lst ""
    set current_table [lindex $c_ind_table_lst 0]
    set index_name ""
    set consolidated [getModelIndexes $currentModDir/USER_IND_COLUMNS]
    set fm_index_lst [lindex $consolidated 0]
    set fm_ind_col_lst [lindex $consolidated 1]
    set fm_ind_table_lst [lindex $consolidated 2]

    foreach fIndex $fm_index_lst {
        set fm_index_lst_array($fIndex) 1
    }

    foreach index_name $c_ind_lst index_table $c_ind_table_lst index_column $c_ind_col_lst {
        if {$index_name != $temp_ind_name_current} {
            if {[info exists fm_index_lst_array($temp_ind_name_current)] == 0} {
                lappend client_ind_col_lst $current_ind_col_lst
                lappend client_index_lst $temp_ind_name_current
                lappend client_ind_table_lst $current_table
            }
            set current_ind_col_lst $index_column
            set temp_ind_name_current $index_name
            set current_table $index_table

        } else {
            lappend current_ind_col_lst $index_column
        }
    }
    # get the remaining column def if exists
    if {[lsearch $fm_index_lst $index_name] < 0} {
        lappend client_ind_col_lst $current_ind_col_lst
    }
    # If Client Indexes Found, Then Get the Target Version's Index Information
    set conflict_ind_lst ""
    set conflict_ind_col_lst ""
    if {[llength $client_ind_col_lst] > 0} {
        set driverFile [findDriverFile $currentModDir]
        set modDirList [getModDirsFrom $driverFile $currentModDir $targetModDir]
        set consolidated [getIndexDelta $fm_ind_col_lst $modDirList]

        set ft_index_lst [lindex $consolidated 0]
        set ft_ind_col_lst [lindex $consolidated 1]
        set ft_ind_table_lst [lindex $consolidated 2]

    # Check to see if Client Index column has an index on Target version.  If so create list of conflicts.
    puts "\nChecking client created indexes against target version information..."
        foreach client_index $client_index_lst client_ind_col $client_ind_col_lst client_table $client_ind_table_lst {
            set i [lsearch $ft_ind_col_lst "$client_ind_col"]
            if {$i >= 0 && $client_table == [lindex $ft_ind_table_lst $i]} {
                    lappend conflict_ind_lst $client_index
                    lappend conflict_ind_col_lst $client_ind_col
                    lappend target_conflict_indexes [lindex $ft_ind_col_lst $i]
                    lappend target_conflict_tables [lindex $ft_ind_table_lst $i]
            }
        }
    }
    # if there are conflicts, output to the screen and log file.
    if { [llength $conflict_ind_lst] > 0 } {
        # Generate the text to be displayed
        append output_index_text "\n============================================================================"
        append output_index_text "\nWARNING: During the conversion, indexes will be added to columns which have"
        append output_index_text "\nalready been indexed outside of the standard schema upgrade process. To prevent"
        append output_index_text "\nconversion failure, drop these indexes prior to the conversion.  A list of"
        append output_index_text "\nDROP statements has been created in the log file."
        foreach conf_ind $conflict_ind_lst conf_col $conflict_ind_col_lst conf_table $target_conflict_tables {
            append output_index_text  "\n\tIndex $conf_ind on $conf_table\($conf_col)\n"
            append fixes "DROP INDEX $conf_ind;\n"
        }
        append output_index_text "\n============================================================================"
        # Output the text to file and to screen
        puts $log $output_index_text
        puts $output_index_text
        puts $log $fixes
        return [list $conflict_ind_lst $conflict_ind_col_lst]
    } else {
        append output_index_text "\n============================================================================"
        append output_index_text "\nNo conflicts found."
        append output_index_text "\n============================================================================"
        # Output the text to screen
        #puts $log $output_index_text
        puts $output_index_text
        return 0
    }
    }
# -----------------------#
# SECTION:            SYSDATA
# -----------------------#

########################################################################
#Code Check: check for conflicts between current and target system codes
########################################################################
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getCodesInDB { arrayName table_name code_col_name} {
    upvar $arrayName tableCodes
    set count 0
    set col_count 0

    set columns [split $code_col_name "!"]
    set whereClause ""
    foreach column $columns {
        lappend whereClause "column_name='$column'"
    }
    set whereClause [join $whereClause " or "]
    set sql_statement "select count(*) into :col_count from user_tab_columns where table_name = '$table_name' and $whereClause"
    if {[catch {execsql $sql_statement} err] || $err < 0} {
        error "There was an error trying to get a column count from DB:\n$err"
    }
    if {$col_count < [llength $columns]} {
        # if column/columns don't exist, then cant cause conflict
        return 0
    }
    set columns "[join $columns "||'!'||"]"
    set start 0
    set end 999
    set allCodes ""
    # mostly this will loop one time, but oracle has a limit of 1000 items
    while {$start < [llength $tableCodes($table_name.$code_col_name)]} {
        set columnValues [join [lrange $tableCodes($table_name.$code_col_name) $start $end] "','"]
        set SQL_Statement "select $columns into :code from $table_name where $columns in ('$columnValues')"
        if {[catch {execsql $SQL_Statement} err] || $err < 0} {
            puts $SQL_Statement
            puts [getinfo all]
            error "There was an error trying to get a code from DB:\n$err"
        }
        set allCodes [concat $allCodes $code]
        incr start 1000
        incr end 1000
    }
    if {$allCodes != ""} {
        return $allCodes
    } else {
        return 0
    }
}
# ##########
# @proc getCodesInModel
# @ parses out the code values from the model description values
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getCodesInModel { table_name col_name values} {
    set break no
    set code_lst ""
    set system_data ""
    foreach system_data $values {
        set i_pound_sign [string first "###" $system_data]
            set concat_keys [string range $system_data 0 [expr $i_pound_sign -1]]
            lappend code_lst "$table_name $col_name $concat_keys"
    }
    return $code_lst
}

# ##########
# @proc getCodeVals
# @ returns list of {table cols vals} for a given system data model
# ##########
# @author LAQ
# @param source_names_file model names file
# @param source_values_file model values file
# @param client_tables list of client tables
# @exception
# @see getCodesInModel
# @return list of {table cols vals}
# ##########
proc getCodeVals {source_names_file source_values_file client_tables} {
    upvar $client_tables ct
    set c_codes ""
    set source_names [open $source_names_file r]
    set source_values [open $source_values_file r]
    # first line of names and values is header, throw it away.
    set namesList [lrange [split [string trim [read $source_names]] \n] 1 end]
    set valuesList [lrange [split [string map {-> \0} "[string trim [read $source_values]]\n"] \0] 1 end]
    close $source_names
    close $source_values
    array set VL ""
    foreach vl $valuesList {
        set vl [split $vl \n]
        set VL([lindex $vl 0]) [lrange $vl 1 end-1]
    }
    # todo: there may be a better way than this to hold the data
    foreach line $namesList {
        set table_name [lindex $line 0]
        if {!($table_name == "")} {
            if {[info exists ct($table_name)]} {
                set col_name [lindex $line 1]
                set ct($table_name) $col_name
                set c_codes [concat $c_codes [getCodesInModel $table_name $col_name $VL($table_name)]]
            }
        }
    }
    return $c_codes
}
# ##########
# @proc getClientTables
# @ Finds all table that have where clauses, which indicate clients may use tables.
# ##########
# @author LAQ
# @param source_where_file the "WHERE.txt" file for a model
# @exception none
# @see
# @return list of client tables
# ##########
proc getClientTables {source_where_file} {
        set source_wheres [open "$source_where_file" r]
        set check_tables [lrange [split [read $source_wheres] \n] 1 end]
        close $source_wheres
        set client_tables ""
        foreach {table columns} $check_tables {
            if {[string trim $table] != ""} {
                    lappend client_tables $table
                    # create a placeholder to allow it to be an array structure. This allows skipping of searching through tables later to ensure uniqueness.
                    lappend client_tables 1
            }
        }
    return $client_tables
    return [lsort $client_tables]
}
# ##########
# @proc getCodeDelta
# @compares the delta of client system data codes from start to target versions (incrementally for each interval mod file)
# ##########
# @author LAQ
# @param startMod the starting model directory
# @param ModDirList the list of mod directories up to and including target model directory
# @param log optional for when printing a log/report
# @exception non caught or thrown
# @see getCodeVals getClientTables
# @return list of codes, as {table, cols, values}
# ##########
proc getCodeDelta {startMod ModDirList {log ""}} {
    # to improve efficiency, remove all tables that do not, not ever do, contain client data ( no where clause)
    # start with current model, then remove any that are not in later where clauses.
    # note: this is not perfect, but does ensure that any that might have client data are checked.
    if {![file exists [file join [getInfo MODEL_FILES_DIRECTORY] $startMod]]} {
        putt "ERROR: model directory [file join [getInfo MODEL_FILES_DIRECTORY] $startMod]
        does not exist!"
        error "Missing model directory $startMod"
    }
    if [catch {glob "[file join [getInfo MODEL_FILES_DIRECTORY] $startMod *WHERE*.txt]"} source_where_file] {
        putt "ERROR: Could not find a WHERE file in $startMod"
        error "$startMod is missing a WHERE file."
    }
    set source_where_file [join $source_where_file]
        # array names may be overwritten, but existing names will never be lost.
    array set client_tables [getClientTables "$source_where_file"]
    foreach modDir $ModDirList {
        if {![file exists [file join [getInfo MODEL_FILES_DIRECTORY] $modDir]]} {
            putt "ERROR: model directory [file join [getInfo MODEL_FILES_DIRECTORY] $modDir]
            does not exist!"
            error "Missing model directory $modDir"
        }
        if [catch {glob "[file join [getInfo MODEL_FILES_DIRECTORY] $modDir *WHERE*.txt]"} source_where_file] {
            putt "ERROR: Could not find a WHERE file in $modDir"
            error "$modDir is missing a WHERE file."
        }
        set source_where_file [join $source_where_file]
        array set client_tables [getClientTables "$source_where_file"]
    }
    # get start version list of codes - will need to confirm that
    # the delta is not due to same codes being added to tip of branch as trunk
    # in which case it would not be in intervening models
    if [catch {glob "[file join [getInfo MODEL_FILES_DIRECTORY] $startMod *NAMES*.txt]"} source_names_file] {
        putt "ERROR: Could not find a NAMES file in $startMod"
        error "$startMod is missing a NAMES file."
    }
    set source_names_file [join $source_names_file]
    if [catch {glob "[file join [getInfo MODEL_FILES_DIRECTORY] $startMod *VALUES*.txt]"} source_values_file] {
        putt "ERROR: Could not find a VALUES file in $startMod"
        error "$startMod is missing a VALUES file."
    }
    set source_values_file [join $source_values_file]
    set allCodes [getCodeVals $source_names_file $source_values_file client_tables]
        # todo: is there a way to do this more easily from getCodeVals?
    foreach tCode $allCodes {
        set allCodesArray($tCode) 1
    }
    array set tableCodes ""
    set diffList 0
    # now get the added codes from start to target versions
    foreach modDir $ModDirList {
        puts "-- Comparing $startMod to $modDir Codes --"
        if [catch {glob "[file join [getInfo MODEL_FILES_DIRECTORY] $modDir *NAMES*.txt]"} source_names_file] {
            putt "ERROR: Could not find a NAMES file in $modDir"
            error "$modDir is missing a NAMES file."
        }
        set source_names_file [join $source_names_file]
        if [catch {glob "[file join [getInfo MODEL_FILES_DIRECTORY] $modDir *VALUES*.txt]"} source_values_file] {
            putt "ERROR: Could not find a VALUES file in $modDir"
            error "$modDir is missing a VALUES file."
        }
        set source_values_file [join $source_values_file]
        set codeB [getCodeVals $source_names_file $source_values_file client_tables]
        set startMod $modDir
        foreach line $codeB {
            # if the code is not already in the list, it needs to be added to the list of items to check for collisions.
            if {[info exists allCodesArray($line)] == 0} {
                if {![info exists tableCodes([lindex $line 0].[lindex $line 1])]} {
                    # need to initialize the list to null
                    set tableCodes([lindex $line 0].[lindex $line 1]) ""
                }
                # add the code to collision list- note that if column definition for a table changes, there will be more that one array name for that table.  It will also ensure that each select is done correctly when checking against the database.
                lappend tableCodes([lindex $line 0].[lindex $line 1]) [lrange $line  2 end]
                set allCodesArray($line) 1
                incr diffList
            }
        }
    }
    if {$log == ""} {
        putt "-- There are $diffList codes added to check --"
    } else {
        puts "-- There are $diffList codes added to check --"
    }
    return [array get tableCodes]
}
# ########## getModDirsFrom

# Retrieves the mod directories from start to target versions
# @author LAQ
# @param driverFile - usually autoconversion.txt
# @param sourceModDir start version
# @param targetModDir target version
# @exception
# @see getDriverInfo
# @return List of mod file directories
# ##########
proc getModDirsFrom {driverFile sourceModDir targetModDir} {
   # determine the models that need to be checked, base on sourceModDir, targetModDir and driverFile
    set modInfo [lindex [getDriverInfo $driverFile] end]
    # setting go to zero, note that first item (sourceModDir) will be skipped
    # note that one can specify a targetModDir, or if targetModDir = "" all to the end will be grabbed.
    set go 0
    set targetModDirs ""
    foreach mod $modInfo {
        if {$go && $sourceModDir != $mod} {
            if {[lsearch $targetModDirs $mod] < 0} {
                lappend targetModDirs $mod
            }
        }
        if {$sourceModDir == $mod} {
            set go 1
        }
        if {$targetModDir == $mod} {
            set go 0
        }
    }
    return $targetModDirs
}
# ########## findDriverFile

# Retrieves the conversion driver file, if not known.
# @author LAQ
# @param sourceModDir - start version model directory
# @exception - cannot determine driver file, or cannot find.
# @return driver file
# ##########
proc findDriverFile {sourceModDir} {
        if {[lsearch {Mod900 Mod901 Mod902 Mod903 Mod904} $sourceModDir] >= 0 } {
            if {[catch {glob "AutoConversionMCtoCR.txt"} driverFile]} {
                if {[catch {glob "MC*CR*AutoConversion.txt"} driverFile]} {
                    error "Driver File Not Found"
                }
            }
        } else {
           if {[catch {glob "AutoConversion.txt"} driverFile]} {
                if {[catch {glob "CR*CR*AutoConversion.txt"} driverFile]} {
                    error "Driver File Not Found"
                }
            }
        }
    return $driverFile
}
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc compareCodes { sourceModDir targetModDir {driverFile ""} {log ""}} {
    # for backwards compatiblity, accepts two params, and we guess at the driver file name...
    if {$log == ""} { putt "Checking for conflicting codes. Start: [date_now] [time_now]" }
    set start [clock seconds]
    if {$driverFile == ""} {
        if {[lsearch {Mod900 Mod901 Mod902 Mod903 Mod904} $sourceModDir] >= 0 } {
            if {[catch {glob "AutoConversionMCtoCR.txt"} driverFile]} {
                if {[catch {glob "MC*CR*AutoConversion.txt"} driverFile]} {
                    error "Driver File Not Found"
                }
            }
        } else {
           if {[catch {glob "AutoConversion.txt"} driverFile]} {
                if {[catch {glob "CR*CR*AutoConversion.txt"} driverFile]} {
                    error "Driver File Not Found"
                }
            }
        }
    }
    set targetModDirs [getModDirsFrom $driverFile $sourceModDir $targetModDir]
        # now get the delta in system data codes to check.
    # note that an empty targetModDirs will return no diffs - which is correct for checking if sourceModDir = targetModDir
    array set extra_schema_codes [getCodeDelta $sourceModDir $targetModDirs $log]

    ########
    #compare
    ########

    # Above delta set vs. s_codes
    set conflict_codes ""
    # Special set of codes that went from being considered non-system to system data, where a DB update did not occur,
    # So conflicts should not occur

    array set exclude_codes "ALT_ALLERGY_TYPE.ALT_CODE DRUG
SPF_SECURITY_PROFILE.SPF_UID {1 2 3 4}
STF_STAFF.STF_UID -5
STY_SURVEY_TYPE.STY_CODE MEM
STY_SURVEY_TYPE.STY_CODE OTHER
STY_SURVEY_TYPE.STY_CODE PVD
TTY_TASK_TYPE.TTY_CODE {APPCMS APPNON APPSTD CMS CONTAC CSMGMT MSG OBI REF REF_IP SURVEY SVYMEM SVYOTH SVYPVD TAU TAUAPP TAUREF TAUREV TAU_IP}"
    set prevColTab ""
    foreach name [lsort [array names extra_schema_codes]] {
        set tableName [lindex [split $name "."] 0]
        set columns [lindex [split $name "."] 1]
        if {$tableName == "TOR_TABLE_ORDER" || $tableName == "ORT_ORGANIZATION_TYPE" || $tableName == "SPV_SECURITY_PRIVILEGE" || $tableName ==  "ATE_APPEAL_TYPE"} {continue}
        set codes ""
        if {[info exists exclude_codes($name)]} {
            foreach v $exclude_codes($name) {
                if {[set i [lsearch $extra_schema_codes($name) $v]] >= 0} {
                    # remove the excluded code from the list
                    set extra_schema_codes($name) [lreplace $extra_schema_codes($name) $i $i]
                }
            }
            if {$extra_schema_codes($name) == ""} {continue}
        }
            # returns a list of codes for this table that will collide
        set concodeIndex [getCodesInDB extra_schema_codes $tableName $columns]
        if {$concodeIndex != 0 } {
            if {$concodeIndex != -1} {
                foreach conflict $concodeIndex {
                    # add table and column to make it relevant
                    lappend conflict_codes "$tableName $columns $conflict"
                }
            }
        }
    }
    if {$log == ""} { putt "Code Conflict check complete" }
    set end [clock seconds]
    if {$log == ""} { putt "Run time was [getDurationDots $end $start]" }
    return $conflict_codes
}
proc deleteNonSysSpool {directory} {
    set Del_Report_lst [glob -directory $directory -nocomplain *_Deletes_*.*]
    foreach Del_Report $Del_Report_lst {
        file delete -force $Del_Report
    }
}

# ##########
# @proc DataCertify
# @runs sysdatagen, then output files, twice as needed.
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc DataCertify { statFile} {
    set scripts ""
    set stat [open $statFile r]
    gets $stat stat_record ;
    set stat_record ""
    gets $stat stat_record
    if { ! [eof $stat] } {
          if { $stat_record != "" && $stat_record != "none" } {
            lappend scripts $stat_record
        }
         gets $stat stat_record
         if { ! [eof $stat] } {
            if { $stat_record != "" && $stat_record != "none" } {
                 lappend scripts $stat_record
              }
        }
        close $stat
        return $scripts
    }
}

# ##########
# @proc GrantCheck
# @checks for necessary permissions.
# ##########
# @author
# @param
# @exception
# @see
# @return 0 Success, 1 optional grants missing, -1 Required grants missing
# ##########
proc GrantCheck {log {dbh ""}} {
    global INFO SQL_Statement
    if {$dbh == ""} {set dbh [getInfo DATABASE_HANDLE]}
    set schema ""
    set value 0
    set objCount 0
    if {[set schema [getInfo SCHEMA_NAME]] == ""} {
        set sql "select username into :schema from user_users"
        execsql use $dbh $sql
        setInfo SCHEMA_NAME $schema
    }
    if {$schema == ""} {set schema "<schema_name>"}
# These first are only required by tablespace analysis
    set SQL_Statement "SELECT file_id from DBA_DATA_FILES where rownum < 2"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value 1
        putt $log "\tGRANT SELECT on DBA_DATA_FILES to $schema;"
    }

    set SQL_Statement "SELECT owner from DBA_ROLLBACK_SEGS where rownum < 2"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value 1
        putt $log "\tGRANT SELECT on DBA_ROLLBACK_SEGS to $schema;"
    }

    set SQL_Statement "SELECT owner from DBA_TABLES where rownum < 2"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value 1
        putt $log "\tGRANT SELECT on DBA_TABLES to $schema;"
    }

    set SQL_Statement "SELECT VALUE FROM v\$parameter WHERE NAME = 'optimizer_mode'"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value 1
        putt $log "\tGRANT SELECT on V_\$PARAMETER to $schema;"
    }

    set SQL_Statement "SELECT VERSION FROM v\$instance where rownum < 2"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value 1
        putt $log "\tGRANT SELECT on V_\$INSTANCE to $schema;"
    }

    set SQL_Statement "SELECT SID FROM v\$session where rownum < 2"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value 1
        putt $log "\tGRANT SELECT on V_\$SESSION to $schema;"
    }

    set SQL_Statement "SELECT distinct owner from DBA_SEGMENTS where rownum < 2"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value 1
        putt $log "\tGRANT SELECT on DBA_SEGMENTS to $schema;"
    }
    if {$value == 0} {
        puts "The target database has sufficient select privileges."
    } else {
        putt "The conversion requires privileges missing on the target database."
        putt "Contact the EXL Healthcare Support Department for assistance: "
        putt [getInfo SupportContact]
    }
    return $value;
}
proc SQL_GrantError{message targetSchemaName} {
     puts ""
     puts "*** ERROR"
     puts ""
     set message "The conversion requires select privileges on the target database to several views.
    As the SYS user, grant the privileges to the target database as follows. \n
    GRANT SELECT on DBA_DATA_FILES to $targetSchemaName;
    GRANT SELECT on DBA_ROLLBACK_SEGS to $targetSchemaName;
    GRANT SELECT on DBA_TABLES to $targetSchemaName;
    GRANT SELECT on V_\$INSTANCE to $targetSchemaName;
    GRANT SELECT on V_\$PARAMETER to $targetSchemaName;
    GRANT SELECT on DBA_SEGMENTS to $targetSchemaName;
    GRANT SELECT on V_\$SESSION to $targetSchemaName;\n
    Contact the EXL Healthcare Support Department for assistance:
    [getInfo SupportContact]"
}

# ##########
# @proc FunctionalGrantCheck
# @checks for necessary permissions.
# ##########
# @author
# @param
# @exception
# @see
# @return 0 Success, 1 optional grants missing, -1 Required grants missing
# ##########
proc FunctionalGrantCheck {log {dbh ""}} {
    global INFO SQL_Statement
    if {$dbh == ""} {set dbh [getInfo DATABASE_HANDLE]}
    set value 0
    set objCount 0
    if {[set schema [getInfo SCHEMA_NAME]] == ""} {
        set sql "select username into :schema from user_users"
        execsql use $dbh $sql
        setInfo SCHEMA_NAME $schema
    }
    if {$schema == ""} {set schema "<schema_name>"}
#  The following are REQUIRED for conversions
    set SQL_Statement "SELECT count(*) into :objCount FROM user_sys_privs where privilege = 'CREATE PROCEDURE'
    union
    SELECT count(*)  FROM role_sys_privs where privilege = 'CREATE PROCEDURE'"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value -1
        putt $log "\tGRANT CREATE PROCEDURE to $schema;"
    } elseif {$objCount == 0} {
        set value -1
        putt $log "\tGRANT CREATE PROCEDURE to $schema;"
    }

    set SQL_Statement "SELECT count(*) into :objCount from user_sys_privs where privilege = 'CREATE TRIGGER'
    union
    SELECT count(*)  FROM role_sys_privs where privilege = 'CREATE TRIGGER'"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value -1
        putt $log "\tGRANT CREATE TRIGGER to $schema;"
    } elseif {$objCount == 0} {
        set value -1
        putt $log "\tGRANT CREATE TRIGGER to $schema;"
    }

    set SQL_Statement "SELECT count(*) into :objCount from user_sys_privs where privilege = 'CREATE TYPE'
    union
    SELECT count(*)  FROM role_sys_privs where privilege = 'CREATE TYPE'"
    if {[execsql use $dbh $SQL_Statement] == -1} {
        set value -1
        putt $log "\tGRANT CREATE TYPE to $schema;"
    } elseif {$objCount == 0} {
        set value -1
        putt $log "\tGRANT CREATE TYPE to $schema;"
    }


    set SQL_Statement "SELECT count(*)
      into :objCount
    from user_tab_privs where table_name = 'CTX_DDL' and PRIVILEGE = 'EXECUTE'"
    if {[catch {execsql use $dbh $SQL_Statement} err] == -1 || $objCount == 0} {
        set value -1
        putt $log "\tGRANT EXECUTE on CTX_DDL to $schema;"
    }
    puts ""
    if {$value == 0} {

    } else {
        putt "The conversion requires privileges missing on the target database."
        putt "Contact the EXL Healthcare Support Department for assistance: "
        putt [getInfo SupportContact]
    }
    return $value;
}
proc SQL_FunctionalGrantError {message targetSchemaName} {
     puts ""
     puts "*** ERROR"
     puts ""
     set message "The conversion requires privileges on the target database to
     perform conversion tasks.
    As the SYS user, grant the privileges to the target database as follows. \n
    GRANT CREATE PROCEDURE to $targetSchemaName;
    GRANT CREATE TRIGGER to $targetSchemaName;
    GRANT CREATE TYPE to $targetSchemaName;
    GRANT EXECUTE on CTX_DDL to $targetSchemaName;\n
    Contact the EXL Healthcare Support Department for assistance:
    [getInfo SupportContact]"
}

# ##########
# @proc stopJournaling
# @ensures that journaling is turned off, if it exists.
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc stopJournaling {DBH} {
    set rval 0
    set journaled -1
    set SQL_Statement "select count(table_name) into :journaled from user_tables where table_name ='TJN_TABLE_JOURNAL'"
    execsql use $DBH $SQL_Statement
    if {$journaled > 0} {
        set journaled ""
            putt "Ensuring Auditing is turned off."
        set SQL_Statement "select TJN_TABLE_NAME
            into :journaled
            from TJN_TABLE_JOURNAL where TJN_JOURNAL_YN = 'Y'
            order by TJN_TABLE_NAME"
        catch {execsql use $DBH $SQL_Statement} err
            # only Y means on.. X will allow us to remember which were on.
        set SQL_Statement "update TJN_TABLE_JOURNAL
        set TJN_JOURNAL_YN = 'X'
        where TJN_JOURNAL_YN = 'Y'"
        catch {execsql use $DBH $SQL_Statement} err
        execsql use $DBH "Commit"
        # disable TJN trigger as well ?
        # now double check in case TJN trigger didn't fire correctly
        set SQL_Statement "select table_name, trigger_name, status
                into :auditTables, :auditTriggers, :auditStatus
            from user_triggers where trigger_name like 'AUDIT%'
            and status != 'DISABLED'"
            #  (trigger_name like 'AUDIT%' or trigger_name = 'TJN_TABLE_JOURNAL')
        execsql use $DBH $SQL_Statement
        # if any triggers are not represented in TJN table, we still will disable it
        set unhandledTriggerTables ""
        foreach tableName $auditTables triggerName $auditTriggers status $auditStatus {
            if {[lsearch $journaled $tableName] < 0} {
                if {[lsearch $unhandledTriggerTables $tableName] < 0} {
                    lappend unhandledTriggerTables $tableName
                }
                putt "$tableName is not set to audit in TJN table, but audit trigger(s) enabled."
            } else {
                putt "Turning off auditing failed for table $tableName trigger $triggerName"
            }
            putt "Forcing disable of trigger $triggerName"
            set SQL_Statement "alter trigger $triggerName disable"
            execsql use $DBH $SQL_Statement
        }
        set rval [expr [llength $journaled] + [llength $unhandledTriggerTables]]
        # final check
        set SQL_Statement "select table_name, trigger_name
            into :auditTables, :auditTriggers
        from user_triggers where trigger_name like 'AUDIT%'
            and status != 'DISABLED'"
            #  (trigger_name like 'AUDIT%' or trigger_name = 'TJN_TABLE_JOURNAL')
        execsql use $DBH $SQL_Statement
        if {$auditTables != ""} {
            putt "ERROR: could not turn off auditing for tables:\n\t[join $auditTables \n\t]"
            set rval -1
        }
    } elseif {$journaled == -1} {
        putt "Could not determine if journaling table exists"
        set rval $journaled
    }
    return $rval
}

# ##########
# @proc getInvalidTriggers
# @gets a list of invalid triggers
# ##########
# @author
# @param
# @exception
# @see
# @return 1 - ERROR, 0 - success
# ##########
proc getInvalidTriggers {DBH triggertype} {
    set triggerLst ""
    set SQL_Statement ""
    if {$triggertype == "nonAuditTrigger" || $triggertype == ""} {
        set SQL_Statement "select trigger_name
            into :triggerLst
        from user_triggers where status = 'ENABLED' and trigger_name IN
            (select object_name from user_objects where object_type = 'TRIGGER' and status = 'INVALID'
                and (object_name not like 'AUDIT%' and object_name not like 'TJN_UPDATE%'))"
    } else {
        set SQL_Statement "select trigger_name
            into :triggerLst
        from user_triggers where status = 'ENABLED' and trigger_name IN
            (select object_name  from user_objects where object_type = 'TRIGGER' and status = 'INVALID'
                and (object_name  like 'AUDIT%' or object_name  like 'TJN_UPDATE%'))"
    }
    catch {execsql use $DBH $SQL_Statement} err
    if {$err < 0} {
        putt "ERROR executing: $SQL_Statement"
        return 1
    }
    if {$triggerLst == ""} {set triggerLst 0}
    return [lsort $triggerLst]
}

# ##########
# @proc disableTriggers
# @disables provided list of triggers
# ##########
# @author
# @param
# @exception
# @see
# @return 1 - ERROR, 0 - success
# ##########
proc disableTriggers {triggerLst DBH} {
    set ret 0
    foreach trigger $triggerLst {
        set SQL_Statement "alter trigger $trigger disable"
        catch {execsql use $DBH $SQL_Statement} err
        if {$err < 0} {
            putt "ERROR executing: $SQL_Statement"
            set ret 1
        }
        putt "Disabled trigger: $trigger"
    }
    return $ret
}

# --------------------------------------------------------------------------#
# SECTION:            I/O FUNCTIONS
# --------------------------------------------------------------------------#

##################################################
# Create an output directory into which all output
# files and the output log will be placed.
##################################################
proc setDebugOn {toolName} {
    if {[getInfo DEBUG_CHANNEL] == ""} {
        set dbugfid [setlog on "$toolName.DEBUG.[clock format [clock seconds] -format [getInfo dateFormat]].out"]
        setInfo DEBUG_CHANNEL $dbugfid
    }
    updateInfo DEBUG_ON 1
}
if {[getInfo dateFormat] == "" } {setInfo   dateFormat          "%Y.%m.%d"}
if {[getInfo timeFormat] == "" } {setInfo   timeFormat          "%H.%M.%S"}
if {[getInfo HR] == "" } {setInfo   HR    "==============================================================================="}
if {[getInfo hr] == "" } {setInfo   hr    "===================="}
proc printInitialHeader {toolName description version} {
    putt "Initiating $toolName version $version"
    putt "$description"
    putt "START: [clock format [getStartTime $toolName] -format "[getInfo dateFormat] [getInfo timeFormat]"]"
    putt [getInfo HR]
    putt ""
}
proc getNow {} {
    return [clock format [clock seconds] -format "[getInfo dateFormat] [getInfo timeFormat]"]
}
proc setStartTime {toolName} {
    if {$toolName == ""} {return [clock seconds]}
    updateInfo $toolName.START [clock seconds]
    return [getStartTime $toolName]
}

proc getStartTime {toolName} {
    if {$toolName == ""} {return [clock seconds]}
    if {[getInfo $toolName.START] == ""} {
        setStartTime $toolName
    }
    return [getInfo $toolName.START]
}
proc setEndTime {toolName} {
    updateInfo $toolName.STOP [clock seconds]
}

proc getEndtTime {toolName} {
    return [getInfo $toolName.STOP]
}
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
# outputs to both file and stdout
proc putt {channel {output "no_default_channel"}} {
  # if only one param, use default log
    if {[getInfo suppressOutput] != "SILENT"} {
        if {$channel == "null"} {
            if {[getInfo default_channel] != ""} {
                logit $output no_default_channel
            }
        } else {
            logit $channel $output
        }
        if {$output == "no_default_channel"} {
            set output $channel
        }
        puts $output
        dbug_putt $output
    }
}
proc logit {channel {output "no_default_channel"}} {
    if {[getInfo suppressOutput] != "SILENT"} {
        if {$output == "no_default_channel"} {
            set output $channel
            set default [getInfo default_channel]
            if {$default == ""} {
                set default [setlog on "DEFAULT_LOG.[clock format [clock seconds] -format [getInfo dateFormat]].out"]
                setInfo default_channel $default
            }
            set channel $default
        }
        puts $channel $output
        flush $channel
        dbug_putt $output
    }
}
proc dbug_putt {output {status INFO}} {
    if {[getInfo DEBUG_CHANNEL] != ""} {
        puts [getInfo DEBUG_CHANNEL] "$status: [getNow]: $message"
    }
}

if {[info procs "setlog"] == {}} {
    proc setlog {action logfile} {
    if {[getInfo suppressOutput] != "SILENT"} {
        switch [string toupper $action] {
            "ON" {
                if [catch {open $logfile w} RE__log] {
                    error "Could not open logfile $logfile"
                }
            }
            "OFF" {
                if {$logfile == ""} {set logfile [getInfo defaultChannel]}
                if [catch {close $logfile} RE__log] {
                    error "Could not close logfile $logfile"
                }
            }
            "APPEND" {
                if [catch {open $logfile a} RE__log] {
                    error "Could not open logfile $logfile"
                }
            }
            default {
                set RE__log -1
            }
        }
        return $RE__log
        }
    }
}


# ##########
# @proc SendMess
# @not working
# ##########
proc SendMess { message } {
    set currentTool [getInfo currentTool]
    if {$currentTool == ""} {set currentTool "Processing"}
    putt $message
    if {[set e_mail [getInfo e_mail]] != "" && $email !="nomail"} {
        if { [string first / [pwd]] == 0 } {
                 exec echo $message | mailx -s "$currentTool terminated.  Attention Required" $e_mail
        } else {
              LOGMess $currentTool $message
        }
    }
}


# ##########
# @proc         SendEmail
# @description  Send an email message in Unix or Windows environments.
# @notes(Linux) Linux requires only a message, recipient, and subject.  Mailx
#               should be pre-configured.
# @notes(Win)   Windows requires all parameters.
# @notes(all)   Provide empty quotes (e.g. "") for parameters you don't use.
# ##########
proc SendEmail {sender recipient subject message smtp_server} {
    set OS          ""
    set attachments ""

    # Windows OS check
    if {[catch {exec sc query} err]} {
        set OS "Not Windows"
    } else {
        set OS "Windows"
    }

    # Linux OS check
    if {$OS == "Not Windows"} {
        if {[catch {exec uname} err]} {
            set OS "Neither"
        } else {
            set OS "Linux"
        }
    }

    putt "INFO: Detected $OS OS."

    if {$OS == "Linux"} {
        putt "INFO: command: exec echo $message | mailx -s \"$subject\" $recipient"
        if {[catch {exec echo $message | mailx -s "$subject" $recipient} err]} {
            putt "ERROR: Message not sent!"
            putt "INFO: Error was \"$err\""
            putt "INFO: Recipient: $recipient"
            putt "INFO: Message:\n$message\n"

            return 1
        }
    } elseif {$OS == "Windows"} {
        putt "INFO: command: exec powershell send-mailmessage -to '$recipient' -from '$sender' -subject '$subject' -body '$message' -smtpServer $smtp_server"
        if {[catch {exec powershell send-mailmessage -to '$recipient' -from '$sender' -subject '$subject' -body '$message' -smtpServer $smtp_server} err]} {
            putt "ERROR: Message not sent!"
            putt "INFO: Error was \"$err\""
            putt "INFO: Recipient: $recipient"
            putt "INFO: Message:\n$message\n"

            return 1
        }
    } else {
        putt "ERROR: Could not deduce which Operating System this is."
        putt "ERROR: Message not sent!"
        putt "INFO: Recipient: $recipient"
        putt "INFO: Message:\n$message\n"

        return 1
    }

    putt "INFO: Message sent successfully."
    return 0
}
proc p_uts {message} {
    if {[getInfo suppressOutput] != "SILENT"} {
       puts $message
    }
}
proc p_runtimeError {message} {
    set  message "***
ERROR: FATAL: $message
STATUS: FAIL
***"
return $message
}
# ##########
# @proc makeDir
# @handles errors on mkdir
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc makeDir {dir} {
    if {$dir == ""} {
        set dir [pwd]
    }
    set dir [file normalize $dir]
        if {![file exists $dir]} {
            if [catch {file mkdir $dir} err] {
                error "makdDir: Unable to make directory $dir.\n$::errorInfo"
            }
        } elseif {![file isdirectory $dir]} {
            error "$dir exists, but is not a directory.  Cannot create directory $dir"
        }
    return [file normalize $dir]
}
# ##########
# @proc getReportFile
# @  note: this ensures that if another script source and calls dbcompare with a report file that has
    # a path on it.
    # that any directory path prepended to reporfile will be created also,
    # putt null will output to default_channel only if it exists.
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getReportFile {toolName outdir reportfile}  {
    if [catch {makeDir $outdir} outdir] {
        putt null "Cannot create output directory $outdir."
        putt null "Output file $reportfile will be in [pwd]"
        set outdir "[pwd]"
    }
    if {[file pathtype $reportfile] == "relative"} {
        set reportDir [file dirname $reportfile]
        if {$reportDir != "."} {
            if [catch {makeDir $outdir/$reportDir}] {
                putt null "Cannot create  directory $outdir/$reportDir."
                putt null "Output file $reportfile will be in $outdir"
                set reportfile [file tail $reportfile]
            }
        }
        if {$outdir == ""} {
            set outdir [pwd]
        }
    }

    # create report file, output starting
    set rpt [setlog ON [file join $outdir $reportfile]]
    updateInfo $toolName.OUTDIR $outdir
    updateInfo $toolName.REPORT_FILE $reportfile
    return $rpt
}

##################################################
# If the file can't be moved, then it is copied.
# The original file will be deleted at the end of
# the AutoScript process. (DVT 330389)
##################################################
# ##########
# @proc MoveOutput
# @Moves specified files/filetypes to specified directoty
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc MoveOutput {filetypeList outDir} {
    if [catch {makeDir $outDir} outDir]  {
        putt "Cannot move ouput files\n$outDir"
        return -1
      }
    set delete_it_lst ""
    foreach filetype $filetypeList {
        set outputfile_list [glob -nocomplain $filetype]
        foreach outputfile $outputfile_list {
            set err1 ""
            set err2 ""
            if { [catch {file rename -force $outputfile $outDir/[file tail $outputfile]} err1 ]} {
                if { [catch {file copy -force $outputfile $outDir/[file tail $outputfile]} err2 ]} {
                    puts "*** ERROR - Unable to copy or move $outputfile to the $outDir directory."
                    if {$err1 != ""} {
                        puts "err1: $err1"
                    }
                    if {$err2 != ""} {
                        puts "err2: $err2"
                    }
                    putt "*** ERROR - Unable to copy or move $outputfile to the $outDir directory."
                } else {
                    lappend delete_it_lst $outputfile
                }
            } else {
                putt "Moved $outputfile to the $outDir directory."
            }
        }
   }
   return $delete_it_lst
}
# ##########
# @proc checkEmail
# @checks for successful email sent.
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc checkEmail {e_mail} {
    if {$e_mail == "" || $e_mail == "nomail"} {
        return 0
    }
      set message "Enter the word 'GOTIT' at the command prompt\n and press ENTER to confirm receipt of this test e-mail."
      puts "A test e-mail will be sent.\nOpen it for verification instructions."
      puts "If you do not receive an e-mail within a reasonable amount of time,\ntype quit at the prompt."
      if { [string first / [pwd]] == 0 } {
         exec echo $message | mailx -s "preUpgradeEval.tcl Test Message.  Acknowledge Receipt." $e_mail
         } else {
           LOGMess AutoScript $message
         }
      gets stdin verify
      if { [string toupper $verify] != "GOTIT" } {
        if {[string tolower $verify] == "quit"} {
            puts "Goodbye"
            exit
        }
        puts "Invalid e-mail verification."
        puts "If this server does not support e-mail,"
        puts "use only three arguments when invoking preUpgradeEval.tcl."
        puts "Type continue to continue processing, or exit to exit."
        flush stdout
        gets stdin verify
        if {[string tolower $verify] != "continue"} {
            puts "Goodbye"
            exit
        }
    }
}
# ##########
# @proc getLines
# @returns contents of file as \n separated list
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getLines {filename} {
    if {![file exists $filename]} {
        set err "$filename not found.\nCheck your spelling and try again."
        error $err
    }
    if [catch {
        set fid [open $filename r]
        set conts [split [string trim [read $fid]] \n]
        close $fid
    } err] {
        error "File $filename not readable: $err"
    }
    return $conts
}
# prompt for input, offer help, disallow empty responses where directed
#------------------------------------------------------------------------------
# ##########
# @proc getUserResponse
# @more robust version to get user input
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getUserResponse { str {silent "0"} {notnull N} { hlp "No help available" } } {
   while { 1 } {
      puts -nonewline "$str"
      flush stdout
      if {$silent} {puts "\nRunning in SILENT mode - returning Y."; return Y}
      set rp [string toupper [gets stdin]]
      # second clause is for highly literal people :-)
      if { $rp != "?" && $rp != "'?'" } {
        if {[string toupper $rp] == "Q"} {
            exit
          }
         if { $rp != "" || $notnull == "N" } {
            return $rp
         } else {
            puts "A parameter is required"
         }
      }
      puts "\n$hlp\n"
   }
}

#from dbcompare
# ##########
# @proc Press_Enter
# @handles i/o if user should determine if they wish to contiue
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc Press_Enter {} {
    set silent [getInfo silent]
    set AutoScript [getInfo AutoScript]
    if {$silent == 0 && $AutoScript == "no" } {
        flush stdout
        puts "Press Enter to acknowledge."
        gets stdin i
        exit
    }
}
# ##########
# @proc runSilent
# @variant to determine if "silent" is in command line args
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc runSilent {argv} {
    if [regexp -nocase {silent} [join $argv]] {
        return 1
    } else {
        return 0
    }
}
# ##########
# @proc delete_like proc to delete all files matching
# @limit is five (to avoid catastrophe)
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc delete_like {pattern} {
    set no 0
    catch {glob -nocomplain $pattern} flist
    if {[llength $flist] > 5} {error "Too many matched files to delete"}
    foreach f $flist {
        if [catch {file delete -force $f}] {
            incr no
        }
    }
    return $no
}
# todo move to common utilities
proc filejoinx {args} {
    set token "/"
    set path [lindex $args 0]
    foreach arg [lrange $args 1 end] {
            append path "$token[string trim $arg $token]"
    }
    set s [expr [string first "/" $path] + 1]
    regsub -all -start $s $token\{2,9\} $path "$token" path
    regsub "$token\$" $path "" path
    return $path
}
proc getItemsList {arrayName infile} {
    upvar $arrayName convArray
    set convArray(ITEMS) ""
    set convArray(PARENTS) ""
    set convArray(REVISIONS) ""
    set convArray(VERSIONS) ""
    set fid [open $infile r]
    set conts [split [string trim [read $fid] ] \n]
    close $fid
    set itemList ""
    foreach line $conts {
        if [regexp {^[\s]*#} $line] { continue}
        if {[string trim $line] == ""} {continue}
        set line [split $line \t]
        lappend convArray(ITEMS) [lindex $line 0]
        lappend convArray(PARENTS) [lindex $line 1]
        lappend convArray(REVISIONS) [lindex $line 2]
        lappend convArray(VERSIONS) [lindex $line 3]
    }
    return $convArray(ITEMS)
}
proc validateItemExistance {arrayName dir} {
    upvar $arrayName convArray
    foreach item $convArray(ITEMS) {
        if {![file exists $dir/$item.sql]} {
            set i [lsearch -exact $convArray(ITEMS) $item]
            if {$i < 0} {continue} ;# impossible? should be
            set convArray(ITEMS) [lreplace $convArray(ITEMS) $i $i]
            set convArray(PARENTS) [lreplace $convArray(PARENTS) $i $i]
            set convArray(REVISIONS) [lreplace $convArray(REVISIONS) $i $i]
            set convArray(VERSIONS) [lreplace $convArray(VERSIONS) $i $i]
        }
    }
    return $convArray(ITEMS)
}
proc getAllItemFiles {itemsDir} {
    set itemsList [glob -nocomplain -directory $itemsDir *.sql]
    set items ""
    foreach item $itemsList {
        if {[regexp {^[\d]{6}\.[\d]{1,3}} [file tail $item] number]} {
            lappend items $number
        }
    }
    return $items
}
# --------------------------------------------------------------------------#
# SECTION:            STRING/LIST FUNCTIONS
# --------------------------------------------------------------------------#
# proc getValueFor {path} {
#     set pList [split $path "."]
#     set pLen [llength $pList]
#     set n [lindex $pList 0]
#     upvar $n temp
#     return [getArrayValueAt ]
# }
# example modelDef.USER_TAB_COLUMNS.MEM_MEMBER.MEM_UID.
proc getValuesFor {path} {
    set pList [split $path "."]
    set pLen [llength $pList]
    set n [lindex $pList 0]
    upvar $n temp
    if {$pLen > 2} {
        set hi [lsearch $temp([lindex $pList 1].header) [lindex $pList 2]]
    }
    if {$pLen > 3} {
        set ki [lsearch [lindex $temp([lindex $pList 1].key) $hi] [lindex $pList 3]]
    }
    # 5 = 4 + attribut Name
    switch $pLen {
        0 {return ""}
        1 {return [array get temp]}
        2 {return $temp([lindex $pList 1].header)}
        3 {return [lindex $temp([lindex $pList 1].key) $hi]}
        4 {return [lindex [lindex $temp([lindex $pList 1].data) $hi] $ki]}
        5 {return [lindex [lindex [lindex $temp([lindex $pList 1].data) $hi] $ki] $temp(DEF.[lindex $pList 1].data.index.[lindex $pList 4])]}
    }
    error "Depth of search beyond depth of data"
}
#  <p> <br> gets the "data" for a particular object
# </p>
# @author  LAQ
# @exceptions
# @
# @param
# @return
proc p_getArrayDatumFor {arrayName object header key} {
    upvar $arrayName A
    set hI [lsearch -sorted $A($object.header) $header]
    set kI [lsearch [lindex $A($object.key) $hI] $key]
    return [lindex [lindex $A($object.data) $hI] $kI]
}

#  <p> <br>
# </p>
# @author  LAQ
# @exceptions
# @
# @param
# @return
proc p_getArrayDatumAt {arrayName object headerIndex {keyIndex ""}} {
    upvar $arrayName A
    if {$keyIndex == ""} {
        return [lindex $A($object.data) $headerIndex]
    } else {
        return [lindex [lindex $A($object.data) $headerIndex] $keyIndex]
    }
}

#  <p> <br> This is the main script function
# </p>
# @author  LAQ
# @exceptions
# @
# @param
# @return
proc p_getArrayDataFor  {arrayName object header {key ""}} {
    upvar $arrayName A
    set i [lsearch $A($object.header) $header]

    if {$key == ""} {
        return [lindex $A($object.data) $i]
    } else {
        set j [lsearch [lindex $A($object.key) $i] $key]

        return [lindex [lindex $A($object.data) $i] $j]
    }
}

#  <p> <br>
# </p>
# @author  LAQ
# @exceptions
# @
# @param
# @return
proc p_getArrayIndexFor {arrayName object header {key ""}} {
    upvar $arrayName A
    set hI [lsearch -sorted $A($object.header) $header]
    if {$key == ""} {return $hI}
    return [lsearch [lindex $A($object.key) $hI] $key]
}
#  <p> <br>
# </p>
# @author  LAQ
# @exceptions
# @
# @param
# @return
proc dbc_getArrayIndexFor {arrayName object header {key ""}} {
    upvar $arrayName A
    if {$header != ""} {
        set hI [lsearch -sorted $A($object.header) $header]
        if {$key == ""} {return $hI}
        return "$hI [lsearch -all [lindex $A($object.key) $hI] $key]"
    } elseif {$key != ""} {
        set keys ""
        #iterate through a nested list of lists table(keys)
        for {set keysI 0} {$keysI < [llength $A($object.key)]} {incr keysI} {
            if {[set keyI [lsearch -all [lindex $A($object.key) $keysI] $key]] != ""} {
                return "$keysI $keyI"
            }
        }
    }
    return -1
}
#  <p> <br>
# </p>
# @author  LAQ
# @exceptions
# @
# @param
# @return
proc p_getArrayKeyFor {arrayName object header {key ""}} {
    upvar $arrayName A
    set hI [lsearch -sorted $A($object.header) $header]
    if {$key == ""} {return [lindex $A($object.header) $hI]}
    return [lindex [lindex $A($object.header) $hI] [lsearch [lindex $A($object.key) $hI] $key]]
}
proc updateArrayData {arrayName object header key newVals} {
    upvar $arrayName A
    set hI [lsearch -sorted $A($object.header) $header]
    if {$key != ""} {
        set kI [lsearch [lindex $A($object.key) $hI] $key]
        set newVals [lreplace [lindex $A($object.data) $hI] $kI $kI $newVals]
    }
    set A($object.data) [lreplace $A($object.data) $hI $hI $newVals]
}
proc findListItem {listName searchItem} {
    upvar $listName lname
    if [info exists lname] {
        return [lsearch -regexp $lname "\\m$searchItem\\M\.*"]
    } else {
        return [lsearch -regexp $listName "\\m$searchItem\\M\.*"]
    }
}
proc findListItemAll {listName searchItem} {
    upvar $listName lname
    if [info exists lname] {
        return [lsearch -all -regexp $lname "\\m$searchItem\\M\.*"]
    } else {
        return [lsearch -all -regexp $listName "\\m$searchItem\\M\.*"]
    }
}
# <p>
#   <br> Get Specific Keys from an Array
# </p>
#
# @author   LAQ
# @param    arrayRef    The name of the Array
# @param    filter      Search pattern for array keys
# @param    endLine     endLine character - change if want other than existing value SHOWARRAYendLine
# @param    delim       The delimiter between the name-value pairs
# @return   string      All the key-values pairs in an easy-to-print string
proc showArray {array_name {filter "*"} {endLine ""} {delim ""}} {
    upvar $array_name temp
    set retval ""
    if {$delim == ""} {set delim [getShowArrayDelim]}
    foreach n [lsort -dictionary [array names temp $filter]] {
        lappend retval "$n$delim\{$temp($n)\}"
    }
    if {$endLine == ""} {set endLine [getShowArrayEndLine]}
    return [join $retval "$endLine"]
}
proc getShowArrayDelim {} {
    set delim [getInfo SHOWARRAYDELIM]
    if {$delim == ""} {set delim " "}
    return "$delim"
}
proc setShowArrayDelim {delim} {
    updateInfo SHOWARRAYDELIM {$delim}
}
proc getShowArrayEndLine {} {
    set endLine [getInfo SHOWARRAYENDLINE]
    if {$endLine == ""} {set endLine " "}
    return "$endLine"
}
proc setShowArrayendLine {endLine} {
    updateInfo SHOWARRAYENDLINE $endLine
}
proc showArrayNames {array_name {filter "*"} } {
    upvar $array_name temp
    set retval ""
    foreach n [lsort -dictionary [array names temp $filter]] {
        lappend retval "$n"
    }
    return [join $retval [getShowArrayEndLine]]
}
# srange
# author laq
# string function to split strings at specified char string
# parameters
# section = to, from, between (string up to token, or string after token or string between tokens)
# token = char string to split on
# s = string
# location (optional) first, last default=first
# returns the substring, or "" if token isn't found
proc srange {section token s {location "first"}} {
    if {$section == "to"} {
        set sub [string range $s 0 [expr [string $location $token $s] -1]]
    } elseif {$section == "from"} {
        set sub [string range $s [expr [string $location $token $s] +1] end]
    } elseif {$section == "between"} {
        if {$location == "nocomplain"} {
            set sub [srange from $token $s]
            set p [srange to $token $sub]
            if {$p != ""} {
                set sub $p
            }
        } else {
            set sub [srange to $token [srange from $token $s]]
        }
    } else {
        error "$section is not a valid option.  Should be to or from or between."
    }
    return $sub
}

# arraytoList
# author laq
# function to turn subset of an array into a  list
# where name value pairs are joined by specified token
# parameters
# ray = the array, passed as pointer
# element search pattern for array elements
# token = char string to join pairs
# returns the list
proc arraytoList {ray element {token =}} {
    upvar $ray r
    set returnval ""
    foreach {name value} [array get r $element] {
        lappend returnval $name$token$value
    }
    if {[llength $returnval] == 1} {
        return [lindex $returnval 0]
    }
    return [string trimright $returnval *]
}

# p_pad_version
# function to pad . separated version to two chars per section
# params version ex 1.5.2
# returns list ex {01 05 02}
proc p_pad_version { ver } {
        set v_lst [split $ver .]
        set count [llength $v_lst]
        set i 0
        set ver_lst ""
        while {$i < $count} {
            if { [string length [lindex $v_lst $i]] < 2 } {
                lappend ver_lst "0[lindex $v_lst $i]"
            } else {
                lappend ver_lst [lindex $v_lst $i]
            }
            incr i
        }
    return $ver_lst
}

# p_padTo
# generalized function to pad version piece to varialbe number of chars
# params
# ver version piece
# count length to pad to default=2
# char char to add default=0
# returns padded string
proc p_padTo {ver {count 2} {char "0"} } {
    set i [string length $ver]
    set pre ""
    while {$i < $count} {
        append pre "$char"
        incr i
    }
    return "$pre$ver"
}
# ##########
# @proc p_unpad_version
# @splits a . delimited version, returning unpadded version bits
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc p_unpad_version {ver} {
    set ver_lst [split $ver .]
    set retval ""
    foreach v $ver_lst {
        if {[string range $v 0 0] == "0"} {
            set v [string trimleft $v "0"]
            if {$v == ""} {set v "0"}
            lappend retval $v
        } else {
            lappend retval $v
        }
    }
    return $retval
}
# ##########
# @proc p_splitat
# @splits a version at any arbitrary number of characters
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc p_splitat {ver {count 2} } {
    set i 0
    set end -1
    set retval ""
    for {set i 0} {$i < [string length $ver]} {incr i $count} {
        lappend retval [string range $ver $i [incr end $count ]]
    }
    return $retval
}
# sqlList
# author laq
# joins a list of [strings]  into a single quote comma separated list
# useful for in() statments
# params
# tcllist = a tcl list
# returns  string of format 'A','B'... etc.
proc sqlList {tcllist} {
return "'[join $tcllist "','"]'"
}
# ##########
# @proc
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc p_interpose {ver {token "."} {count 2} } {
    if {[expr [string length $ver] % $count] != 0} {
        error "invalid version to split: length of [string length $ver] does not divide evenly by $count"
    }
    return [join [p_splitat $ver $count] $token]
}
# splat
# generalize split function that splits on multi-character token
# params
# str string to split
# sep character string to split on
# returns a list
proc splat {str sep} {
    set s 0
    set e 0
    set l [string length $sep]

    set ret_lst {}
    while {$e < [string length $str] && $e >-1} {
        set e [string first "$sep" $str $s]
        if {$e > -1} {
            lappend ret_lst [string range $str $s [expr $e - 1]]
            set s [expr $e + $l]
        } else {
            lappend ret_lst [string range $str $s end]
        }
    }
    return $ret_lst
}
# ##########
# @proc getDisplayConnection
# @removes password from logon string
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getDisplayConnection {logonstring} {
    set schemaName [srange to "/" $logonstring]
    set database [srange from "@" $logonstring]
    return $schemaName@$database
}
# ##########
# @proc getProductFromScript
# @parses script name to return product script is for
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc getProductFromScript {scriptname} {
    set productPrefix ""
    regexp {^[^\d]+} [string trim $scriptname] productPrefix
    if {$productPrefix == ""} {
        error "Product not found"
    }
    return $productPrefix
}
# these from DBCompare
# This procedure inserts separating paragraphs into the
# comparison file when a new type of processing such as
# adding columns or rebuilding tables is to occur.
# ##########
# @proc break_lines
# @used by dbcompare to do output
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc break_lines {separator section_heading } {
     return "\#\n\#\n$separator\n\# $section_heading\n$separator\n\#"
 }

# ##########
# @proc parse_clause
# @translates column datatypes to Lcor usage
# ##########
# @author
# @param
# @exception
# @see
# @return lcorp type column description
# ##########
proc parse_clause {format_lst } {
    set parsed_column ""
     set type [lindex $format_lst 0]
     append parsed_column $type
     if { $type == "NUMBER" || $type == "VARCHAR2" } {
        append parsed_column \(
        }
     set fld_len [lindex $format_lst 1]
     if { $type == "VARCHAR2" } {
          append parsed_column $fld_len \)
        }
     set fld_siz [lindex $format_lst 2]
     if { $type == "NUMBER" } {
          append parsed_column $fld_siz
         }
     set fld_pre [lindex $format_lst 3]
     if { $type == "NUMBER" } {
         if { $fld_pre > 0 } {
             append parsed_column , $fld_pre
            }
         append parsed_column \)
       }

       return $parsed_column
}

# This procedure formats column information to be used in building
# a command such as add_column
# dereferencing concat_column as list for items that are {} bracketed (like with LONG RAW)
proc parse_column {concat_column} {
     set col_info_lst [split [lindex $concat_column 0] \#]
     set format_lst [split [lindex $col_info_lst 1] !]
     set parsed_column "[lindex $col_info_lst 0] [lindex $col_info_lst 1] "
     append parsed_column [parse_clause $format_lst ]
     append parsed_column \;
     return $parsed_column

}
# ##########
# @proc CleanString
# @removes all invalid items from an sql statment
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc CleanString { statement } {
    set statement [string toupper $statement]
    regsub -all \} $statement " " statement
    regsub -all \{ $statement " " statement
    regsub -all \t $statement " " statement
    regsub -all \" $statement " " statement
    set statement [string trim $statement]
    set i_squeeze 3
    while { $i_squeeze > 0 } {
       set i_squeeze [regsub -all "  " $statement " " statement]
      }
    return $statement
}
proc doColIdIntegrityCheck {arrayName} {
    upvar $arrayName modelDef
    set tabI 0
    set rval ""
    foreach table $modelDef(USER_TAB_COLUMNS.header) {
        set keys [lindex $modelDef(USER_TAB_COLUMNS.key) $tabI]
        set datas [lindex $modelDef(USER_TAB_COLUMNS.data) $tabI]
        set used ""
        set no 0
        set testnums ""
        set testNames ""
        set testData ""
        array unset KEYS
        array set KEYS ""
        array unset DATA
        array set DATA ""
        # check for duplicate ids, build up lists
        foreach key $keys datarow $datas {
            set id [lindex $datarow $modelDef(DEF.USER_TAB_COLUMNS.data.index.COLUMN_ID)]
            if {[lsearch $used $id] < 0} {
                set KEYS($id) $key
                set DATA($id) $datarow
            } else {
                lappend testnums $id
                lappend testNames $key
                lappend testData $datarow
                set no 1
            }
            lappend used $id
        }
        set ids [lsort -integer $used]
        # check for skipped ids. (this will also fail for tables that failed the prior loop)
        set cid 1
        foreach id $ids {
            if {$id != $cid} {
                set no 1
                break
            }
            incr cid
        }
        if {$no} {
            # replace the column ids with sequenced numbers.
            lappend rval $table
            set cid 1
            set newdata ""
            set newused ""
            array unset NEWDATA
            array set NEWDATA ""
            foreach id $ids {
                if {[lsearch $newused $id] < 0} {
                    set NEWDATA($cid) [lreplace $DATA($id) $modelDef(DEF.USER_TAB_COLUMNS.data.index.COLUMN_ID) $modelDef(DEF.USER_TAB_COLUMNS.data.index.COLUMN_ID) $cid]
                    lappend newused $id
                    set NEWDATA($KEYS($id)) $cid
                } else {
                    set dindex [lsearch $testnums $id]
                    set testnums [lreplace $testnums $dindex $dindex X]
                    set datarow [lindex $testData $dindex]
                    set NEWDATA($cid) [lreplace $datarow $modelDef(DEF.USER_TAB_COLUMNS.data.index.COLUMN_ID) $modelDef(DEF.USER_TAB_COLUMNS.data.index.COLUMN_ID) $cid]
                    set NEWDATA([lindex $testNames $dindex]) $cid
                }
                incr cid
            }
            foreach key $keys {
                lappend newdata $NEWDATA($NEWDATA($key))
            }
            set modelDef(USER_TAB_COLUMNS.data) [lreplace $modelDef(USER_TAB_COLUMNS.data) $tabI $tabI $newdata]
        }
        incr tabI
    }
    return $rval
}
proc trimListItems {myList {trimvals ""}} {
    set yourList ""
    foreach item $myList {
        if {$trimvals == ""} {
            set item [string trim $item]
        } else {
            foreach t $trimvals {
                set item [string trim $item "$t"]
            }
        }
        lappend yourList $item
    }
    return $yourList
}
proc compareLists {listA listB} {
    set extraItems ""
    set missingItems ""
    set extraItems [missingFromListB $listA $listB]
    set missingItems [missingFromListB $listB $listA]
    return  [list $extraItems $missingItems]
}
# --------------------------------------------------------------------------#
# SECTION:            SQL/DATABASE FUNCTIONS
# --------------------------------------------------------------------------#
proc makeSQLcols {type arglist} {
    set p ""
    foreach itemlist $arglist {
        foreach item $itemlist {
            if {[regexp {\.} $item] == 0} {
            lappend p $type.$item
            } else {
                # if it has a dot, it already has a type association
                lappend p $item
            }
        }
    }
    return $p
}
proc runSQLA {connectString type columnList from_where results {isolateColumnList ""}} {
    upvar $results output
    set here [pwd]
    cd [getInfo WORKING_DIRECTORY]
    set schema [srange to "/" $connectString]
    set columnSQL "'{ {'||[join $columnList "||'} {'||"]||'}'"
    set linesize 1000
    set longSize 1000
    set setLong ""
    set icFormat ""
    set outfile $schema.$type.lst
    set sqlFile $schema.$type.sql
    if {$isolateColumnList != ""} {
        set setLong "set long $longSize"
        set i 0
        foreach ic $isolateColumnList {
            lappend icsql "$ic COL_$i"
            append icFormat "column COL_$i format a$longSize justify left word_wrapped\n"
        }
        append columnSQL "||' {',[join $icsql ",'} {',"],'}'"
    }
    set columnSQL "select $columnSQL ||'}'"
    set now [clock seconds]
    set fid [open $sqlFile w]
    puts $fid "set echo off"
    puts $fid "set pagesize 0"
    puts $fid "$setLong"
    puts $fid "set heading off"
    puts $fid "set feedback off"
    puts $fid "set trimspool on"
    puts $fid "set linesize $linesize"
    puts $fid "$icFormat"
    puts $fid "$columnSQL"
    puts $fid "$from_where;"
    puts $fid "exit"
    close $fid
    if [catch {exec [getSQLPLUS] -L -S $connectString @$sqlFile} output] {
      putt "SQL error : $output\n see $sqlFile"
      putt "connectString = $connectString"
      putt "columnList = $columnList"
      putt "from_where = $from_where"
      putt "isolateColumnList = $isolateColumnList"
    error "SQL error : $output\n see $sqlFile"
    }
    # TODO  move into a proc; also allow debugging to leave the file instead of deleting it

    catch {file delete -force $sqlFile}
    cd $here
    return $outfile
}
proc runSQLB {connectString sql rval {spool ""}} {
    upvar $rval output
    set here [pwd]
    cd [getInfo WORKING_DIRECTORY]
    set sqlFile "SQLB.sql"
    set fid [open $sqlFile w]
    puts $fid "whenever sqlerror exit 5"
    puts $fid "set echo off"
    puts $fid "set pagesize 0"
    puts $fid "set heading off"
    puts $fid "set feedback off"
    puts $fid "set linesize 200"
    if {$spool != ""} {
        puts $fid "spool $spool"
    }
    puts $fid "$sql"
    if {$spool != ""} {
        puts $fid "spool off"
    }
    puts $fid "exit"
    close $fid

    if {[catch {exec [getSQLPLUS] -L -S $connectString @$sqlFile} output] || [lindex $::errorCode 2] == 5} {
        puts "SQL error : $::errorInfo\n$output\n"
        return -1
    }
    # TODO  move into a proc; also allow debugging to leave the file instead of deleting it
    catch {file delete -force $spool}
    catch {file delete -force $sqlFile}
    cd $here
    return 0
}
proc runSQL {connectString type columnList from_where results {isolateColumnList ""}} {
    upvar $results output
    set rval ""
    set outfile [runSQLA $connectString $type $columnList $from_where rval $isolateColumnList]
    # TODO : handle this error
    if {[regexp {ORA-[\d]+} [string range $rval 0 2000]]} {
        set rval ""
    }
    foreach line $rval {
        set line [string trim $line]
        if {$line == ""} {continue}
         set r ""
        foreach item $line {
            lappend r [string trim $item]
        }
        lappend output $r
    }
    return $outfile
}

# ##########
# <p>
#   <br> SQL_Error
#   <br> common version of sql error that handles execsql failure
#   <br> If the SQL_Statement global is present it will output this variable if sql is null
#   <br> If the rpt global is present then this will print to standard out and the rpt file instead of the log file
# </p>
#
# @author     RE
# @author     JRW
# @since      04/30/2015
# @param      sql       The offending SQL statement, or passed on the global SQL_Statement; sql takes precedence
# @exception  TCL_ERROR Executes error in all cases
proc SQL_Error {{sql ""}} {
    global SQL_Statement rpt

    if {[info exist SQL_Statement] && $sql == ""} {
        set sql $SQL_Statement
    }

    if {$sql == ""} {
        set sql "SQL STATEMENT UNDEFINED"
    }

    #Put together the Error Messages
    lappend errOut ""
    lappend errOut "*** ERROR - SQL:"
    lappend errOut $sql
    lappend errOut [getinfo all]
    lappend errOut ""

    lappend errMsg "ERROR: SQL error."
    lappend errMsg "The current process failed due to the following error:"
    lappend errMsg [getinfo all]
    lappend errMsg $sql
    lappend errMsg ""
    lappend errMsg "Contact the EXL Healthcare Support Department for assistance:"
    lappend errMsg [getInfo SupportContact]


    #Print out Errors
    set errOut [join $errOut \n]
    set errMsg [join $errMsg \n]

    if {[info exist rpt]} {
        putt $rpt $errOut
        puts $rpt $errMsg
        close $rpt
    } else {
        putt $errOut
    }
    error $errMsg
}


# ##########
# @proc insertSHS
# @ inserts a STARTED record into SHS
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
proc insertSHS {dbh scriptname type desc status newversion {oldversion ""}} {
    set nextuid ""
    set sql "Select SHS_SEQUENCE.nextval into :nextuid from dual"
    execsql use $dbh $sql
    if {$nextuid == ""} {error -2}
        set sql [getSHSinsert $scriptname $type $desc $status $newversion $oldversion $nextuid]
    catch {execsql use $dbh $sql "SQL_Error {$sql}"} err
    if {$err != 0} {
        error $err
    }
    return $nextuid
}
# ##########
# @proc getSHSinsert
# @creates an insert statment for SHS row
# ##########
# @author LAQ
# @param
# @exception
# @see
# @return string update statment
# ##########
proc getSHSinsert {scriptname type desc status {newversion ""} {oldversion ""} {nextuid "SHS_SEQUENCE.NEXTVAL"}} {
  return "INSERT INTO SHS_SCHEMA_HISTORY (
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
) values (
   $nextuid,
  '$type',
  '$oldversion',
  '$newversion',
  '$scriptname',
  '$desc',
  trunc(SYSDATE),
  TO_CHAR (SYSDATE,'HH24MI'),
  '$status',
  SYSDATE,
  '-4')"
}
# ##########
# @proc updateSHSuid
# @Updated schema SHS record using script entry UID for finding correct row to update
# ##########
# @author LAQ
# @param db
# @exception
# @see
# @return 0 on success
# ##########
proc updateSHSuid {dbh uid {oldversion ""} {status "Successful"}} {
set sql "UPDATE  SHS_SCHEMA_HISTORY
    SET SHS_VERSION_OLD = '$oldversion',
    SHS_RESULTS = '$status',
    SHS_LAST_UPDATE_DATE = sysdate,
    SHS_USR_UID_UPDATED_BY = -4
    WHERE SHS_UID = '$uid'"
    catch {execsql use $dbh $sql} err
    if {$err != 0 } {error $err}
    catch {execsql use $dbh COMMIT}
    return $err
}
# ##########
# @proc updateSHSscript
# @
# ##########
# @author
# @param
# @exception
# @see
# @return
# ##########
# proc updateSHSscript {dbh script_name} {
# set sql "UPDATE  SHS_SCHEMA_HISTORY
    # SET SHS_VERSION_OLD = (SELECT MAX (SHS_VERSION_NEW)
        # FROM    SHS_SCHEMA_HISTORY
        # WHERE   SHS_UID <> ( SELECT MAX (SHS_UID) FROM  SHS_SCHEMA_HISTORY)
        # AND     SHS_VERSION_NEW LIKE '$oldversion%'),
    # SHS_RESULTS = 'Successful',
    # SHS_LAST_UPDATE_DATE = sysdate,
    # SHS_USR_UID_UPDATED_BY = -4
    # where SHS_SQL_SCRIPT_NAME = '$script_name'"
    # catch {execsql use $dbh $sql} err
    # if {$err != 0 } {error $err}
    # return $err
# }
# ##########
# @proc getSHSupdate
# @return update statment for SHS
# ##########
# @author LAQ
# @param script_name - for check
# @param oldversion -version to update old to
# @exception
# @see
# @return update sctring
# ##########
proc getSHSupdate {script_name {oldversion ""}} {
    return "UPDATE  SHS_SCHEMA_HISTORY
    SET SHS_VERSION_OLD = '$oldversion',
    SHS_RESULTS = 'Successful',
    SHS_LAST_UPDATE_DATE = sysdate,
    SHS_USR_UID_UPDATED_BY = -4
    where SHS_SQL_SCRIPT_NAME = '$script_name'"
}
# ##########
# @proc run_SQL_Script
# @runs an sql script against database, using a scripting file (eg .bat)
# ##########
# @author
# @param logonstring
# @param script_name
# @param batty -script name to run commands from
# @param dirname directory "batty" to be found
# @param question (depricated)
# @param sign format of the "@" symbol as "@" or "\\@" (for environments that require "@" to be escaped)
# @exception file not found
# @see
# @return 0 on success
# ##########
proc run_SQL_Script {scriptLogonString script_name batty dirname {sign "@"}} {
    set status 0
    set ::errorCode "" ; # clear out any prior errors
    if {$dirname == ""} {
        error "ERROR: fully qualified directory to the script $script_name was not provided."
    }
    if { [file exists [file join $dirname $batty]] } {
        if {[regexp -nocase {asc[0-9]*.bat} $batty all] != 1} {
            puts "WARNING: Command file $batty already exists\n - overwriting it."
        }
    }
    if { ![file exists [file join $dirname $script_name]] } {
        putt "ERROR: $script_name not found."
        error "File not found."
    }
    if {[catch {set cmd_file [open [file join $dirname "$batty"] w 77777]}]} {
        putt ""
        putt "INFO: Cannot open command file: \"$batty\""
        putt "INFO: Waiting 1s due to file lock contention."
        after 1000
        putt "INFO: Retry: open command file: $batty"
        if {[catch {set cmd_file [open [file join $dirname "$batty"] w 77777]}] == 1} {
            error "ERROR: Could not open command file: $batty"
        }
    }
    # todo remove this, we should have it right by this point
    if {$sign == ""} {
        putt "WARNING: Sign variable is empty (should be \@); assigning default..."
        set sign [battyExecTest $scriptLogonString $dirname]
    }
    puts $cmd_file [getUnixHeader]
    puts $cmd_file "cd \"[getInfo WORKING_DIRECTORY]\""
    puts $cmd_file "echo exit | \"[getSQLPLUS]\" $scriptLogonString $sign \"[file join $dirname $script_name]\""
    puts $cmd_file "exit"
    puts $cmd_file "exit"
    close $cmd_file

    if [catch {exec [file join $dirname $batty]} err] {
        set status "An error occurred during execution of $batty"
    }
    if {[regexp -line {^(SP2-.*|ORA-.*)} $err errorMessage] > 0 } {
        putt "Error: encountered execution error: $errorMessage"
        append status "An SQL error occurred running script $script_name\n$errorMessage"
    }
    #if a script doesn't have a spool file, this will catch and error in execution by getting the error level of the bat script
    set test [lindex $::errorCode 2]
    if {!($test == "" || $test == 0) || [regexp -nocase "child process exited abnormally" $err]} {set status "ERROR occurred: $err"}
    return $status
}
proc findSpoolFile {scriptName directory {ext "lst"}} {
    set find_spool ""
    regsub .sql $scriptName {} l_file
    set find_spool [list [lindex [lsort -decreasing [glob -nocomplain -directory $directory $l_file*\_*$ext]] 0]]
    if {$find_spool == ""} {
        error "Script output file for $scriptName ([filejoinx $directory $l_file]) not found."
    } else {
        set find_spool [lindex [lsort $find_spool] end]
    }
    return $find_spool
}
# ##########
# @proc QuestionCompleteness
# @Checks to ensure script completed successfully
# ##########
# @author
# @param script_name - the script that had been run
# @param dbh database handle
# @param there location of script
# @exception on database error
# @see
# @return 0 (success) 1,-1 on failure
# ##########
proc QuestionCompleteness {dbh script_name spoolfile} {
    set status -1
    set SQL_Statement "select max(shs_uid), shs_results
        into :test, :results
    from shs_schema_history where
    shs_sql_script_name = '$script_name' group by shs_results"
      set status [execsql use $dbh $SQL_Statement {SQL_Error $SQL_Statement}]
      #code 100 = no rows returned
    if { $status == 100 } {
        if {![file exists $spoolfile]} {
            error "Spool file '$spoolfile' doesn't exist"
        }
        set fid [open $spoolfile r]
        set conts [read $fid]
        close $fid
        if {![regexp "$script_name has completed" $conts]} {
            set status "It appears that $script_name did not complete successfully.
Could not find expected line:
    $script_name has completed"
        } else {
            set status 0
        }
    } elseif {$status != 0} {
            set status "Database error: returned $status"
    } elseif {$results != "Successful"} {
        putt "Script failure"
        set status "It appears that $script_name did not complete successfully.
SHS entry was not updated to 'Successful'"
    }
        return $status
}
# ##########
# @proc dropColumns
# @drop columns listed at the bottom of the script. (commented out)
# ##########
# @author LAQ
# @param dbh database handle
# @param scriptwPath path/scriptname to check
# @exception
# @see
# @return list of failed and successful drops
# ##########
# drop columns from  the bottom of the script.
# need: script name, script location
# break into : find drop statements
#   : execute drop statments
# exceptions: statement fails
# logging: defer, return log outputs to caller.
# returns drop results per table, status at lindex "end"
proc dropColumns {dbh scriptwPath} {
    set status 0
    set done ""
    set failed ""
    set Noaction ""
    if {[catch {open "$scriptwPath" r} dropping]} {
        error "Could not find $scriptwPath.  Cannot validate success."
    }
    if [catch {
        while { ! [eof $dropping] } {
          gets $dropping may_alter
          set may_alter [string trim $may_alter]
          if { [string first "DROP UNUSED" $may_alter] > 0 && [string first ALTER $may_alter] == 0 } {
               set SQL_Statement [string trimright $may_alter \;]
               regexp -nocase {table (.*?) } $SQL_Statement temp tableName
               set checkTableStatus "select count(*) into :rowCountTemp from $tableName where rownum=1"
               if {[catch {execsql use $dbh $checkTableStatus} err ] || $err < 0} {
                    lappend Noaction "Table $tableName no longer exists!!"
                    incr status
               } elseif {[catch {execsql use $dbh $SQL_Statement} err ] || $err < 0} {
                    lappend failed "FAILED: $SQL_Statement"
                    incr status
               } else {
                    lappend done  "Completed: $SQL_Statement."
               }
          }
        }
    } err] {logit "dropcolumns: $scriptwPath $err"}
    lappend status $Noaction
    lappend status $failed
    lappend status $done
    return $status
}
proc dropDroppedColumns {scriptConnectionString scriptName} {
    runSQLB $scriptConnectionString "EXEC LANDA_CONVERSION.DROP_DROPPED_COLUMNS($scriptName);" droppedColumns.lst
}
# #############################################
    # Close all the files that are left
# #############################################
proc closeOpenChannels {skip} {
    set file_close_lst [file channels file*]
    foreach file_close $file_close_lst {
        if {[lsearch $skip $file_close] < 0} {
            close $file_close
        }
    }
    return
}
#
# ##########
# @proc getSchemaVersion
# @returns the largest, newest version of schema
# ##########
# @author LAQ
# @param dbh - database handle
# @param types types of scripts to check
# @exception none
# @see getSchemaVersions
# @return current schema version
# ##########
proc getSchemaVersion {dbh {types "CREATE EB UPDATE"}} {
    set versions [getSchemaVersions $dbh $types]
    return [lindex $versions 0]
}
# /* getSchemaVersions
# gathers all distinct versions in the schema history table, sorted with greatest on top
# @author LAQ
# @param dbh connection handle to database
# @param types SHS_TYPE, defaults to CREATE, EB, UPDATE
# @return descending sorted list of decimal separated zero padded versions.
# */
proc getSchemaVersions {dbh {types "CREATE EB UPDATE"}} {
    set versions ""
    set types [string toupper $types]
    set SQL "Select distinct(SHS_VERSION_NEW), shs_uid
    into :versions, :uids
    from SHS_SCHEMA_HISTORY
    where SHS_TYPE in ([sqlList $types])
    and SHS_VERSION_NEW is not null
    and SHS_VERSION_NEW not like '-%'
    and upper(SHS_RESULTS) != 'STARTED'
    and lower(SHS_SQL_SCRIPT_NAME) like '%.sql'
    order by SHS_UID desc"
    catch {execsql use $dbh $SQL} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    set temp ""
    foreach ver $versions {
        lappend temp [join [p_pad_version $ver] "."]
    }
    set versions [lsort -decreasing $temp]
    return $versions
}

# /* getFailedScripts
# gathers lists consisting of failed sql script names, version and uids from the schema history table
# @author LAQ
# @param dbh connection handle to database
# @return list shs_sql_script_name, shs_version_new, and shs_uid
# */
proc getFailedScripts {dbh} {
    set SQL "Select SHS_VERSION_NEW, shs_uid, shs_sql_script_name
    into :versions, :uids, :scripts
    from SHS_SCHEMA_HISTORY
    where SHS_TYPE in ('CREATE', 'EB', 'UPDATE')
    and SHS_VERSION_NEW is not null
    and SHS_VERSION_NEW not like '-%'
    and upper(SHS_RESULTS) != 'SUCCESSFUL'
    and lower(SHS_SQL_SCRIPT_NAME) like '%.sql'
    order by SHS_UID desc"
    catch {execsql use $dbh $SQL} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    if {[llength $uids] != 0} {
        return [list $scripts $versions $uids]
    }
    return ""
}

# ##########
# @proc checkBackTables
# @Ensures no "BACK" table exists
# @depricated
# ##########
# @author
# @param dbh the database handle
# @exception
# @see
# @return "" or string message
# ##########
proc checkBackTables {dbh} {
set to_db "this schema"
set SQL_Statement "select nvl(user, 'this schema') into :to_db from dual"
execsql use $dbh $SQL_Statement SQL_Error
set SQL_Statement "select table_name into :back_lst from user_tables where substr(table_name,4,5) = '_BACK' and length(table_name) = 8 and substr(table_name,1,4) in (select substr(tor_table_name,1,4) from tor_table_order)"
execsql use $dbh $SQL_Statement SQL_Error
    set err ""
if { [llength $back_lst] > 0 } {
    append err "\n***Error - The following _BACK tables: \n\t[join $back_lst "\n\t"] are still on $to_db.\n"
    append err " Please drop them to insure an accurate difference report."
  }
  return $err
}
proc checkLogon.Oracle {connectionString} {
    if [catch {exec sqlplus -L $connectionString << {exit;}} err] {
        error "Cannot connect to database: $err"
    }
    if [catch {testOracleScriptLogon $connectionString} scriptLogonString] {
         error "Cannot run scripts from sh or bat files: $err"
    }
    if [catch {battyExecTest $scriptLogonString} sign] {
         error "Cannot run scripts from sh or bat files: $err"
    }
    return [list connectionString $connectionString scriptLogonString $scriptLogonString sign $sign]
}
# ##########
# @proc battyExecTest
# @test valid execution of bat files used to run sqlplus and scripts
# ##########
# @author BCP
# @param logstring - the database login string used for sqlplus
# @param here - directory to be used otherwise we default the WORKING_DIRECTORY
# @param signs - allows multiple exceptions to test
# @exception
# @see
# @return 0 for failure or the format of the "@" symbol (either @ or \\@)
# ##########
proc battyExecTest {scriptLogonString {dirname ""} {signs ""}} {
    if {$dirname == "" || ![file exists $dirname]} {set dirname [getInfo WORKING_DIRECTORY]}
    if {$signs == ""} {set signs [list "@" "\\@"]}
    set fileTypes [list bat sql lst]
    foreach fileType $fileTypes {
        if {[file exists "[file join $dirname battyExecTest.$fileType]"]} {
            file delete -force "[file join $dirname battyExecTest.$fileType]"
        }
    }
    set i 0
    while {[catch {set sql_file [open "[file join $dirname "battyExecTest.sql"]" w 77777]}]} {
        if {$i > 9} {
            error "ERROR: Could not open command file: battyExecTest.sql"
        }
        incr i
    }
    puts $sql_file "spool \"[file join $dirname battyExecTest.lst]\""
    puts $sql_file "select sysdate from dual;"
    puts $sql_file "exit"
    close $sql_file
    foreach sign $signs {
        catch {run_SQL_Script $scriptLogonString "battyExecTest.sql" "battyExecTest.bat" "$dirname" $sign} err
        if {$err != 0} {
            puts "Test execution failed: $err"
            set sign 0
        } else {
            break
        }
    }
    foreach fileType $fileTypes {
        if {[file exists "[file join $dirname battyExecTest.$fileType]"]} {
            file delete -force "[file join $dirname battyExecTest.$fileType]"
        }
    }
    if {$sign == 0} {
        error $err
    } else {
        return $sign
    }
}
# ##########
# @proc testOracleScriptLogon
# @test whether logon string has character that need to be escaped on command line
# ##########
# @author LAQ
# @param logstring - the database login string used for sqlplus
# @param here - directory to be used otherwise we default the PWD
# @exception failure on opening file is not handled
# @see
# @return scriptLogonString that works on command line
# ##########

proc testOracleScriptLogon {scriptLogonString} {
    set i 0
    set testScript "logontest$i.bat"
    set dirname [getInfo WORKING_DIRECTORY]
    set tcount 0
    while [ catch {set fid [open "[file join $dirname $testScript]" w 77777]
            puts $fid [getUnixHeader]
            puts $fid "echo exit | sqlplus -L $scriptLogonString"
            close $fid} err] {
        if {$tcount > 9} {
            putt "\nFAIL: could not write to the $testScript test file."
            putt $err;
            error "FAIL"
        }
        incr tcount
    }
    if [catch {exec [file join $dirname $testScript] > logontest$i.err} err] {
        # putt "\nCurrent logon string will FAIL when executed from a shell script."
        # putt "Attempting to escape special characters."
        incr i
        set testScript "logontest$i.bat"
        if {[string tolower $::tcl_platform(platform)] == "windows"} {
            regsub -all {([%])} $scriptLogonString "%\\1" scriptLogonString
            regsub -all {([>\|\^<&\(\)\=\,\;])} $scriptLogonString {^\1} scriptLogonString
        } else {
            regsub -all {([\$>\|\^<&\(\)])} $scriptLogonString {\\\1} scriptLogonString
        }
        set tcount 0
        while [ catch {set fid [open "[file join $dirname $testScript]" w 77777]
                puts $fid [getUnixHeader]
                puts $fid "echo exit | \"[getSQLPLUS]\" -L $scriptLogonString"
                close $fid} err] {
            if {$tcount > 9} {
                putt "\nFAIL: could not write to the $testScript test file."
                putt $err;
                error "FAIL"
            }
            incr tcount
        }
        if [catch {exec [file join $dirname $testScript] > logontest$i.err} err] {
            putt "FAIL: Cannot execute script to run sqlplus correctly."
            putt "See file scriptLogon$i.err for details."
            error "Cannot logon to schema via shell script execution with current username/ password.\n"
        } else {
            # putt "SUCCESS: work-around was found.\n"
        }
    }
    catch {
        foreach f [glob -nocomplain logontest*] {
            file delete -force $f
        }
    }
    return $scriptLogonString
}

# ##########
# @proc validateLOBTableSpace
# @test whether MAX2_LOB_TS exists
# ##########
# @author BCP
# @param dbh the database handle
# @return 1 if found, 0 if not
# ##########
proc validateLOBTableSpace {dbh} {
    set sql "SELECT count(*) into :objCount FROM user_tablespaces WHERE tablespace_name = 'MAX2_LOB_TS'
             or (select count(*) from shs_schema_history where shs_sql_script_name = 'LDSCreateTablespace.sql') > 0"
    catch {execsql use $dbh $sql} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    return $objCount
}

# ##########
# @proc validateCTXTableSpace
# @test whether MAX2_CTX_TS exists
# ##########
# @author BCP
# @param dbh the database handle
# @return 1 if found, 0 if not
# ##########
proc validateCTXTableSpace {dbh} {
    set sql "SELECT count(*) into :objCount FROM user_tablespaces WHERE tablespace_name = 'MAX2_CTX_TS'
              or (select count(*) from shs_schema_history where shs_sql_script_name = 'CTXCreateTablespace.sql') > 0"
    catch {execsql use $dbh $sql} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    return $objCount
}

# ##########
# @proc missingSchemaTrigs
# @used to report missing schema triggers and tables that do not have a record version column
# ##########
# @author BCP
# @param dbh the database handle
# @return 3 lists, missing triggers, tables on which missing triggers are to be based and tables without record version columns
# @exceptions if sql failure error
# ##########
proc missingSchemaTrigs {dbh} {
    set torNames [list]; # list of table names from the tor table.  It's probably best to use this proc after verification of the tor table has been done.
    set tablePrefix ""; # 3 character table prefix to be used checking for the record_version column in the table.
    set recVerTabLst [list]; # list of record version tables for comparison.
    set trigsLst [list]; # list of triggers that match our naming standard
    set trigsNotFndLst [list]; # list of triggers not found
    set trigsTblLst [list]; # list of tables for the triggers not found
    set noRecVerCol [list]; # list of tables without record version columns
    set trigName ""; # trigger name to search for
    # Get tor tables.  We are only going to check our tables since they should have triggers.
    set SQL_Statement "select TOR_TABLE_NAME into :torNames
                       from TOR_TABLE_ORDER
                       order by TOR_TABLE_NAME"
    catch {execsql use $dbh $SQL_Statement} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    # Get list of tables that have record version columns (these tables are in the tor table)
    set SQL_Statement "select TABLE_NAME into :recVerTabLst
                       from USER_TAB_COLUMNS
                       where column_name = substr(TABLE_NAME, 1, 4)||'RECORD_VERSION'
                       and table_name in (select tor_table_name from tor_table_order)
                       order by table_name"
    catch {execsql use $dbh $SQL_Statement} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    # Get list of triggers
    set SQL_Statement "select TRIGGER_NAME into :trigsLst from USER_TRIGGERS"
    catch {execsql use $dbh $SQL_Statement} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    # Now check for a trigger for each table entry as long as that table has a record_version column
    foreach torName $torNames {
        set recVerTabIndex [lsearch $recVerTabLst $torName]
        if {$recVerTabIndex < 0} {
            # build list of tables that do not have record version columns
            lappend noRecVerCol $torName
        } else {
            set trigName "[string range $torName 0 3]TGRB_U_01"
            if {[lsearch $trigsLst $trigName] < 0} {
                lappend trigsNotFndLst $trigName
                lappend trigsTblLst $torName
            }
        }
    }
    return [list $trigsNotFndLst $trigsTblLst $noRecVerCol]
}

# ##########
# @proc getTxtIndexInfo
# @used to get text index info
# ##########
# @author BCP
# @param dbh the database handle
# @param indexName - index name on which to query
# @return retVal - "$indName!!!$indTable!!!$indCol!!!$indItypName!!![string trim [lindex $indParms 0]]" or "0" if index not found
# @exceptions if sql failure error
# ##########
proc getTxtIndexInfo {dbh} {
    set sql "select
                ui.index_name,
                ui.table_name,
                uic.column_name,
                ui.ityp_name,
                ui.parameters
            into
                :indNameLst,
                :indTableLst,
                :indColLst,
                :indItypNameLst,
                :indParmsLst
            from
                user_indexes ui, user_ind_columns uic
            where
                ui.table_name = uic.table_name and
                ui.index_name = uic.index_name and
                ui.ityp_owner = 'CTXSYS'
                order by ui.index_name"
    catch {execsql use $dbh $sql} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    if {[llength $indNameLst] == 0} {
        set retVal 0
    } else {
        foreach indName $indNameLst indTable $indTableLst indCol $indColLst indItypName $indItypNameLst indParms $indParmsLst {
            regsub -all {[\n\s\t]+} $indParms " " indParms
            lappend retVal "$indName!!!$indTable!!!$indCol!!!$indItypName!!!$indParms"
        }
    }
    return $retVal
}

# ##########
# @proc getTrigInfo
# @used to get info for specified trigger
# ##########
# @author BCP
# @param dbh the database handle
# @param trigName the trigger for which to return information
# @return retVal - list of "$trigName!!!$trigType!!!$trigEvent!!!$trigTabName!!!$trigWhenClause!!!$trigDesc"
# @exceptions if sql failure error
# ##########
proc getTrigInfo {dbh} {
    # Get list of triggers
    set SQL_Statement "select
                        TRIGGER_NAME,
                        TRIGGER_TYPE,
                        TRIGGERING_EVENT,
                        TABLE_NAME,
                        WHEN_CLAUSE,
                        DESCRIPTION
                       into
                        :trigNameLst,
                        :trigTypeLst,
                        :trigEventLst,
                        :trigTabNameLst,
                        :trigWhenClauseLst,
                        :trigDescLst
                       from
                        USER_TRIGGERS
                        order by TRIGGER_NAME"
    catch {execsql use $dbh $SQL_Statement} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    if {[llength $trigNameLst] == 0} {
        set retVal 0
    } else {
        foreach trigName $trigNameLst trigType $trigTypeLst trigEvent $trigEventLst trigTabName $trigTabNameLst trigWhenClause $trigWhenClauseLst trigDesc $trigDescLst {
            regsub -all {[\n\s\t]+} $trigDesc " " trigDesc
            regsub -all {^[^\s]+} $trigDesc $trigName trigDesc
            lappend retVal [list $trigName $trigType $trigEvent $trigTabName $trigWhenClause $trigDesc]
        }
    }
    return $retVal
}

# ##########
# @proc createRecVerTrigs
# @used to generate create record version trigger blocks for insertion into sql file
# ##########
# @author BCP
# @param tableName - table name or list of table names on which to create the trigger(s)
# @return retVal - list of pl/sql blocks for creation of triggers.  The ouput does not supply anything other than trigger creation sql.  Wrapping needs to be done externally.
# ##########
proc createRecVerTrigs {tableName} {
    # create pl/sql block text for each table name supplied
    foreach item $tableName {
        set triggerName [string range $item 0 3]TGRB_U_01
        set columnName [string range $item 0 3]RECORD_VERSION
        lappend retVal "prompt Building Trigger $triggerName on $columnName;
CREATE OR REPLACE TRIGGER $triggerName
    BEFORE UPDATE ON $tableName FOR EACH ROW BEGIN
    IF(:new.$columnName >= 0) THEN :new.$columnName := :old.$columnName +1;
        ELSE :new.$columnName := :old.$columnName;
    END IF;
END;
/"
    }
    return $retVal
}

# ##########
# @proc getTxtIndexCreate
# @used to get text index creation information
# ##########
# @author BCP
# @param dbh the database handle
# @param indexName - index name on which to query
# @return index creation script in full
# @exceptions if sql failure error
# ##########
proc getTxtIndexCreate {dbh indexName} {
    set sql "select to_char(CTX_REPORT.create_index_script('$indexName')) into :idxCreation from dual"
    set sqlUser "select user into :userName from dual"
    catch {execsql use $dbh $sql} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    catch {execsql use $dbh $sqlUser} err
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    regsub -all "\"$userName\"\." $idxCreation "" idxCreation
    regsub -all -line -- {^\n} $idxCreation "" idxCreation
    return $idxCreation
}


# ##########
# @proc getUnixHeader
# @used to get text "\#!/usr/bin/env sh" if platform is unix based
# ##########
# @author BCP
# @return "\#!/usr/bin/env sh" if platform = unix
# ##########
proc getUnixHeader {} {
    set unixHeader "\#!/usr/bin/env sh"
    if {[string tolower $::tcl_platform(platform)] == "unix"} {
        return $unixHeader
    }
}

# ##########
# @proc GetOraDefTblSpace
# @used to get the Oracle default tablespace
# ##########
# @author BCP
# @param dbh the database handle
# @return tablespace name or blank "" if none found.
# ##########
proc GetOraDefTblSpace {dbh} {
    set defaultTblsp ""
    set sql "SELECT PROPERTY_VALUE into :defaultTblsp FROM DATABASE_PROPERTIES WHERE PROPERTY_NAME = 'DEFAULT_PERMANENT_TABLESPACE'"
    catch {execsql use $dbh $sql} err
    if {$err < 0} {puts "Unable to get default tablespace."}
    return $defaultTblsp
}

# ##########
# @proc GetOracleDefaultTablespace
# @Newer version used to get the Oracle default tablespace.  Uses runSQL and requires connection string rather than handle
# ##########
# @author BCP
# @param dbh the connection string handle
# @return tablespace name or blank "" if none found.
# ##########
proc GetOracleDefaultTablespace {dbh} {
    set defaultTblsp ""
    set colLst PROPERTY_VALUE
    set from_where "FROM DATABASE_PROPERTIES WHERE PROPERTY_NAME = 'DEFAULT_PERMANENT_TABLESPACE'"
    # runSQL {connectString type columnList from_where results {isolateColumnList ""}}
    catch {[runSQL $dbh DEFAULT_TABLESPACE $colLst $from_where defaultTblsp]} err
    if {$defaultTblsp == ""} {
        puts "Unable to get default tablespace."
        puts "$err"
        return -1
    }
    return $defaultTblsp
}

# ##########
# @proc GetLdsSize
# @used to get the size of the LDS table in MB.  Stats must be gathered on LDS for this to work.
# note, this does not require scriptLogonString,
# ##########
# @author BCP
# @param dbh the database handle
# @return size of LDS table in MB
# @exceptions if sql failure error
# ##########
proc GetLdsSize {dbh loginString} {
    set ldsSizeMB 0
    # gather statistics on the LDS table as they need to exist for the
    # sql to get the usage size for the lds table.
    putt "Gathering stats on LDS table..."
    if {$::tcl_platform(os) == "Windows NT"} {
        if {[catch {exec $::env(ComSpec) /c {echo exec dbms_stats.gather_table_stats(ownname=^>null,tabname=^>'lds_large_data_storage',estimate_percent=^>100,cascade=^>true);} | sqlplus $loginString} err]} {
            putt "Error gathering stats on LDS table.  Size info may be inaccurate.  $err"
        }
    } else {
        set command {
        exec dbms_stats.gather_table_stats(ownname=>null,tabname=>'lds_large_data_storage',estimate_percent=>100,cascade=>true);
        exit
        }
        if {[catch {exec sqlplus -s $loginString << $command} err]} {
            puts "Error gathering stats on LDS table.  Size info may be inaccurate.  $err"
        }
    }
    # get lds usage and return the value in ldsSizeMB
    set sql {select round(((blocks + empty_blocks + num_freelist_blocks) * (select block_size from user_tablespaces where tablespace_name =
           (select tablespace_name from user_tables where table_name = 'LDS_LARGE_DATA_STORAGE')))/(1024*1024)) into :ldsSizeMB
       from user_tables
      where table_name = 'LDS_LARGE_DATA_STORAGE'
    }
    putt "Getting LDS size info..."
    set err [execsql use $dbh $sql]
    if {!($err == 0 || $err == 100)} {
        puts [getinfo all]
        error "SQL failure."
    }
    return $ldsSizeMB
}


# ##########
# @proc GetLobTblspcSize
# @used to get the size of the LOB tablespace size in MB.
# ##########
# @author BCP
# @param dbh the database handle
# @return size of LOB tablespace in MB or returns a list consisting of [errorcode message]
# @exceptions if sql failure error
# ##########
proc GetLobTblspcSize {dbh} {
    set lobSizeMB 0
    set tblspcCount 0
    set scriptCount 0
    set autoExtensible 0

    set sql {select nvl(count(*),0) into :tblspcCount from user_tablespaces where tablespace_name = 'MAX2_LOB_TS'}
    execsql use $dbh $sql
    if {$tblspcCount > 0} {
        # find out if segment space management is set to auto
        set sql {select count(*) into :autoExtensible from dba_data_files where tablespace_name = 'MAX2_LOB_TS' and autoextensible = 'YES'}
        set err [execsql use $dbh $sql]
        if {!($err == 0 || $err == 100)} {
            puts [getinfo all]
            error "SQL failure."
        }
        if {$autoExtensible == 0} {
            # get LOB tablespace size and return the value in lobSizeMB
            set sql {select (df.TotalSpace - tu.TotalUsedSpace) into :lobSizeMB
                     from
                     (select round(sum(bytes)/(1024*1024)) TotalSpace
                     from dba_data_files
                     where tablespace_name = 'MAX2_LOB_TS') df,
                     (select round(sum(bytes)/(1024*1024)) TotalUsedSpace
                     from dba_segments
                     where tablespace_name = 'MAX2_LOB_TS') tu}
            putt "Getting MAX2_LOB_TS size info..."
            set err [execsql use $dbh $sql]
            if {!($err == 0 || $err == 100)} {
                puts [getinfo all]
                error "SQL failure."
            }
        } else {
            set sql {select (df.TotalSpace - tu.TotalUsedSpace) into :lobSizeMB
                     from
                     (select round(sum(maxbytes)/(1024*1024)) TotalSpace
                     from dba_data_files
                     where tablespace_name = 'MAX2_LOB_TS') df,
                     (select round(sum(bytes)/(1024*1024)) TotalUsedSpace
                     from dba_segments
                     where tablespace_name = 'MAX2_LOB_TS') tu}
            putt "Getting MAX2_LOB_TS size info..."
            set err [execsql use $dbh $sql]
            if {!($err == 0 || $err == 100)} {
                puts [getinfo all]
                error "SQL failure."
            }
        }
    } else {
        set sql {select nvl(count(*),0) into :scriptCount from shs_schema_history where shs_sql_script_name = 'LOBCreateTablespace.sql'}
        if {$scriptCount == 0} {
            return [list -1 "LDSCreateTablespace.sql has not been run and MAX2_LOB_TS does not exist."]
        } else {
            return [list 1 "LDSCreateTablespace.sql has been run but the MAX2_LOB_TS does not exist."]
        }
    }
    return $lobSizeMB
}
#==============================================================================#
#   Global Settings
#==============================================================================#

catch {setInfo WORKING_DIRECTORY       "[pwd]"}
catch {setInfo MODEL_FILES_DIRECTORY   "[file join [getInfo WORKING_DIRECTORY] Models]"}
catch {setInfo SCRIPT_FILES_DIRECTORY  "[file join [getInfo WORKING_DIRECTORY] Scripts]"}

updateInfo _common_utilities_loaded "true"
