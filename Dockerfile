#############################################
# Builder stage
#############################################
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# ALLE Build-Dependencies – EINMAL
RUN apt update && apt install -y --no-install-recommends \
    ca-certificates \
    \
    # Toolchain / Autotools
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    libtool-bin \
    pkg-config \
    m4 \
    gettext \
    flex \
    bison \
    \
    # Core audio
    libasound2-dev \
    libpulse-dev \
    libsndfile1-dev \
    \
    # AirPlay / Apple
    libplist-dev \
    libsodium-dev \
    libgcrypt-dev \
    uuid-dev \
    \
    # Avahi / Zeroconf
    libavahi-client-dev \
    libavahi-common-dev \
    libdaemon-dev \
    avahi-daemon \
    \
    # Codec / DSP
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libsoxr-dev \
    \
    # MQTT
    libmosquitto-dev \
    \
    # Config / parsing
    libconfig-dev \
    libpopt-dev \
    libpcre2-dev \
    \
    # SSL / crypto
    libssl-dev \
    \
    # Helfer
    jq \
    xxd \
 && rm -rf /var/lib/apt/lists/*

# nqptp
RUN git clone https://github.com/mikebrady/nqptp.git \
 && cd nqptp \
 && autoreconf -fi \
 && ./configure --without-systemd \
 && make \
 && make install

# shairport-sync
RUN git clone https://github.com/mikebrady/shairport-sync.git \
 && cd shairport-sync \
 && autoreconf -fi \
 && ./configure \
      --sysconfdir=/etc \
      --with-alsa \
      --with-mqtt-client \
      --with-avahi \
      --with-ssl=openssl \
      --with-soxr \
      --with-airplay-2 \
      --with-apple-alac \
 && make \
 && make install

#############################################
# Runtime stage
#############################################
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y --no-install-recommends \
    libasound2 \
    libavahi-client3 \
    libavcodec59 \
    libavformat59 \
    libavutil57 \
    libpulse0 \
    libsodium23 \
    libconfig9 \
    libpopt0 \
    libssl3 \
    libsoxr0 \
    libplist3 \
    libmosquitto1 \
    dbus \
 && rm -rf /var/lib/apt/lists/*

# Binaries & libs aus dem Builder
COPY --from=builder /usr/local/bin/shairport-sync /usr/local/bin/shairport-sync
COPY --from=builder /usr/local/bin/nqptp /usr/local/bin/nqptp

# Config & helper scripts
COPY shairport-sync.conf /etc/shairport-sync.conf
COPY apply-config.sh /apply-config.sh
COPY start-dbus.sh /start-dbus.sh

RUN chmod +x /apply-config.sh /start-dbus.sh

# Start:
# - dbus (für avahi)
# - nqptp (Timing für AirPlay 2)
# - shairport-sync
CMD ["/bin/sh", "-c", "/start-dbus.sh && nqptp & shairport-sync -c /etc/shairport-sync.conf"]
