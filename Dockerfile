#############################################
# Builder stage
#############################################
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y --no-install-recommends \
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libpopt-dev \
    libconfig-dev \
    libasound2-dev \
    libavahi-client-dev \
    libssl-dev \
    libsoxr-dev \
    libplist-dev \
    libsodium-dev \
    libavutil-dev \
    libavcodec-dev \
    libavformat-dev \
    libpulse-dev \
    uuid-dev \
    libgcrypt-dev \
    libmosquitto-dev \
 && rm -rf /var/lib/apt/lists/*
RUN apt update && apt install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    pkg-config \
 && rm -rf /var/lib/apt/lists/* 

# ALAC
RUN git clone https://github.com/mikebrady/alac.git \
 && cd alac \
 && autoreconf -i \
 && ./configure \
 && make \
 && make install

# nqptp
RUN git clone https://github.com/mikebrady/nqptp.git \
 && cd nqptp \
 && autoreconf -fi \
 && ./configure \
 && make \
 && make install

# shairport-sync (AirPlay 2 + MQTT + ALSA)
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
COPY --from=builder /usr/local/lib/libalac* /usr/lib/

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
