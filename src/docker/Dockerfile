FROM centos:7

MAINTAINER Julianne <juliannebot@gmail.com>

WORKDIR /root

ENV JULIA_PKGDIR /usr/local/julia/share/julia/site

RUN echo "export PATH=/usr/local/sbin:/usr/local/bin:${PATH}" >> /etc/profile.d/local-bin.sh \
	&& echo "export CPATH=/usr/include/glpk" >> /etc/profile.d/glpk-include.sh \
	&& source /etc/profile

RUN yum update -y && yum install -y epel-release && yum clean all

RUN yum update -y && yum install -y \
	bison \
	bzip2 \
	bzip2-devel \
	cmake \
	curl-devel \
	expat-devel \
	flex \
	gcc \
	gcc-c++ \
	gcc-gfortran \
	gettext-devel \
	glibc-devel \
	java-1.8.0-openjdk-devel \
	lynx \
	libcurl \ 
	libcurl-devel \
	libedit-devel libffi-devel \
	libgcc \
	m4 \
	make \
	man \
	nano \
	nload \
	htop \
	openssl \
	openssl098e \
	openssl-devel \
	patch \
	perl-ExtUtils-MakeMaker \
	svn \
	unzip \
	valgrind \
	sqlite \
	sqlite-devel \
	vim \
    wget \
	zlib \
	zlib-devel \
	zip \
    && yum clean all

# GIT
# http://tecadmin.net/install-git-2-0-on-centos-rhel-fedora/#
RUN wget https://www.kernel.org/pub/software/scm/git/git-2.9.2.tar.gz \
	&& tar xf git-2.9.2.tar.gz && cd git-2.9.2 \
	&& make -j"$(nproc --all)" prefix=/usr/local all \
	&& make prefix=/usr/local -j"$(nproc --all)" install \
	&& cd .. && rm -f git-2.9.2.tar.gz && rm -rf git-2.9.2

# Makes git use https by default
RUN git config --global url."https://".insteadOf git://

# llvm needs CMake 2.8.12.2 or higher
# https://cmake.org/download/
RUN wget https://cmake.org/files/v3.6/cmake-3.6.0.tar.gz \
	&& tar xf cmake-3.6.0.tar.gz && cd cmake-3.6.0 \
	&& ./bootstrap && make -j"$(nproc --all)" && make -j"$(nproc --all)" install \
	&& cd .. && rm -rf cmake-3.6.0 && rm -f cmake-3.6.0.tar.gz \
	&& echo "export CMAKE_ROOT=/usr/local/share/cmake-3.6" > /etc/profile.d/cmake-root.sh \
	&& source /etc/profile

# LLVM deps
RUN yum -y install libedit-devel libffi-devel swig python-devel

RUN git clone https://github.com/JuliaLang/julia.git

ADD julia-packages.jl julia-packages.jl

RUN cd julia && git pull

RUN cd julia && make -j"$(nproc --all)"

RUN ./julia/julia -e 'Pkg.init()'

RUN ./julia/julia -e 'include("julia-packages.jl")'

ADD TARGET TARGET

RUN cd julia && git pull && git checkout $(cat ../TARGET) && make clean && make -j"$(nproc --all)"

RUN ./julia/julia -e 'Pkg.update()'
