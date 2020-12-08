ARG DATE
ARG REPO
ARG COMMIT

FROM qwofford/nvidia-cuda-devel:summit_2020-11-25 AS e4s_base

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


#RUN wget https://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_440.33.01_linux_ppc64le.run \
# && sh cuda_10.2.89_440.33.01_linux_ppc64le.run --silent --toolkit --override \
# && rm -f cuda_10.2.89_440.33.01_linux_ppc64le.run

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

# Copy specific workflow into pantheon home
COPY submodules/2020-08_miniapp-example/ /home/pantheon/2020-08_miniapp-example/

# Build the target application from source
RUN git clone https://github.com/ECP-WarpX/WarpX.git warpx \
 && pushd warpx \
 && git checkout ebde54faa8bcae2f1b37b81270a8d0a64bf58a98 \
 && popd \
 && git clone --branch QED https://bitbucket.org/berkeleylab/picsar.git \
 && git clone --branch development https://github.com/AMReX-Codes/amrex.git \
 && pushd warpx \
 && make -j 16 USE_GPU=TRUE && popd

CMD /bin/bash
ENTRYPOINT ["/entrypoint.sh"]

LABEL io.e4s.repo=${REPO}
LABEL io.e4s.commit=${COMMIT}
LABEL io.e4s.build-date=${DATE}
