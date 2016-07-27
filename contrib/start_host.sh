#!/bin/sh
nohup julia -e '(Pkg.update();using Julianne;Julianne.start())' &
