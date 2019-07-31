# tclUnitTests.tcl
set tclUnitTestsHome [file normalize [file dirname [info script]]]
catch {package require otc}
package require re

package     require re::reXML
package require SPM
package     require dom::tcl
package require re::tclgit
package require re::testFunctions
set ::TCLUNITTESTSCHEMALISTFILE ""
if {[info exists ::env(GIT_LOCAL)]} {
    source $::env(GIT_LOCAL)/localEnv/$::env(COMPUTERNAME)/local_env.tcl
} else {
    source /git_local/localEnv/$::env(COMPUTERNAME)/local_env.tcl
}
if [catch {array set env $env_vars}] {
    puts "need access to /git_local/localEnv/$::env(COMPUTERNAME)/local_env.tcl"
    exit
}
# to do: solidify appropriate value for this
global TCL_UNIT_TEST_WORKING_DIR
set ::TCL_UNIT_TEST_WORKING_DIR [pwd]
# todo is this functions.tcl the right location for the procs needed here?
source $tclUnitTestsHome/tclConversionTestUtilities.tcl
proc checkVersionMatch {version conditions versionNumber} {
    set testIt 0
    switch $conditions {
        eq {
            if {$version == $versionNumber} {
                set testIt 1
            }
        }
        ne {
            if {$version != $versionNumber} {
                set testIt 1
            }
        }
        gt {
            if {$version > $versionNumber} {
                set testIt 1
            }
        }
        ge {
            if {$version >= $versionNumber} {
                set testIt 1
            }
        }
        lt {
            if {$version < $versionNumber} {
                set testIt 1
            }
        }
        le {
            if {$version<= $versionNumber} {
                set testIt 1
            }
        }
        dc {
            set testIt 1
        }
        invalid {
            set testIt 0
        }
        default {
            set testIt -1
            puts "Invalid conditions $version $versionNumber $conditions"
        }
    }
    return $testIt
}
proc tclUnitTests  {dbCNode category testPattern version lastVersion testScript} {
    # due to differing implementations of xml/dom, these procedures may be in different namespaces,
    puts "ARGUMENTS:  $category $testPattern"

    file delete $::TCL_UNIT_TEST_WORKING_DIR/results_$category.out


    set configNodes  [p_getNodes $dbCNode "config"]
    set configVals ""
    foreach cnode $configNodes  {
        foreach tnode [node children $cnode] {
            lappend configVals [subst [node cget $tnode -nodeValue]]
        }
    }
    set currentVersion [join $version ""]
    set currentVersionDots [p_interpose $version "." 2]
    set currentShortVersion  [join [p_unpad_version $currentVersionDots] ""]
    regsub  -all {\.} $lastVersion "" lastVersion
    set lastVersionDots [p_interpose $lastVersion "." 2]
    set lastShortVersion  [join [p_unpad_version $lastVersionDots] ""]

    set testNodes [p_getNodes $dbCNode "tests/test"]

    # Here! Parse XML and Execute test for each version
    set testsRun ""
    foreach n $testNodes {
        set testName ""
        set testName [getAttributeValue $n "name"]
        if {[string match -nocase *$testPattern* $testName]} {
            set testIt 0
            set inputCount 0
            set testVer [p_getNodes $n "versions/version"]
            set sequence [getAttributeValue $n "sequence"]
            set type [getAttributeValue $n "type"]
            foreach vn $testVer {
                set versionNumber [getAttributeValue $vn "number"]
                set conditions [getAttributeValue $vn "condition"]
                set testIt [checkVersionMatch $currentVersion $conditions $versionNumber]
                if {$testIt == 1} {
                    if [catch {callingTest "$conditions" "$testName"  "$vn" "$category" $configVals "$currentVersion" $currentVersionDots $currentShortVersion $lastVersion $lastVersionDots $lastShortVersion $testScript} err] {
                        puts "Error running test $testName \n$err"
                    } else {
                        lappend testsRun [list $testName $sequence $type]
                    }
                } elseif {$testIt == -1} {
                    puts "testname? $testName"
                } else {
                   puts "SKIPPING $testName $version $conditions $versionNumber"
                }
            }
        }
    }
    return $testsRun
}

proc callingTest {conditions testName vn category configVals currentVersion currentVersionDots currentShortVersion lastVersion lastVersionDots lastShortVersion testScript} {
    set testInputFileName inputs_$category.tcl
    set filehandler [open $::TCL_UNIT_TEST_WORKING_DIR/$testInputFileName w]
    puts $filehandler "\# test name: $testName"
    puts $filehandler "source $category.tcl"
    puts $filehandler [join $configVals \n]
    puts $filehandler "set xmlVerNum $currentVersion"
    puts $filehandler "set condition $conditions"
    puts $filehandler "set TEST_HOME \"$::tclUnitTestsHome\""
    puts $filehandler "set TCL_UNIT_TEST_WORKING_DIR \"$::TCL_UNIT_TEST_WORKING_DIR\""
    set inputNodes [p_getNodes $vn "inputs/input"]
    set inputCount 0
    array set inputs ""
    set testDataDir $::tclUnitTestsHome/testdata
    foreach inode $inputNodes {
        set iname ""
        set iname [getAttributeValue $inode "name"]
        set tnodes  [node children $inode]
        set ival ""
        foreach tnode $tnodes {
            set ival [node cget $tnode -nodeValue]
        }
        puts $filehandler "set $iname \"[subst $ival]\""
        set inputs($iname) $ival
        incr inputCount
    }
    if {[info exists inputs(schemaConnections)]} {
        foreach schemaID $inputs(schemaConnections) {
            set schemaconnect ""
            set tVersion [subst $inputs($schemaID\_schemaVersion)]
            set tServer [subst $inputs($schemaID\_server)]
            if {$tVersion == "noConnection"} {
                set schemaconnect $tVersion/$tVersion@$tServer
            } else {
                set schemaconnect [getSchemaName [getSchemaListFile] $tVersion $tServer]
            }
            if {$schemaconnect != "" && $schemaconnect != -1} {
                puts $filehandler "set $schemaID $schemaconnect"
                incr inputCount
                set sn [lindex [split $schemaconnect "/"] 0]
                puts $filehandler "set $schemaID\_schemaName $sn"
                incr inputCount
            } else {
                error "Failed to create schema $tVersion $tServer"
            }
        }
    }
    puts $filehandler "set inputCount $inputCount"
    set outputCount 0
    set outputNodes [p_getNodes $vn "outputs/output"]

    # Loop for each verion tag output

    foreach onode $outputNodes {
        set oname ""
        set oname [getAttributeValue $onode "name"]
        set tnodes  [node children $onode]
        set oval ""

        foreach tnode $tnodes {
            set oval [node cget $tnode -nodeValue]
        }
        # substitue any dynamic variables such as currentVersion
        puts $filehandler "set $oname \"[subst $oval]\""
        incr outputCount
    }

    puts $filehandler "set outputCount $outputCount"
    # close $filehandler
    # puts "@@@@@@@@@@@@@@@@@@@@@@@@\n"
    # puts "tclsh tclConversionUnit.test -loadfile $testInputFileName -verbose spe -outfile results_$category.out -match $testName \n"
    # puts "@@@@@@@@@@@@@@@@@@@@@@@@ \n"
    # exit
    close $filehandler
    exec tclsh $testScript -loadfile $::TCL_UNIT_TEST_WORKING_DIR/$testInputFileName -verbose spe -outfile $::TCL_UNIT_TEST_WORKING_DIR/results_$category.out -match $testName
    if {$::errorInfo != ""} {
        puts "$::errorInfo"
    }
}
proc tut_cleanUpSchemas {schemaFile {server db09}} {
    if {[info exists ::env(DEBUG)] && ($::env(DEBUG) == "true" || $::env(DEBUG) == 1)} {
        puts "Please clean up the schemas found in $schemaFile when you have finished testing"
        return
    }
    array set schemaList "" 
    source $schemaFile
    foreach n [array names schemaList] {
        foreach schema [split $schemaList($n)] {
            setSchemaToBeDropped $schema $server
        }
    }
}
proc getSchemaListFile {} {
    if {$::TCLUNITTESTSCHEMALISTFILE == ""} {
        makeSchemaList
    }
    return $::TCLUNITTESTSCHEMALISTFILE
}
proc makeSchemaList {{fileName schemaList.txt}} {
    if {[info exists ::env(DEBUG)] && ($::env(DEBUG) == "true" || $::env(DEBUG) == 1)} {
        if {![file exists $::TCL_UNIT_TEST_WORKING_DIR/$fileName]} {
            set fp [open "$::TCL_UNIT_TEST_WORKING_DIR/$fileName" w]
            close $fp
        }
    } else {
        set fp [open "$::TCL_UNIT_TEST_WORKING_DIR/$fileName" w]
        close $fp
    }
    set ::TCLUNITTESTSCHEMALISTFILE $::TCL_UNIT_TEST_WORKING_DIR/$fileName
    return "$::TCL_UNIT_TEST_WORKING_DIR/$fileName"
}
proc cleanUpUnitTests {dir} {
    set here [pwd]
    cd $dir
    set ds [glob -types d *]
    set knownDirectories [list Auditing Models Packages Scripts]
    foreach d $ds {
        if {[lsearch $knownDirectories $d] < 0} {
            file delete -force $d
        }
    }
    foreach f [glob -nocomplain *.log] {
        file delete $f
    }
    foreach f [glob -nocomplain *.out] {
        file delete $f
    }
    foreach f [glob -nocomplain *.lst] {
        file delete $f
    }
    foreach f [glob -nocomplain *.bat] {
        file delete $f
    }
    foreach f [glob -nocomplain *.sql] {
        if {$f != "sy_load.sql"} {
            file delete $f
        }
    }
    foreach f [glob -nocomplain *.txt] {
        if {$f != "AutoConversion.txt"} {
            file delete $f
        }
    }
    cd $here
}
proc runUnitTests {db_conn tclUnitDataFile version svnRevision buildNumber testCategory patternMatch testScript {rel_uid ""} } {
    if {[info exists ::env(DEBUG)] && ($::env(DEBUG) == "true" || $::env(DEBUG) == 1)} {
        set postResults 0
    } else {
        set postResults 1
    }
    set lastVersion [join [p_pad_version [getLastVersion $db_conn $version]] ""]
    if {$postResults} {
        set ttrUID [postTestRun $db_conn "$rel_uid" $version "" $svnRevision $buildNumber "tcl_unit - $testCategory"]
    }
    set totalPasses 0
    set totalFails  0
    set totalSkips 0
    set here [pwd]
    set schemaListFile [makeSchemaList]
    cd $::tclUnitTestsHome/../DB_Scripts/Tools
    if {$testCategory == "*"} {
        set testCategory [fetchtestCategory $tclUnitDataFile]
    }
    set basedoc [p_setDocument $tclUnitDataFile]
    if {[info exists ::env(DEBUG)] && ($::env(DEBUG) == "true" || $::env(DEBUG) == 1)} {
        set postResults false
    }
    foreach cat $testCategory {
        if {$postResults} {
            p_writeTestsDescriptions $testScript $tclUnitDataFile $cat $db_conn "tcl_unit" "U"
        }
        puts "Running Unit tests for Category-\"$cat\" matching Pattern-\"$patternMatch\""
        set dbCNode [p_getFirstNodeWithName $basedoc /suite/category "$cat"]
        if {$dbCNode==""} {
            puts "null node at tclUnitTests looking for $cat"
            continue
        }
        if [catch {tclUnitTests $dbCNode $cat $patternMatch $version $lastVersion $testScript} testsRun] {
            puts "error: caught $testsRun \n$version\n$::errorInfo"
            continue
        }
        if {$testsRun != ""} {
            if {[file exists $::TCL_UNIT_TEST_WORKING_DIR/results_$cat.out]} {
                set results [p_parseResults2 $::TCL_UNIT_TEST_WORKING_DIR/results_$cat.out]
                set conts [lindex $results 0]
                set passes [lindex $results 1]
                set fails [lindex $results 2]
                set skips [lindex $results 3]
                if {$postResults} {
                    postTestResults2 $db_conn $ttrUID tcl_unit $cat $conts $testsRun
                }
                puts "posting results for $cat"
                puts "PASSED:  $passes"
                puts "FAILED:  $fails"
                puts "SKIPPED:  $skips"
                set totalPasses [expr $totalPasses + $passes]
                set totalFails [expr $totalFails + $fails]
                set totalSkips [expr $totalSkips + $skips]
            } else {
                puts "An error occurred and no test file matching results_$cat.out was generated"
                set passes -1
                set fails  -1
                set skips  -1
                set totalPasses [expr $totalPasses + $passes]
                set totalFails [expr $totalFails + $fails]
                set totalSkips [expr $totalSkips + $skips]
            }
        } else {
            puts "No tests were run for $cat"
            set passes 0
            set fails  0
            set skips  0
            set totalPasses [expr $totalPasses + $passes]
            set totalFails [expr $totalFails + $fails]
            set totalSkips [expr $totalSkips + $skips]
        }
    }
        tut_cleanUpSchemas $schemaListFile
        if {$postResults} {
            execsql use $db_conn "update TTR_TEST_RUN set
            TTR_PASSED = $totalPasses,
            TTR_FAILED = $totalFails,
            TTR_SKIPPED = $totalSkips,
            TTR_STOP_TIME = systimestamp
            where
            TTR_UID = $ttrUID"
            execsql use $db_conn "commit"
        }
        puts "Posting results for all categories"
        puts "Total PASSED:  $totalPasses"
        puts "Total FAILED:  $totalFails"
        puts "Total SKIPPED: $totalSkips"
        cd $here
        logoff $db_conn
        cleanUpUnitTests $::tclUnitTestsHome/../DB_Scripts/Tools
        return $totalFails
}
# MAIN
# runUnitTests.tcl datafile versiondotted category pattern
if {[info exists argv0] && [string toupper [file tail $argv0]] == "TCLUNITTESTS.TCL"} {
    # schema list for access to currently being used schemas
    # set debug for testing purposes
      # todo hard coded for now

    set connectionString "releng@cic-svr-db08"
    if {[set db_conn [getDbHandle $connectionString]] == "" } {
        puts "\nERROR: Not able to connect database: $connectionString\n"
        exit
    }
    # get input parameters 
    if {[lindex $argv 0] != ""} {
        # not implemented yet
        set version [lindex $argv 0]
    } else {
        set version $::env(CRVERSION)
    }
    set version [join [p_pad_version $version] ""]
    set tclUnitDataFile $tclUnitTestsHome/tclUnitData.xml
    # if {[lindex $argv 1] == ""} {
        # set tclUnitDataFile $tclUnitTestsHome/tclUnitData.xml
    # } else {
        # set tclUnitDataFile [lindex $argv 1]
    # }
    # if {[lindex $argv 2] == ""} {
        # set branch ""
    # } else {
         # set branch [lindex $argv 2]
    # }
    # set version [join [p_pad_version $version] ""]
    # puts $version
    # set sql "select VRI_GIT_DB_BRANCH, VRI_GIT_DB_REPO
    # into :dbbranch, :repo
    # from VRI_VERSION_RELEASE_INFO where VRI_VERSION = '$version' and VRI_PRD_ID = 'CR'"
    # execsql use $db_conn $sql
    # if {$branch == ""} {set branch $dbbranch}
    if {[lindex $argv 1] == "" || [lindex $argv 1] == "*"} {
        set testCategory [fetchtestCategory $tclUnitDataFile]
    } else {
         set testCategory [lindex $argv 1]
    }
    if {[lindex $argv 2] == ""} {
        set patternMatch "*"
    } else {
        set patternMatch [lindex $argv 2]
    }
    
    if {[info exists ::env(BUILD_NUMBER)]} {
        set buildNumber $::env(BUILD_NUMBER)
    } else {
        set buildNumber "MANUAL"
    }

    # if {[lindex $argv 5] == ""} {
        # set rel_uid  ""
    # } else {
        # set rel_uid [lindex $argv 5]
    # }

    # if {![info exists ::env(GIT_URL)] || $::env(GIT_URL) == ""} {
        # set git_url "$::env(GIT_PERSONAL_URL)"
    # } else {
        # set git_url $::env(GIT_URL)
    # }
    # if {![info exists ::env(USER_GIT_REVISION)]}  {
        # set gitRevision [git get-revision $git_url/$repo $branch]
    # } else {
        # set gitRevision "$::env(USER_GIT_REVISION)"
    # }
    set testScript $tclUnitTestsHome/tclConversionUnit.test
    set gitRevision ""
    set rel_uid 0
    # puts "$db_conn $tclUnitDataFile $version $svnRevision $buildNumber $testCategory $patternMatch"
    puts "$db_conn $tclUnitDataFile $version $gitRevision $buildNumber $testCategory $patternMatch $testScript"
    runUnitTests $db_conn $tclUnitDataFile $version $gitRevision $buildNumber $testCategory $patternMatch $testScript $rel_uid
    logoff $db_conn
}
