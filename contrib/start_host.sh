#!/bin/sh
nohup julia -e '(Pkg.update();using Julianne;Julianne.start(ip"127.0.0.1",8023))' &
