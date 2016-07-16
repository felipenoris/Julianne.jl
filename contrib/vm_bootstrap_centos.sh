
# centos:7

yum -y install epel-release
yum -y update
yum -y install bzip2 wget cmake git gcc gcc-c++ gcc-gfortran patch libcurl libcurl-devel libgcc m4 openssl openssl098e openssl-devel
wget https://julialang.s3.amazonaws.com/bin/linux/x64/0.4/julia-0.4.6-linux-x86_64.tar.gz
tar xf julia-0.4.6-linux-x86_64.tar.gz
rm -f julia-0.4.6-linux-x86_64.tar.gz
./julia-2e358ce975/bin/julia -e 'Pkg.init(); Pkg.clone("https://github.com/felipenoris/Julianne.jl.git")'

curl -fsSL https://get.docker.com/ | sh

# to start docker service
#/usr/bin/docker daemon --storage-opt dm.basesize=50G
