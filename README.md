# Node22 image with python and git
This Dockerfile is composed of multiple stages to build various tools from source, such as Git, jq, and Python, targeting different architectures (arm, x86, x64). It utilizes a multi-stage build process to keep the final image size small.

## Stages
### Git Builder Stage
- It starts with a debian:bookworm-slim image as a base for building Git.
- Environment variables are set to avoid interactive prompts and to specify the Git version.
- It installs the necessary dependencies for building Git using apt-get.
- Downloads the Git source code for the specified version and builds it from source.
- After Git is built and installed, it creates symbolic links for all Git commands to point to the Git binary. This reduces the size of the image as there's only one Git binary and the rest are just symlinks.
-  tarball of the Git installation directory is created for use in the final image.

### jq Builder Stage
- This stage builds jq, a lightweight and flexible command-line JSON processor.
- The same debian:bookworm-slimbase image is used.
- It installs build tools and dependencies needed to compile jq from the source.
- The jq source code is cloned from its official repository and checked out to the specified version.
- It then builds jq with all its dependencies statically linked.

### Python Builder Stage
- This stage builds Python from source.
- Again, debian:bookworm-slim is the base image.
- The necessary libraries and tools for building Python are installed via apt-get.
- Python source code for the specified version is downloaded and compiled with optimizations enabled.

### Final Image Creation
- The final image is based on node:21.0.0-bookworm-slim.
- It sets various environment variables for the Node ecosystem tools, such as pm2, node-gyp, and pnpm, along with their respective versions.
- It copies the previously built Git, Python, and jq binaries and libraries from their respective builder stages.
- Creates symlinks for Python to ensure python and python3 commands point to the newly installed version.
- Installs runtime dependencies including curl, wget, and other necessary libraries.
- Detects the architecture and installs pnpm, a fast, disk space-efficient package manager.
- Installs pm2 to manage Node.js applications and node-gyp to build native addons.
- Cleans up the apt cache and lists to reduce image size.
- The Dockerfile also sets environment variables for the pnpm home directory and adds it to the PATH.

## Usage instructions and tool information:

- Git: Installed from source; use for version control operations.
- jq: Installed from source; use for JSON processing from the command line.
- Python: Installed from source; available for running Python applications and scripts.
- Node.js: Included in the base node image; use for running JavaScript applications.
- pm2: Installed globally; use to manage Node.js applications.
- node-gyp: Installed globally; use to compile native addon modules for Node.js.
- pnpm: Installed globally; use as an efficient and fast package manager for Node.js applications.

- In summary, this Dockerfile builds the latest versions of Git, jq, and Python from source, tailored to the architecture of the build system. It then combines these with a Node.js environment, along with tools like pm2 and pnpm for application management and dependency management, respectively, into a final Docker image.

## Version-Overview


| Tool/Dependency      | Version                | Description                                            |
|----------------------|------------------------|--------------------------------------------------------|
| Git                  | 2.42.0                 | Version control system                                 |
| jq                   | 1.7                    | Lightweight and flexible JSON processor                |
| Python               | 3.12.0                 | Programming language                                   |
| Node.js              | 21.0.0 (from base)     | JavaScript runtime                                     |
| pm2                  | 5.3.0                  | Process manager for Node.js applications               |
| node-gyp             | 9.4.0                  | Tool for compiling native addon modules                |
| pnpm                 | 8.9.2                  | Fast, disk space-efficient package manager             |
| Debian Base          | bookworm-slim| Base OS for the builders and final image               |
| wget                 | (default)              | Network downloader                                     |
| make                 | (default)              | Build automation tool                                  |
| gcc                  | (default)              | GNU Compiler Collection                                |
| autoconf             | (default)              | Tool for configuring source code                       |
| libssl-dev           | (default)              | SSL development files, libraries                       |
| libcurl4-openssl-dev | (default)              | Development files for libcurl (OpenSSL)                |
| libexpat1-dev        | (default)              | XML parsing C library - development kit                |
| gettext              | (default)              | GNU Internationalization utilities                     |
| zlib1g-dev           | (default)              | Compression library - development                      |
| tar                  | (default)              | Utility for manipulating tar archives                  |
| build-essential      | (default)              | Informational list of build dependencies               |
| libffi-dev           | (default)              | Foreign Function Interface library                     |
| libgdbm-dev          | (default)              | GNU dbm database routines (development)                |
| libc6-dev            | (default)              | GNU C Library: Development Libraries                   |
| libbz2-dev           | (default)              | Bzip2 compression library - development                |
| libreadline-dev      | (default)              | GNU readline and history libraries                     |
| libsqlite3-dev       | (default)              | SQLite 3 development files                             |
| libncurses5-dev      | (default)              | Developer's libraries for ncurses                      |
| xz-utils             | (default)              | XZ-format compression utilities                        |
| tk-dev               | (default)              | Toolkit for TCL and X11 (development)                  |
| liblzma-dev          | (default)              | XZ-format compression library - dev                    |
| libgdbm-compat-dev   | (default)              | GNU dbm database routines (legacy support)             |
| curl                 | (default)              | Data transfer tool with URL syntax                     |
| ca-certificates      | (default)              | Common CA certificates                                 |
| fontconfig           | (default)              | Generic font configuration library                     |
| binutils             | (default)              | GNU assembler, linker and binary utilities             |
| dumb-init            | (default)              | Simple init system for containers                      |
| bash                 | (default)              | GNU Bourne Again SHell                                 |
| openssl              | (default)              | Secure Sockets Layer toolkit - cryptographic utility   |
| libc6                | (default)              | GNU C Library: Shared libraries                        |
| libcurl4             | (default)              | Easy-to-use client-side URL transfer library (OpenSSL) |
| libgcc-s1            | (default)              | GCC support library                                    |

Please note that the versions marked with (default) indicate that the Dockerfile does not explicitly set a version, thus the installed version would be the one available by default in the Debian bookworm repositories at the time of the image build.
