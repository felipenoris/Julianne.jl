
# centos:7

yum -y update
yum -y install wget cmake git gcc
wget https://julialang.s3.amazonaws.com/bin/linux/x64/0.4/julia-0.4.6-linux-x86_64.tar.gz
tar xf julia-0.4.6-linux-x86_64.tar.gz
rm -f julia-0.4.6-linux-x86_64.tar.gz
./julia-2e358ce975/bin/julia -e 'Pkg.init(); Pkg.clone("https://github.com/felipenoris/Julianne.jl.git")'

curl -fsSL https://get.docker.com/ | sh
echo 'DOCKER_OPTS="--storage-opt dm.basesize=50G"' >> /etc/default/docker
