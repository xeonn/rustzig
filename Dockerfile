# Stage 1: Build stage with platform support
FROM --platform=$BUILDPLATFORM alpine AS build
ARG TARGETPLATFORM
ARG TARGETARCH
RUN echo "Building for $TARGETPLATFORM on $BUILDPLATFORM" > /log

# Stage 2: Build the Rust application with musl compilers
FROM --platform=$BUILDPLATFORM rust:1.82.0-alpine3.20 AS rust-build
ARG TARGETARCH

# Set the Rust target based on the architecture
RUN rustup target add x86_64-unknown-linux-musl && \
    rustup target add aarch64-unknown-linux-musl

WORKDIR /app

# Install dependencies for musl-based compilation
RUN apk update && apk add --no-cache \
    musl-dev linux-headers perl git xz wget bash make binutils

# Install musl-based cross-compilation toolchains
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    wget https://musl.cc/x86_64-linux-musl-cross.tgz && \
    tar -xzf x86_64-linux-musl-cross.tgz -C /usr/local && \
    rm x86_64-linux-musl-cross.tgz && \
    ln -s /usr/local/x86_64-linux-musl-cross/bin/* /usr/local/bin/; \
else \
    wget https://musl.cc/aarch64-linux-musl-cross.tgz && \
    tar -xzf aarch64-linux-musl-cross.tgz -C /usr/local && \
    rm aarch64-linux-musl-cross.tgz && \
    ln -s /usr/local/aarch64-linux-musl-cross/bin/* /usr/local/bin/; \
fi

# Install Zig for cross-compilation
RUN ARCH=$(echo $TARGETARCH | sed 's/amd64/x86_64/;s/arm64/aarch64/') && \
    wget https://ziglang.org/download/0.9.1/zig-linux-${ARCH}-0.9.1.tar.xz && \
    tar -xf zig-linux-${ARCH}-0.9.1.tar.xz && rm zig-linux-${ARCH}-0.9.1.tar.xz && \
    mv zig-linux-${ARCH}-0.9.1 /usr/local/zig && \
    ln -s /usr/local/zig/zig /usr/local/bin/zig

# Build OpenSSL using the musl toolchain
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

