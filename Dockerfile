# START:install-curl
# in Dockerfile

# END:install-curl

# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bookworm-20260824-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.18.4-erlang-27.2.4-debian-bookworm-20260824-slim
#
# ash-migration Phase 7 real fixes: the book's original 1.16.0/OTP 26.2.1
# fails a real Docker build once ash is a dep, in 2 real, sequential ways
# (each confirmed via a real docker build error, not guessed):
# 1. Ash.Type.Duration references Elixir's core Duration struct, added in
#    Elixir 1.17 ("Duration.__struct__/0 is undefined").
# 2. ex_money's optional json_polyfill dep is conditional on
#    Code.ensure_loaded?(:json) -- OTP's built-in :json module, added in
#    OTP 27. mix.lock was resolved on the host (OTP 28, has :json, so
#    json_polyfill was correctly NOT added as a dep), but the original
#    OTP 26.2.1 builder lacks :json, so `mix release` fails looking for an
#    app that was never fetched ("Could not find application
#    :json_polyfill"). Bumping OTP to 27.x (which also has :json) keeps the
#    builder and the resolved lock file consistent.
#
# k8s-fortune5-hardening pass real fixes:
# 1. ELIXIR_VERSION was pinned to 1.18.4 here but this repo's own
#    .tool-versions (asdf) pins `elixir 1.19.5-otp-27` / `erlang 27.2.4` --
#    the two had drifted. Corrected to match the real, asdf-pinned toolchain
#    this repo actually develops against, not a stale value left over from
#    an earlier book-derived Dockerfile revision.
# 2. The previously-pinned bullseye-20260803-slim base is Debian bullseye,
#    whose bullseye-security apt pool has genuinely decayed past
#    buildability -- confirmed via 4 real, reproducible `docker build` 404s
#    (perl, then libc-l10n) against the archive mirror, not a transient
#    blip. Moved to bookworm (Debian's current stable release, actively
#    maintained). Note: this repo's packer/ directory (HashiCorp Packer)
#    builds the EC2 Docker Swarm HOST AMI (amazon-linux-docker) -- a
#    different artifact from this app's own container image -- so it is
#    not an applicable substitute base here; Debian bookworm is the real
#    fix for this specific image.
#
# merge/main-2026-09-14 correction: origin/main had already moved this
# image to ELIXIR_VERSION=1.20.2/OTP_VERSION=28.5.0.2 under a comment
# claiming lockstep with .tool-versions. This branch's .tool-versions was
# actually the stale side (still pinned to 1.19.5-otp-27/27.2.4) -- fixed
# by updating .tool-versions to 1.20.2-otp-28/28.5.0.2 to match main's
# already-correct forward move, rather than reverting main's Dockerfile
# bump. Keeping main's newer Debian tag too.
ARG ELIXIR_VERSION=1.20.2
ARG OTP_VERSION=28.5.0.2
ARG DEBIAN_VERSION=bookworm-20260623-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

ENV ERL_FLAGS="+JPperf true"
WORKDIR /app

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential git curl ca-certificates clang libclang-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# ggen_igniter (hex) compiles its Rustler NIF native/ggen_graph_nif from source
# at `mix deps.compile` (`use Rustler`, no precompiled artifact): the builder
# needs cargo >= 1.87 (oxigraph/oxrocksdb-sys 0.5.11 rust-version) and libclang
# (oxrocksdb-sys runs bindgen). Without it: System.cmd("cargo", ...) :enoent.
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- -y --no-modify-path --profile minimal --default-toolchain 1.97.0 \
  && cargo --version

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

COPY VERSION mix.exs mix.lock ./
RUN mix deps.get --only ${MIX_ENV}

RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy
RUN mix compile --warnings-as-errors

COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
       ca-certificates curl libncurses5 libstdc++6 locales openssl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod

WORKDIR /app
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/xaas ./

USER nobody
CMD ["/app/bin/server"]
