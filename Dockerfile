FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VERILATOR_VERSION=5.020

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    python3 \
    python3-pip \
    python3-venv \
    autoconf \
    flex \
    bison \
    libfl2 \
    libfl-dev \
    zlib1g \
    zlib1g-dev \
    help2man \
    perl \
    wget \
    curl \
    gtkwave \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/verilator/verilator.git /opt/verilator-src \
    && cd /opt/verilator-src \
    && git checkout v${VERILATOR_VERSION} \
    && autoconf \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && rm -rf /opt/verilator-src

RUN pip3 install --no-cache-dir \
    cocotb==1.8.1 \
    pytest \
    numpy

WORKDIR /workspace

COPY . /workspace

CMD ["bash"]
