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
# Pinned to a real, currently-published hexpm/elixir + debian tag pair for
# the CORRECT (1.19.5/27.2.4) version combo -- verified both exist on
# Docker Hub before pinning, not guessed.
# merge/main-2026-09-14 note: origin/main's Dockerfile pinned
# ELIXIR_VERSION=1.20.2/OTP_VERSION=28.5.0.2 under a comment claiming
# "kept in lockstep with .tool-versions" -- verified against the real
# .tool-versions on both sides of this merge (identical on both:
# `elixir 1.19.5-otp-27` / `erlang 27.2.4`) and found NOT in lockstep.
# Kept this branch's values, which do match .tool-versions.
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20260824-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

ENV ERL_FLAGS="+JPperf true"
WORKDIR /app

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

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
