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

FROM e4s_base AS pantheon_base

ARG DATE
ARG REPO
ARG COMMIT

# Create a pantheon home
RUN mkdir /home/pantheon

# Make subsequent copies relative to pantheon home
WORKDIR /home/pantheon

# Install spack environment
COPY spack_env/nobuild.yaml spack_env/spack.yaml /home/pantheon/
RUN sed -i.bak -e '82,84d' /opt/spack/var/spack/repos/builtin/packages/ascent/package.py
RUN . /opt/spack/share/spack/setup-env.sh \
 && spack mirror add e4s_summit https://cache.e4s.io \
 && spack buildcache keys --trust --install \
 && spack --env . concretize \
 && spack --env . install

COPY entrypoint.sh /entrypoint.sh

CMD /bin/bash
ENTRYPOINT ["/entrypoint.sh"]

LABEL io.e4s.repo=${REPO}
LABEL io.e4s.commit=${COMMIT}
LABEL io.e4s.build-date=${DATE}
