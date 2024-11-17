# rustzig

A docker environment for building static rust binaries for x86_64 and arm64 linux environments.

The goal is to simplify the creation of small and efficient cloud containers, or stand-alone linux binary releases.

This image includes zig compiler to enable use of zigbuild, an alternative compiler for cross platform compilation.

OpenSSL 3.4.0 and libgit2 is included. They are compiled with musl-gcc, enabling static builds when needed.

## Usage
```
docker pull xeonn/rustzig:1.80.0-alpine3.19
```