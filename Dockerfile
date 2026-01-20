#############################################
# Builder stage
#############################################
FROM debian:bullseye AS builder

ENV DEBIAN_FRONTEND=noninteractive

# -------- Build Dependencies (bewusst vollständig) --------
RUN apt update && apt install -y \
    ca-certificates \
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
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
    # Apple / Crypto
    libplist-dev \
    libsodium-dev \
    libgcrypt-dev \
    uuid-dev \
    \
    # Avahi / mDNS
    libavahi-client-dev \
    libavahi-common-dev \
    libdaemon-dev \
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
    # Config
    libconfig-dev \
    libpopt-dev \
    \
    # SSL (Pflicht!)
    libssl-dev \
    \
    jq \
    xxd \
 && rm -rf /var/lib/apt/lists/*

# -------- nqptp (AirPlay 2 Timing) --------
RUN git clone https://github.com/mikebrady/nqptp.git \
 && cd nqptp \
 && autoreconf -fi \
 && ./configure --prefix=/usr/local \
 && make \
 && make install

# -------- shairport-sync (ALSA ONLY) --------
RUN git clone https://github.com/mikebrady/shairport-sync.git \
 && cd shairport-sync \
 && autoreconf -fi \
 && ./configure \
      --sysconfdir=/etc \
      --with-alsa \
      --with-avahi \
      --with-airplay-2 \
      --with-ssl=openssl \
      --without-pulseaudio \
      --without-jack \
      --without-pipewire \
 && make \
 && make install

#############################################
# Runtime stage
#############################################
FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

# -------- Runtime Dependencies --------
RUN apt update && apt install -y \
    libasound2 \
    libavahi-client3 \
    libdaemon0 \
    libavcodec58 \
    libavformat58 \
    libavutil56 \
    libsoxr0 \
    libplist3 \
    libsodium23 \
    libconfig9 \
    libpopt0 \
    libssl1.1 \
    libmosquitto1 \
    libsndfile1 \
    dbus \
    procps \
 && rm -rf /var/lib/apt/lists/*

# -------- Binaries --------
COPY --from=builder /usr/local/bin/shairport-sync /usr/local/bin/shairport-sync
COPY --from=builder /usr/local/bin/nqptp /usr/local/bin/nqptp

# -------- Config & Scripts --------
COPY shairport-sync.conf /etc/shairport-sync.conf
COPY apply-config.sh /apply-config.sh
COPY start-dbus.sh /start-dbus.sh

RUN chmod +x /apply-config.sh /start-dbus.sh

# -------- Start --------
CMD ["/bin/sh", "-c", "/apply-config.sh && /start-dbus.sh && nqptp & shairport-sync -c /etc/shairport-sync.conf"]
