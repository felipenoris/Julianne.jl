
using HttpServer

function start_webapp(ip=HOST.webapp_ip, port=HOST.webapp_port)
	http = HttpHandler() do req::Request, res::Response
		if !ismatch(r"^/julianne",req.resource)
			Response(404)
		else
			Response(report_html())
		end
	end

	server = Server(http)
	@async run(server, host=ip, port=port)
end

function report_html() # :: String
    tail = gettail()
    r = UTF8String("")
    r = r * """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset=\"UTF-8\">
        <meta name=\"description\" content=\"Julianne.jl status\">
    </head>
    <body>
    <h1>
        <a href=\"https://github.com/felipenoris/Julianne.jl\">Julianne</a> status
    </h1>
    
    <hr>
    <ul>
        <li> Current tail is: <b> $(tail.sha)-$(tail.subject) </b></li>
        <li> # of available workers: <b> $(length(HOST.workers)) </b></li>
    </ul>
    
    <p>
    """
    for c in HOST.commits
        r = r * "<br> $(sha_abbrev(c))-$(c.subject): <b> $(getstatus(c)) </b> \n"
        
        if isdone(c)
            failures, stvec = gettestedpkg(c, [:FAILED, :UNKNOWN])
            if !isempty(failures)
                for i in 1:length(failures)
                    pkg = failures[i]
                    st = stvec[i]
                    r = r * "<br>⎿ $(pkg.name) $(st)\n"
                end
            end
        end

        if istail(c)
            break
        end
    end
    r = r * """
    </p>
    </body>
    </html>
    """
    r
end
