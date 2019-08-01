#!/usr/bin/sh
# schemaDiff.sh
### JNB 8/30/11 ###
# The purpose of this script is to automate the workflow required to run the sysDataGen.tcl and dbCompare.tcl utilities
# and to produce a difference report highligting the changes a previous run
# Usage: sh schemaDiff.sh <config file name>
# Example: sh schemaDiff.sh config/sd_crdevel_CR161.cfg


##################
#Environment Setup
##################

get_config() {
    export config=$1
    HOME=`cygpath -ma $HOME` #FIXME: test for platform before setting this to a mixed path
    if [ -e $HOME/setEnv.sh ]
    then
       echo "Sourcing environment file: $HOME/setEnv.sh"
        cat $HOME/setEnv.sh
        . $HOME/setEnv.sh
    else
        echo "Environment setup file $HOME/setEnv.sh was not found!"
        exit 1
    fi

    if [ -z $config ]
    then
        echo "Usage: escrow.sh <config file name>"
        exit 1
    elif [ -e $config ]
        then
        echo "Running with configuration file: $config"
        cat $config
        . $config
    else
        echo "config file $config was not found!"
        exit 1
    fi
}

setup() {
    echo "svn info $SVN_REPO_URL/$1 | grep "Last Changed Rev: .*" | sed 's/Last Changed Rev: //g'"
    export SVN_PROD_REVISION=`svn info $SVN_REPO_URL/$1 | grep "Last Changed Rev: .*" | sed 's/Last Changed Rev: //g'`
    export SVN_RETOOLS_REVISION=`svn info $SVN_REPO_URL/$SVN_RETOOLS_DIR | grep "Last Changed Rev: .*" | sed 's/Last Changed Rev: //g'`

    export SVN_DDL_MODELFILES_REVISION=`svn info $SVN_REPO_URL/$1/DDL/ModelFiles | grep "Last Changed Rev: .*" | sed 's/Last Changed Rev: //g'`
    echo "svn info $SVN_REPO_URL/$1/DDL/Modelfiles | grep "Last Changed Rev: .*" | sed 's/Last Changed Rev: //g'"

    export SVN_DATA_MODELFILES_REVISION=`svn info $SVN_REPO_URL/$1/Data/ModelFiles | grep "Last Changed Rev: .*" | sed 's/Last Changed Rev: //g'`
    echo "svn info $SVN_REPO_URL/$1/Data/Modelfiles | grep "Last Changed Rev: .*" | sed 's/Last Changed Rev: //g'"

    echo "SVN_PROD_REVISION: $SVN_PROD_REVISION"
    echo "SVN_RETOOLS_REVISION: $SVN_RETOOLS_REVISION"
    echo "SVN_DDL_MODELFILES_REVISION: $SVN_DDL_MODELFILES_REVISION"
    echo "SVN_DATA_MODELFILES_REVISION: $SVN_DATA_MODELFILES_REVISION"

    export LOG_DIR=$RE_INTERNAL_DIR/reports/schemaDiff/${DB_USER}_${PRODUCT_VERSION}_${MODEL_VERSION}/$SVN_PROD_REVISION
    echo "LOG_DIR=$LOG_DIR"
    #FIXME: some issue with mkdir -p
    mkdir $RE_INTERNAL_DIR/reports/schemaDiff/${DB_USER}_${PRODUCT_VERSION}_${MODEL_VERSION}
    mkdir $LOG_DIR
    # dump environment to a file
    env > $LOG_DIR/env.log
}


#SVN: update and grab revision number
svn_update_retools() {
   # script is designed to grab the latest mod files and update them into a local sandbox
   pushd .
   cd $RETOOLS_DIR
   $SVN_UPDATE_CMD > $LOG_DIR/svn_update_retools.log
   popd
}

svn_checkout_modelfiles() {
   # script is designed to grab the latest mod files and update them into a local sandbox
   # $1 is the top-level directory of the product you wish to perform this function on
   mkdir -p $SVN_TMP_DIR
   $SVN_CHECKOUT_CMD $SVN_REPO_URL/$1/DDL/ModelFiles $SVN_TMP_DIR/$1/DDL/ModelFiles > $LOG_DIR/svn_checkout_ddl.log
   $SVN_CHECKOUT_CMD $SVN_REPO_URL/$1/Data/ModelFiles $SVN_TMP_DIR/$1/Data/ModelFiles > $LOG_DIR/svn_checkout_data.log
   # copy files together under $MODEL_VERSION
   mkdir -p $SVN_TMP_DIR/$1/$MODEL_VERSION 
   cp $SVN_TMP_DIR/$1/Data/ModelFiles/* $SVN_TMP_DIR/$1/$MODEL_VERSION # I'm  not sure if this is correct.
   cp $SVN_TMP_DIR/$1/DDL/ModelFiles/* $SVN_TMP_DIR/$1/$MODEL_VERSION
}

#### dbCompare.tcl
call_dbcompare() {
    local TCL_SCRIPT=schema/dbCompare # referenced as a path from $RETOOLS_DIR
    local LOG_NAME=dbCompare.log

    echo "mtclsh $RETOOLS_DIR/${TCL_SCRIPT}.tcl $LOCAL_MODEL_DIR $DB_USER/$DB_PASS@$DB_SERVER $LOG_DIR/$LOG_NAME SILENT"
    mtclsh $RETOOLS_DIR/${TCL_SCRIPT}.tcl $LOCAL_MODEL_DIR $DB_USER/$DB_PASS@$DB_SERVER $LOG_DIR/$LOG_NAME SILENT > $LOG_DIR/schemaDiff_dbCompare.log 2>&1
    RETCODE=$?
    if [ $RETCODE -eq 0 ]
    then
        dbCompare_result="SUCCESS"
        tail -6 $LOG_DIR/$LOG_NAME
    else
        dbCompare_result="FAILURE"
        dbCompare_message=`tail -10 $LOG_DIR/schemaDiff_dbCompare.log`
    fi
    echo "${TCL_SCRIPT}.tcl $dbCompare_result $dbCompare_message"
}

#TODO: add a differ that gives us a metric on the delta from this run to a prior run (hmm. maybe add a date to top-level directory

#### SysDataGen.tcl
call_sysdatagen() {
    local TCL_SCRIPT=load_n_compare/SysDataGen
    local LOG_NAME="" # we don't need a logname for this a s the script handles it for us. See if this works, so we can use the same command line as for dbCompare.

    echo "mtclsh $RETOOLS_DIR/${TCL_SCRIPT}.tcl $LOCAL_MODEL_DIR $DB_USER/$DB_PASS@$DB_SERVER $LOG_DIR/$LOG_NAME SILENT"
    mtclsh $RETOOLS_DIR/${TCL_SCRIPT}.tcl $LOCAL_MODEL_DIR $DB_USER/$DB_PASS@$DB_SERVER $LOG_DIR/$LOG_NAME SILENT  > $LOG_DIR/schemaDiff_SysDataGen.log 2>&1
    RETCODE=$?
    if [ $RETCODE -eq 0 ]
    then
        sysDataGen_result="SUCCESS"
    else
        sysDataGen_result="FAILURE"
        sysDataGen_message=`tail -10 $LOG_DIR/schemaDiff_SysDataGen.log`
        tail -10 $LOG_DIR/schemaDiff_SysDataGen.log
    fi
    echo "${TCL_SCRIPT}.tcl $sysDataGen_result $SysDataGen_message"
}

call_ddlgen() {
    export TCL_SCRIPT=schema/DDLgen
    # mtclsh $RETOOLS_DIR/${TCL_SCRIPT}.tcl $LOG_DIR/dbCompare.log $MODEL_VERSION $SVN_TMP_DIR/$1/$MODEL_VERSION/ FIXME
    echo "FIXME: call to DDLgen.tcl"
}

# generate some summary files.
report() {
    sysDataDiffLog=`basename $LOG_DIR/sysDataDiff*`
    sysDataUpdateLog=`basename $LOG_DIR/sysDataUpdate*`
    nonSysRowsLog=`basename $LOG_DIR/nonSysRows*`
    # grep for "ERROR" in output files 
    grep --text -C 5 "SQL ERROR" $LOG_DIR/* > $LOG_DIR/ERRORS.txt
    if [ -s $LOG_DIR/ERRORS.txt ] 
    then
        echo "SQL ERRORS were found"
        cat $LOG_DIR/ERRORS.txt
    else
        echo "No sql errors were found"
    fi

    # check system data diffs
    grep --text  "SYSTEM DATA CHANGES" $LOG_DIR/$sysDataDiffLog > $LOG_DIR/SYS_DATA_DIFFS.txt
    if [ -s $LOG_DIR/SYS_DATA_DIFFS.txt ]
    then
        echo "Data diffs were found"
        cat $LOG_DIR/SYS_DATA_DIFFS.txt
    else
        echo "No data diffs were found"
    fi

    # check schema diffs in dbCompare.log
    grep --text "[^0] system schema" $LOG_DIR/dbCompare.log >> $LOG_DIR/SCHEMA_DIFFS.txt
    grep --text "[^0] disabled constraints" $LOG_DIR/dbCompare.log >> $LOG_DIR/SCHEMA_DIFFS.txt
    grep --text "[^0] non validated" $LOG_DIR/dbCompare.log >> $LOG_DIR/SCHEMA_DIFFS.txt
    if [ -s $LOG_DIR/SCHEMA_DIFFS.txt ]
    then
        echo "System schema diffs were found"
        cat $LOG_DIR/SCHEMA_DIFFS.txt
    else
        echo "No sytem schema diffs were found"
    fi
}

# Generate a diff report vs. prior run
run_diff() {
    dir_list=`\ls $LOG_DIR/.. | grep ^[0-9][0-9][0-9][0-9][0-9] | sort -r | head -2 | awk '{ ORS=" "; print $1; }'`
    set -- $dir_list
    latest_dir=$1
    prior_dir=$2
    diffPattern="^.* [0-9][0-9], [0-9][0-9][0-9][0-9].*$" # match dates like: September 12, 2011
    diffPattern4="^.* [0-9][0-9]-[A-Z][a-z][a-z]-[0-9][0-9][0-9][0-9].*$" # match dates like: 12-Sep-2011
    diffPattern3="^.*Run Time was.*$"
    diffPattern2="^.*[A-Z][a-z][a-z][a-z][a-z]es_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].*$"
    DIFF_CMD="diff -I '$diffPattern' -I '$diffPattern3' -I '$diffPattern4'"
    DIFF_LOG=$LOG_DIR/../diff_${latest_dir}_${prior_dir}.log
    mv $LOG_DIR/../diff_${latest_dir}_${prior_dir}.txt $LOG_DIR/../diff_${latest_dir}_${prior_dir}.old

    echo -e "diff $LOG_DIR/dbCompare.log $LOG_DIR/../$prior_dir/dbCompare.log\r\n" > $DIFF_LOG
    diff -I "$diffPattern" -I "$diffPattern3" -I "$diffPattern4" $LOG_DIR/dbCompare.log $LOG_DIR/../$prior_dir/dbCompare.log >> $DIFF_LOG

    #echo "$DIFF_CMD $LOG_DIR/env.log $LOG_DIR/../$prior_dir/env.log"\n >> $DIFF_LOG
    #diff -I "$diffPattern" $LOG_DIR/env.log $LOG_DIR/../$prior_dir/env.log >> $DIFF_LOG

    echo -e "diff $LOG_DIR/$nonSysRowsLog $LOG_DIR/../$prior_dir/nonSysRows_*.sql\r\n" >> $DIFF_LOG
    diff -I "$diffPattern" -I "$diffPattern2" -I "$diffPattern3" $LOG_DIR/$nonSysRowsLog $LOG_DIR/../$prior_dir/nonSysRows_*.sql >> $DIFF_LOG

    echo -e "diff $LOG_DIR/$sysDataDiffLog $LOG_DIR/../$prior_dir/sysDataDiff_*.txt\r\n" >> $DIFF_LOG
    diff -I "$diffPattern" -I "$diffPattern2" -I "$diffPattern3" $LOG_DIR/$sysDataDiffLog $LOG_DIR/../$prior_dir/sysDataDiff_*.txt >> $DIFF_LOG

    echo -e "diff $LOG_DIR/$sysDataUpdateLog $LOG_DIR/../$prior_dir/sysDataUpdate_*.sql\r\n" >> $DIFF_LOG
    diff -I "$diffPattern" -I "$diffPattern2" -I "$diffPattern3" $LOG_DIR/$sysDataUpdateLog $LOG_DIR/../$prior_dir/sysDataUpdate_*.sql >> $DIFF_LOG
    diffLog=`basename $DIFF_LOG`
}

send_email() {
    priorDateStr=`date -r $LOG_DIR/../$prior_dir "+%D %X"`
    dateStr=`date "+%D %X"`
    SUBJECT="schemaDiff run for $DB_USER@$DB_SERVER using $PRODUCT_VERSION $MODEL_VERSION $SVN_PROD_REVISION"
    FROM="Release Engineering <JNB@landacorp.com>"
    EMAILMESSAGE="/tmp/emailmessage.txt"
#NOTE: here-doc may not be indented
(
cat <<EOF
<html>
<body>

<h3>---This schema difference report was generated by $FROM---</h3>

<li>Schema: $DB_USER@$DB_SERVER</li>
<li>Model File Version: $MODEL_VERSION</li>
<li>Run Date: $dateStr</li>
<li>Last Run Date: $priorDateStr</li>

<h4>Difference report for this run with revision $latest_dir versus prior revision $prior_dir</h4>
<li><a href="$DIFF_LOG">$diffLog</a></li>

<h4>dbCompare.tcl: compare target DB structure vs model</h4>
Result: $dbCompare_result
<br/>$dbCompare_message
<br/>Log Directory:
<br/><a href="$LOG_DIR">$LOG_DIR/</a>
<br/>
<li><a href="$LOG_DIR/dbCompare.log">dbCompare.log</a></li>
<li><a href="$LOG_DIR/schemaDiff_dbCompare.log">schemaDiff_dbCompare.log</a> - Script stdout</li>

<br/><h4>SysDataGen.tcl: compare target DB system data vs model</h4>
Result: $sysDataGen_result 
<br/>$sysDataGen_message
<br/>Log Directory:
<br/><a href="$LOG_DIR">$LOG_DIR/</a>
<br/>
<li><a href="$LOG_DIR/$sysDataDiffLog">$sysDataDiffLog</a></li>
<li><a href="$LOG_DIR/$sysDataUpdateLog">$sysDataUpdateLog</a></li>
<li><a href="$LOG_DIR/$nonSysRowsLog">$nonSysRowsLog</a></li>
<li><a href="$LOG_DIR/schemaDiff_SysDataGen.log">schemaDiff_sysDataGen.log</a> - Script stdout</li>

<h4>Revision Information</h4>
<li>$SVN_REPO_URL/$PRODUCT_DIR Revision: $SVN_PROD_REVISION</li>
<li>$SVN_REPO_URL/$SVN_RETOOLS_DIR Revision: $SVN_RETOOLS_REVISION</li>
<li>$SVN_REPO_URL/$PRODUCT_DIR/DDL/ModelFiles Revision: $SVN_DDL_MODELFILES_REVISION</li>
<li>$SVN_REPO_URL/$PRODUCT_DIR/Data/ModelFiles Revision: $SVN_DATA_MODELFILES_REVISION</li>

<h4>Configuration File</h4>
<li>$config</li>
</body>
</head>

EOF
) > $EMAILMESSAGE
    header0="From: $FROM"
    header1="Mime-Version: 1.0;"
    header2="Content-Type: text/html; charset=ISO-8859-1;"
    header3="Content-Transfer-Encoding: 7bit;"
    echo 'mailx -s "$SUBJECT" -a "$header0" -a "$header1" -a "$header2" -a "$header3" "$MAILTO" < $EMAILMESSAGE #mail compliant version for use on unix systems'
    /usr/local/bin/mailx -s "$SUBJECT" -a "$header0" -a "$header1" -a "$header2" -a "$header3" "$MAILTO" < $EMAILMESSAGE #mail compliant version for use on unix systems
}

#############
# Do the work
#############
 
get_config $1
setup $PRODUCT_DIR
svn_update_retools
svn_checkout_modelfiles $PRODUCT_DIR
call_dbcompare
call_sysdatagen
report
run_diff
send_email
