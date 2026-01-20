#############################################
# Builder stage
#############################################
FROM debian:bullseye-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Build-Dependencies
RUN apt update && apt install -y --no-install-recommends \
    ca-certificates \
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
    # Audio (ALSA)
    libasound2-dev \
    libsndfile1-dev \
    \
    # Apple / Crypto
    libplist-dev \
    libsodium-dev \
    libgcrypt-dev \
    uuid-dev \
    \
    # Avahi / Zeroconf (DEV only)
    libavahi-client-dev \
    libavahi-common-dev \
    libavahi-compat-libdnssd-dev \
    libdaemon-dev \
    libevent-dev \
    \
    # Codec / DSP
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libsoxr-dev \
    \
    # MQTT
    libmosquitto-dev \
    libpcre2-dev \
    \
    # Config / Parsing
    libconfig-dev \
    libpopt-dev \
    \
    # SSL
    libssl-dev \
    \
    jq \
    xxd \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------
# nqptp (AirPlay 2 timing)
# -------------------------------------------------
RUN git clone https://github.com/mikebrady/nqptp.git \
 && cd nqptp \
 && autoreconf -fi \
 && ./configure --without-systemd --prefix=/usr/local \
 && make \
 && make install

# -------------------------------------------------
# shairport-sync (AirPlay 2 + MQTT + ALSA)
# -------------------------------------------------
RUN git clone https://github.com/mikebrady/shairport-sync.git \
 && cd shairport-sync \
 && autoreconf -fi \
 && ./configure \
      --sysconfdir=/etc \
      --with-alsa \
      --with-avahi \
      --with-airplay-2 \
      --with-ssl=openssl \
 && make \
 && make install
 
#############################################
# Runtime stage
#############################################
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y --no-install-recommends \
    libasound2 \
    libavahi-client3 \
    libdaemon0 \
    libavcodec \
    libavformat \
    libavutil \
    libsodium \
    libconfig9 \
    libpopt0 \
    libssl1.1 \
    libsoxr0 \
    libplist3 \
    libmosquitto1 \
    libsndfile1 \
    procps \
    dbus \
 && rm -rf /var/lib/apt/lists/*

# Binaries aus dem Builder
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
CMD ["/bin/sh", "-c", "/apply-config.sh && /start-dbus.sh && nqptp & shairport-sync -c /etc/shairport-sync.conf"]
