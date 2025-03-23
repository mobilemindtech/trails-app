package require TclOO

namespace import ::trails::controllers::Controller

namespace eval ::controllers {

    oo::class create PersonController {

	Controller {
	    scaffold true
	}

	constructor {} {
	    
	}

	# enter filter
	# method enter {req} {}

	# leave filter
	# method leave {req resp} {}

	# simple action
	# method stuff {} {
	#  render -text "hello, world"
	#}

	method say {} {}
    }

    namespace export PersonController
}

