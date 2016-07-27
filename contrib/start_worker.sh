#!/bin/sh
nohup julia -e '(Pkg.update();using Julianne;Julianne.Worker.start("w1", ip"127.0.0.1", 8023))' &
