#############################################
# Builder stage
#############################################
FROM debian:bullseye AS builder

ENV DEBIAN_FRONTEND=noninteractive

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
    xxd \
    libc6-dev \
    libasound2-dev \
    libsndfile1-dev \
    libavahi-client-dev \
    libavahi-common-dev \
    libdaemon-dev \
    libplist-dev \
    libsodium-dev \
    libgcrypt-dev \
    uuid-dev \
    libsoxr-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libmosquitto-dev \
    libpcre2-dev \
    libconfig-dev \
    libpopt-dev \
    libssl-dev \
 && rm -rf /var/lib/apt/lists/*

# -------- nqptp --------
RUN git clone https://github.com/mikebrady/nqptp.git \
 && cd nqptp \
 && autoreconf -fi \
 && ./configure --prefix=/usr/local \
 && make \
 && make install

# -------- shairport-sync (ALSA, AirPlay2, MQTT-ready) --------
RUN git clone https://github.com/mikebrady/shairport-sync.git \
 && cd shairport-sync \
 && autoreconf -fi \
 && ac_cv_header_stdint_h=yes ./configure \
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

# -------- Binaries --------
COPY --from=builder /usr/local/bin/shairport-sync /usr/bin/shairport-sync
COPY --from=builder /usr/local/bin/nqptp /usr/bin/nqptp

# -------- Scripts --------
COPY apply-config.sh /usr/bin/apply-config.sh
COPY start-dbus.sh /usr/bin/start-dbus.sh

RUN chmod +x /usr/bin/apply-config.sh /usr/bin/start-dbus.sh

# -------- Start --------
CMD ["/bin/sh", "-c", "\
/apply-config.sh && \
/start-dbus.sh && \
nqptp & \
sleep 1 && \
exec shairport-sync -c /etc/shairport-sync.conf \
"]
