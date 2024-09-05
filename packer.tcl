#!/bin/tclsh

package require yaml
package require http
package require tls
package require Tclx

#set cntrlc_flag 1

http::register https 443 [list ::tls::socket -autoservername true]


namespace eval packer {
    variable configs   
    set deps "./.tcl"
    #signal trap SIGINT packer::trap_ctrl_c
}


proc packer::trap_ctrl_c {} {
    puts stdout "Aborting current routine"
    packer::stop_all
    exit 0
}

 proc packer::uniqkey { } {
    set key   [ expr { pow(2,31) + [ clock clicks ] } ]
    set key   [ string range $key end-8 end-3 ]
    set key   [ clock seconds ]$key
    return $key
 }

 proc packer::sleep { ms } {
    set uniq [ packer::uniqkey ]
    set ::__sleep__tmp__$uniq 0
    after $ms set ::__sleep__tmp__$uniq 1
    vwait ::__sleep__tmp__$uniq
    unset ::__sleep__tmp__$uniq
 }

#
# clear console
#
proc packer::clear_term { } {
    puts "\x1B\x5B\x32\x4A\x1B\x5B\x30\x3B\x30\x48"
}

#
# get files checksum
#
proc packer::get_checksum {} {
    set dir ./
    set filter *.tcl
    set working_path [pwd]
    set cmd [list find -L $working_path/$dir -type f -name $filter -exec md5sum \{\} \;]
    exec {*}$cmd
}

#
# run app entrypoint, restart on change
#
proc packer::run {cmd} {
    set chsum1 ""
    set fd ""
    set pid "" 

    while {true} {
        set chsum2 [packer::get_checksum]
        if {$chsum1 ne $chsum2} {
            packer::clear_term
            puts "::> File change, restarting app.."
            set chsum1 $chsum2

            packer::kill $pid

            set pid [exec {*}$cmd &]
            puts "::> app started!"
            packer::sleep 1000
        }
    }    

}

#
# kill app by PID
#
proc packer::kill {pid} {
    if {$pid != ""} {
        puts "kill $pid"
        exec {*}[list kill $pid]
        puts "::> app stoped!"
        packer::sleep 300
    }    
}

#
# process app args
#
proc packer::main {argc argv} {
    
    variable deps 
    variable configs

    create_dir
    set configs [read_configs ]

    set param ""

    if {$argc > 0} {
        set param [lindex $argv 0]
    }

    switch $param {
        build {
            build
        }
        clean {
            if {[file exists $deps]} {
                file delete -force -- $deps
            }
        }
        init {
            init
        }
        run {
            run [dict get $configs app entrypoint]            
        }
        test {
            test $argc $argv
        }
        default {

            set cfg_cmds [dict get $configs commands]
            set cmds [list]

            dict for {k v} $cfg_cmds {

                set label $k
                set cmd $v
                set forever false

                if {[string match *.* $k]} {
                    set keys [split $k \.] 
                    if {[lsearch $keys forever] > -1} {
                        set keys [lrange $keys 0 end-1]
                    }
                    set label [join $keys " "]
                }

                lappend cmds [dict create label $label cmd $cmd forever $forever]
            }

            set labels {}

            foreach it $cmds {

                set label [dict get $it label] 
                set cmd [dict get $it cmd] 
                set forever [dict get $it forever]

                lappend labels $label

                if {$label == [join $argv " "]} {

                    puts "::> run $label -> $cmd \{forever=$forever\}"

                    if {$forever} {
                        run $cmd
                    } else {
                        exec {*}[list {*}$cmd | tee /dev/tty]
                    }
                    return
                }                
            }

            set labels [join $labels { | }]
            puts "::> usage \[init | build | clean | test | $labels\]"
            exit 1
        }
    }
}

# https://wuhrr.wordpress.com/2011/04/01/tcltest-part-3-include-and-exclude-tests/
proc packer::test {argc argv} {

    variable configs
    
    set params ""

    if {$argc > 1} {

        if {[lindex $argv 1] == "--help"} {
            puts "::> Test usage:"
            puts "::> configure -file patternList"
            puts "::> configure -notfile patternList"
            puts "::> configure -match patternList"
            puts "::> configure -skip patternList"
            puts "::> matchFiles patternList = shortcut for configure -file"
            puts "::> skipFiles patternList = shortcut for configure -notfile"
            puts "::> match patternList = shortcut for configure -match"
            puts "::> skip patternList = shortcut for configure -skip"
            puts "::> See more at https://wiki.tcl-lang.org/page/tcltest"
            return
        }

        set params [lrange $argv 1 end]
    }

    
    set testdir tests

    if {[dict exists $configs app testdir]} {
        set testdir [dict get $configs app testdir]
    }

    set cmd [list sh -c "tclsh $testdir/all.tcl -testdir $testdir $params | tee /dev/tty"]
    exec {*}$cmd
}

#
# init empty build.yaml
#
proc packer::init {} {
    set build_file "./build.yaml"

    if {[file exists $build_file]} {
        puts "::> build.yaml already exists"
    } else {

        set fd [open $build_file w+]
        puts $fd {app:}
        puts $fd {  name: My app name}
        puts $fd {  description: My app description}
        puts $fd {  entrypoint: ./main.tcl}
        puts $fd {}
        puts $fd {dependencies:}
        puts $fd {    # - https://github.com/user/tcp-app.git}
        puts $fd {    # - tcl-lib}
        puts $fd {}
        puts $fd {#tcl-lib:}
        puts $fd {#   uri: https://github.com/user/tcl-lib.git}
        puts $fd {#   cmds:}
        puts $fd {#     - cmd 1}
        puts $fd {#   imports:}
        puts $fd {#     - ::tcl::tm::path add [file normalize ./.tcl/tcl-lib/build/tcl/modules]}
        puts $fd {#     - lappend ::auto_path [file normalize ./.tcl/tcl-lib/build/tcl/packages]}
        puts $fd {}
        puts $fd {build:}
        puts $fd {    cmds:}
        puts $fd {        # - cmd 1}
        puts $fd {        # - cmd 1}
        
        close $fd
        puts "$build_file created!"
    }
}

#
# read app configs
#
proc packer::read_configs {} {
    set build_file "./build.yaml"
    set configs {}
    if {[file exists $build_file]} {        
        set fd [open $build_file]
        set configs [yaml::yaml2dict [read $fd]]
        close $fd  
        return $configs      
    }
    error "config $build_file file not found"
}

#
# run build
#
proc packer::build {} {

    variable deps
    variable configs

    set name [dict get $configs app name]
    set description [dict get $configs app description]
    set dependencies [dict get $configs dependencies]
    set require_packages [dict get $configs requirements packages]
    set require_cmds [dict get $configs requirements cmds]

    puts "::> check packages requirements"
    foreach pack $require_packages {        
        if {[catch {package require $pack} err]} {
            puts "::> \[x\] package $pack not found"
            return
        } else {
            puts "::> \[ok\] package $pack found"
        }
    }

    puts "::> check cmds requirements"
    foreach cmd $require_cmds {        
        if {[catch {exec {*}[list sh -c $cmd]} err]} {
            puts "::> \[x\] command $cmd not found"
            return
        } else {
            puts "::> \[ok\] command $cmd found"
        }
    }

    foreach dep $dependencies {

        if {[string match https://* $dep]} {
            packer::resolve_dependency_uri $dep
        } else {
            if {[dict exists $configs $dep]} {
                set dep_info [dict get $configs $dep]
                set uri [dict get $dep_info uri]
                set cmds [dict get $dep_info cmds]
                set imports [dict get $dep_info imports]

                set dirname [packer::get_url_dirname $uri]
                if {[file exists $deps/$dirname]} {
                    puts "::> dependency $dep already exists"
                } else {

                    packer::resolve_dependency_uri $uri

                    foreach cmd $cmds {
                        puts "::> run $cmd"
                        set cmd [list sh -c "cd $deps/$dirname && $cmd | tee /dev/tty"]
                        exec {*}$cmd
                    }

                    foreach import $imports {
                        packer::add_import $import
                    }
                }


            } else {
                error "dependency $dep not found"
            }
        }

    }

    if {[dict exists $configs build cmds]} {
        set cmds [dict get $configs build cmds]
        foreach cmd $cmds {
            puts "::> run $cmd"
            exec $cmd
        }
    }
}

#
# resove dependency uri
#
proc packer::resolve_dependency_uri {uri} {

	variable deps

    create_dir

	if {[string match *.tcl $uri]} {
		load_file_from_uri $deps $uri
	} elseif {[string match *github.com* $uri]} {
		load_lib_from_git $deps $uri
	}
}

#
# get dir name by url
#
proc packer::get_url_dirname {uri} {
    set dirname [lindex [split $uri /] end]
    lindex [split $dirname .] end-1    
}

#
# run git clone dependency
#
proc packer::load_lib_from_git {deps uri} {

	global auto_path


	set dirname [packer::get_url_dirname $uri]

	if {[file exists $deps/$dirname]} {
        puts "::> dependency $dirname already exists"
    } else {
        puts "::> git clone $uri"
		set cmd [list git clone $uri $deps/$dirname | tee /dev/tty]
		if {[catch {exec {*}$cmd} results options]} {

            set err [dict get $options -errorcode]

            if {$err ne "NONE"} {                
                if {[file exists $deps/$dirname]} {
                    file delete -force -- $deps/$dirname
                }
                error "git clone error: $err"
            }

        }
        packer::add_import "lappend ::auto_path $deps/$dirname" 
	}
    
    #puts "add autopath $deps/$dirname"
    lappend auto_path $deps/$dirname

}

#
# run download dependency file
#
proc packer::load_file_from_uri {deps uri} {
	set filename [lindex [split $uri /] end]
	set file_path $deps/$filename
	if {[file exists $file_path]} {
        puts "::> dependency $filename already exists"
    } else {
		puts "::> downloading file $uri.."
		set token [http::geturl $uri]
		set data [::http::data $token]
		::http::cleanup $token
		set fd [open $file_path w+]
		puts $fd $data
		close $fd

        packer::add_import "source $deps/$filename" 
	}
	
    #puts "use $deps/$filename"
    source $deps/$filename
}

#
# write import on deps.tcl
#
proc packer::add_import {import} {
    variable deps
    set fd [open $deps/deps.tcl a+]
    puts $fd $import
    close $fd    
}

#
# create deps dir
#
proc packer::create_dir {} {
    variable deps
    if {![file exists $deps]} {
        file mkdir $deps
    }    
}

proc packer::is_dict d {
    expr {[string is list $d]
        && !([llength $d] % 2)
        && ((2 * [llength [dict keys $d]]) == [llength $d])
    }
}

packer::main $argc $argv

