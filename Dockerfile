#############################################
# Builder stage
#############################################
FROM debian:bullseye AS builder

ENV DEBIAN_FRONTEND=noninteractive

# --- Build-Dependencies (ALLES was gebraucht wird) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    # Required tools
    xxd \
    \
    # pthread / basics
    libc6-dev \
    \
    # ALSA
    libasound2-dev \
    libsndfile1-dev \
    \
    # Avahi / mDNS
    libavahi-client-dev \
    libavahi-common-dev \
    libdaemon-dev \
    avahi-daemon \
    \
    # Crypto / Apple
    libplist-dev \
    libsodium-dev \
    libgcrypt-dev \
    uuid-dev \
    \
    # DSP / Codec
    libsoxr-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    \
    # MQTT
    libmosquitto-dev \
    libpcre2-dev \
    \
    # Config
    libconfig-dev \
    libpopt-dev \
    \
    # SSL (REQUIRED!)
    libssl-dev \
 && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------
# nqptp (AirPlay 2 timing)  ✅ pthread-fix
# -------------------------------------------------
RUN git clone https://github.com/mikebrady/nqptp.git \
 && cd nqptp \
 && autoreconf -fi \
 && ./configure --prefix=/usr/local \
 && make \
 && make install

# -------------------------------------------------
# shairport-sync (ALSA ONLY, NO PA)
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

RUN apt-get update && apt-get install -y --no-install-recommends \
    libasound2 \
    libsndfile1 \
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
    procps \
    dbus \
 && rm -rf /var/lib/apt/lists/*

# --- Binaries ---
COPY --from=builder /usr/local/bin/shairport-sync /usr/local/bin/shairport-sync
COPY --from=builder /usr/bin/nqptp /usr/local/bin/nqptp

# --- Config & Scripts ---
COPY shairport-sync.conf /etc/shairport-sync.conf
COPY apply-config.sh /apply-config.sh
COPY start-dbus.sh /start-dbus.sh

RUN chmod +x /apply-config.sh /start-dbus.sh

# --- Start sequence ---
CMD ["/bin/sh", "-c", "/apply-config.sh && /start-dbus.sh && nqptp & shairport-sync -c /etc/shairport-sync.conf"]
