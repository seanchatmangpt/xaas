# XaaS v26.8.21 release image.
# Runtime identity is kept in lockstep with .tool-versions and VERSION.
ARG ELIXIR_VERSION=1.20.2
ARG OTP_VERSION=28.5.0.2
ARG DEBIAN_VERSION=bookworm-20260623-slim

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

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/kanban ./

USER nobody
CMD ["/app/bin/server"]
