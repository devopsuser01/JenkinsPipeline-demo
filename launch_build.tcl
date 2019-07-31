
package require http
if [catch {package require base64}] {
    if {![info exists g_RE_COMMON]} {
        set g_RE_COMMON /opt/www/doc/test_forms/common
    }
    source $g_RE_COMMON/packages/base64-2.4.2.tm
}

proc startJenkinsJob {user passwd jobPath params} {
    set url     "http://10.157.201.138:8080"
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
}
if {[info exists argv0] && [string toupper [file tail $argv0]] == "LAUNCH_BUILD.TCL"} {
    set user    reservice
    set passwd  6ab31e98924cf5086d36f0e8652bee32
    set build   [lindex $argv 0]
    set params [lrange $argv 1 end]
    catch {startJenkinsJob $user $passwd $build [join $params]} err
    puts $err
}

    
    
    
