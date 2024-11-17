FROM --platform=$BUILDPLATFORM alpine AS build
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM" > /log

FROM rust:1.80.0-alpine3.19
COPY --from=build /log /log

# built in variable $BUILDPLATFORM $TARGETPLATFORM
# TARGETOS TARGETARCH

RUN rustup target add x86_64-unknown-linux-gnu && rustup target add x86_64-unknown-linux-musl

RUN apk update && apk upgrade && \
    apk add --no-cache pkgconfig musl-dev libgit2-dev binutils git perl alpine-sdk xz \
    linux-headers

# Install Zig from the official source
RUN wget https://ziglang.org/download/0.9.1/zig-linux-x86_64-0.9.1.tar.xz && \
    tar -xf zig-linux-x86_64-0.9.1.tar.xz && rm zig-linux-x86_64-0.9.1.tar.xz && \
    mv zig-linux-x86_64-0.9.1 /usr/local/zig && \
    ln -s /usr/local/zig/zig /usr/local/bin/zig && \
    mkdir -p /usr/include/x86_64-linux-musl && \
    ln -s /usr/include/asm-generic /usr/include/x86_64-linux-musl/asm-generic && \
    ln -s /usr/include/linux /usr/include/x86_64-linux-musl/linux && \
    mkdir /musl && \
    wget https://github.com/openssl/openssl/releases/download/openssl-3.4.0/openssl-3.4.0.tar.gz && \
    tar zxvf openssl-3.4.0.tar.gz && rm openssl-3.4.0.tar.gz && \
    cd openssl-3.4.0/ && \
    CC="gcc -fPIE -pie" ./Configure no-shared no-async --prefix=/musl --openssldir=/musl/ssl linux-x86_64 && \
    make depend && \
    make -j$(nproc) && \
    make install_sw clean

ENV PKG_CONFIG_ALLOW_CROSS=1 \
    OPENSSL_STATIC=true \
    OPENSSL_DIR=/musl

# Example usage

# COPY . /
# RUN cargo install --locked cargo-zigbuild && \
# cargo zigbuild --release --target=x86_64-unknown-linux-musl --bin app

## Deployment image
# FROM --platform=linux/amd64 alpine:3

# COPY --from=stage /target/x86_64-unknown-linux-musl/release/app /app

# EXPOSE 8080
# CMD /bin/sh -c "/app"