package require TclOO

namespace import ::trails::services::Service

namespace eval ::services  {
    catch {
	oo::class create IndexService { 
	    superclass Service 
	}
    }

    namespace export IndexService
    
    oo::define IndexService {
	constructor {} {
	    next
	    my variable domain

	    set domain {
		table_name person
		fields {
		    id {{id_ int key} {json ID string}}
		    name {{name_ string} {json NAME string}}	
		}
	    }

	}
	method foo {} { 
	    return foo
	}
    }

    namespace export IndexService
}
