
# centos:7

yum -y update
yum -y install wget cmake
wget https://julialang.s3.amazonaws.com/bin/linux/x64/0.4/julia-0.4.6-linux-x86_64.tar.gz
tar xf julia-0.4.6-linux-x86_64.tar.gz
rm julia-0.4.6-linux-x86_64.tar.gz
./julia-2e358ce975/bin/julia -e 'Pkg.update() ; Pkg.clone("https://github.com/juliannebot/Julianne.jl.git")'

curl -fsSL https://get.docker.com/ | sh
echo 'DOCKER_OPTS="--storage-opt dm.basesize=50G"' >> /etc/default/docker
