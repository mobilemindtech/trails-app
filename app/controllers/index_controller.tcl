package require TclOO

namespace import ::trails::controllers::Controller

namespace eval controllers  {
    catch {
	oo::class create IndexController { 
	    Controller {
		scaffold true
	    }
	}
    }

    oo::define IndexController {
	constructor {} {	
	    next	
	    #my variable service scaffold filters counter
	    #set service [DummyService new]	
	    #set scaffold true
	    my prop counter 0
	    puts "::? New IndexController"
	}
	
	#method enter {request} {
	#	$request prop body hello
	#	return $request
	#}

	method leave {request response} {
	    $response prop body "[$response prop body], world!"
	    return $response
	}

	#method recover {request err} {
	#	my render -body $err
	#}

	method dummy {request} {
	    Response new -status 200 -body [$request prop body]
	}

	method count {_} {
	    set counter [my propapply counter {it {expr $it + 1}}]
	    my prop other 2
	    my render -text "counter = $counter"
	}

	method index {req} {
	    puts "::> index"
	    my render \
		-model {x 1 y 2}
	    #-view /index \
	}

	#method index {request} {
	#	my variable indexService
	#	Response new -status 200 -body [$indexService foo]
	#}

	method custom {request} {
	    Response new -status 200 -body {custom action}
	}

	method xxx {request} {
	    my render -status 200 -body {xxx}
	}

	method x1 {request} {
	    return {200 x1 text/plain}
	}

	method x2 {request} {
	    return {text x2}
	}

	method x3 {request} {
	    return {json {[{"x": 3}]}}
	}

	method x4 {request} {
	    return {html {
		<html>
		<body>
		<h1>hello, trails!</h1>
		</body>
		</html>
	    }}
	}

	method data {request} {
	    my render -body [$request prop body] -content-type application/json
	}

	method tpl {request} {
	    my render -tpl-text {
		<html>
		<head>
		<title>Hello, TCL</title>
		</head>
		<body>
		Hello, {{name}}. You are {{age}} old?!
		</body>						
		</html>
	    } -ctx {name Ricaro age 37}
	}
    }


    namespace export IndexController
}


