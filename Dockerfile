#############################################
# Builder stage
#############################################
FROM debian:bullseye AS builder

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------------------------
# Build dependencies (bewusst vollständig)
# -------------------------------------------------
RUN apt update && apt install -y \
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
    # Audio / ALSA
    libasound2-dev \
    libsndfile1-dev \
    \
    # Avahi / mDNS
    libavahi-client-dev \
    libavahi-common-dev \
    libdaemon-dev \
    \
    # Crypto / Apple
    libplist-dev \
    libsodium-dev \
    libgcrypt-dev \
    uuid-dev \
    \
    # Codec / DSP (ffmpeg 4.x)
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libsoxr-dev \
    \
    # MQTT
    libmosquitto-dev \
    \
    # Config / CLI
    libconfig-dev \
    libpopt-dev \
    \
    # SSL (Bullseye!)
    libssl-dev \
    \
    # Helfer
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
# shairport-sync (ALSA + MQTT + Avahi + AirPlay 2)
# -------------------------------------------------
RUN git clone https://github.com/mikebrady/shairport-sync.git \
 && cd shairport-sync \
 && autoreconf -fi \
 && ./configure \
      --sysconfdir=/etc \
      --with-alsa \
      --with-avahi \
      --with-mdns=avahi \
      --with-airplay-2 \
      --with-mqtt-client \
      --with-ssl=openssl \
 && make \
 && make install
 
#############################################
# Runtime stage
#############################################
FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y --no-install-recommends \
    ca-certificates \
    libasound2 \
    libavahi-client3 \
    libdaemon0 \
    libavcodec58 \
    libavformat58 \
    libavutil56 \
    libsodium23 \
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
