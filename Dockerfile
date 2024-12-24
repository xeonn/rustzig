# Stage 1: Build stage with platform support
FROM alpine:3.20 AS build
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETARCH
RUN echo "Building for $TARGETPLATFORM on $BUILDPLATFORM" > /log

# Stage 2: Build the Rust application with musl compilers
FROM --platform=$TARGETPLATFORM rust:1.82.0-alpine3.20 AS rust-build
ARG TARGETARCH
ARG TARGETPLATFORM

WORKDIR /app

# Install dependencies for musl-based compilation
RUN apk update && apk add --no-cache \
    musl-dev linux-headers perl git xz wget bash make binutils

# Install Zig for cross-compilation
RUN ARCH=$(echo $TARGETARCH | sed 's/amd64/x86_64/;s/arm64/aarch64/') && \
    wget https://musl.cc/${ARCH}-linux-musl-cross.tgz && \
    tar -xzf ${ARCH}-linux-musl-cross.tgz -C /usr/local && \
    rm ${ARCH}-linux-musl-cross.tgz && \
    ln -s /usr/local/${ARCH}-linux-musl-cross/bin/* /usr/local/bin/

RUN ARCH=$(echo $TARGETARCH | sed 's/amd64/x86_64/;s/arm64/aarch64/') && \
    wget https://ziglang.org/download/0.9.1/zig-linux-${ARCH}-0.9.1.tar.xz && \
    tar -xf zig-linux-${ARCH}-0.9.1.tar.xz && rm zig-linux-${ARCH}-0.9.1.tar.xz && \
    mv zig-linux-${ARCH}-0.9.1 /usr/local/zig && \
    rm zig-linux-${ARCH}-0.9.1.tar.xz && \
    ln -s /usr/local/zig/zig /usr/local/bin/zig

RUN rustup target add $(echo $TARGETARCH | sed 's/amd64/x86_64/;s/arm64/aarch64/')-unknown-linux-musl

# # Build OpenSSL using the musl toolchain
RUN wget https://github.com/openssl/openssl/releases/download/openssl-3.4.0/openssl-3.4.0.tar.gz && \
    tar zxvf openssl-3.4.0.tar.gz && rm openssl-3.4.0.tar.gz && \
    cd openssl-3.4.0/ && \
    mkdir /openssl && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        CC="x86_64-linux-musl-gcc -fPIE -pie" ./Configure no-shared no-async --prefix=/openssl --openssldir=/openssl linux-x86_64; \
    else \
        CC="aarch64-linux-musl-gcc -fPIE -pie" ./Configure no-shared no-async --prefix=/openssl --openssldir=/openssl linux-aarch64; \
    fi && \
    make depend && \
    make -j$(nproc) && \
    make install_sw && \
    cd .. && rm -rf openssl-3.4.0

# Set environment variables for musl-based builds
ENV OPENSSL_STATIC=true
ENV OPENSSL_DIR=/openssl
ENV PKG_CONFIG_ALLOW_CROSS=1
