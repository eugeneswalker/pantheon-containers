ARG DATE
ARG REPO
ARG COMMIT

FROM registry.access.redhat.com/ubi8/ubi:8.2 AS e4s_base

ARG DATE
ARG REPO
ARG COMMIT

RUN yum update -y \
 && yum install -y \
    git \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    cmake \
    patch \
    xz \
    bzip2 \
    findutils \
    which \
    automake \
    autoconf \
    make \
    m4 \
    unzip \
    vim \
    file \
    wget \
    curl \
    hostname \
    ncurses-devel \
    pciutils \
    iputils \
    python3-devel \
    procps \
    libtool \ 
    && yum clean all \
    && rm -rf /var/cache/yum/*

RUN ln -s `which python3` /usr/bin/python \
 && python -m pip install --upgrade pip setuptools wheel \
 && python -m pip install gnureadline boto3 pyyaml pytz minio requests popper \
 && rm -rf ~/.cache

ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

RUN git clone https://github.com/spack/spack.git /opt/spack \
 && pushd /opt/spack && git checkout 49512e2 && popd 


#RUN wget http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_440.33.01_linux.run \
# && sh cuda_10.2.89_440.33.01_linux.run --silent --toolkit --override \
# && rm -f cuda_10.2.89_440.33.01_linux.run

# Create a pantheon home
RUN mkdir /home/pantheon

# Make subsequent copies relative to pantheon home
WORKDIR /home/pantheon

# Install spack environment
COPY spack_env/nobuild.yaml spack_env/spack.yaml /home/pantheon/
# Update cmake package.py, Kitware recommends newer cmake for paraview, and 3.14 no longer breaks ascent
RUN sed -i.bak 's/cmake@3\.14.*"/cmake@3\.18\.2"/' /opt/spack/var/spack/repos/builtin/packages/ascent/package.py
RUN sed -i.bak 's/cmake@3\.14.*"/cmake@3\.18\.2"/' /opt/spack/var/spack/repos/builtin/packages/vtk-h/package.py
RUN . /opt/spack/share/spack/setup-env.sh \
 && spack mirror add e4s_summit https://cache.e4s.io \
 && spack buildcache keys --trust --install \
 && spack --env . concretize \
 && spack --env . install

# Paraview spack package isn't working on Summit at the moment. Use superbuild instead.
# Current cmake spack package isn't added to spack view. Force it.
RUN export PATH=$PATH:/opt/spack/opt/spack/linux-rhel8-power9le/gcc-8.3.1/cmake-3.18.2-sfv33nosvyj7752deettpx57b3reevwo/bin \
 && . /opt/spack/share/spack/setup-env.sh \
 && git clone --recursive https://gitlab.kitware.com/paraview/paraview-superbuild.git \
 && pushd paraview-superbuild \
 && git fetch \
 && git checkout v5.8.1 \
 && git submodule update \
 && popd && mkdir pv_build && pushd pv_build \
 && cmake -DENABLE_osmesa=ON -Dmesa_USE_SWR=OFF -DENABLE_python3=ON ../paraview-superbuild \
 && make -j && make install && popd

COPY entrypoint.sh /entrypoint.sh

CMD /bin/bash
ENTRYPOINT ["/entrypoint.sh"]

LABEL io.e4s.repo=${REPO}
LABEL io.e4s.commit=${COMMIT}
LABEL io.e4s.build-date=${DATE}
