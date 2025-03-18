FROM hexpm/elixir:1.14.4-erlang-25.3-debian-bullseye-20230227-slim as build

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set environment variables
ENV MIX_ENV=prod \
    LANG=C.UTF-8

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy configuration files
COPY config config
COPY mix.exs mix.lock ./
COPY rel rel

# Install mix dependencies
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy assets
COPY assets assets
COPY priv priv

# Compile and build assets
RUN mix assets.deploy

# Copy application files
COPY lib lib

# Compile and build release
RUN mix compile
RUN mix release

# Prepare release image
FROM debian:bullseye-slim AS app

# Install runtime dependencies
RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/xiam ./

# Run as non-root user for better security
RUN useradd --create-home app
RUN chown -R app: /app
USER app

# Set runtime environment
ENV HOME=/app \
    PHX_SERVER=true

CMD ["/app/bin/xiam", "start"]
