
using HttpServer

function start_webapp(ip=HOST.webapp_ip, port=HOST.webapp_port)
	http = HttpHandler() do req::Request, res::Response
		if !ismatch(r"^/julianne",req.resource)
			Response(404)
		else
			Response(report_str())
		end
	end

	server = Server(http)
	@async run(server, host=ip, port=port)
end
