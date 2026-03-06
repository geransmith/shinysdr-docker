ARG PLATFORM=amd64
FROM ${PLATFORM}/debian:12-slim
LABEL maintainer="Jefferson J. Hunt <jeffersonjhunt@gmail.com>"

ENV DEBIAN_FRONTEND=noninteractive
ENV MAKEFLAGS='-j 8'

# Ensure that we always use UTF-8, US English locale and UTC time
RUN apt-get update && apt-get install -y locales && \
  localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
  echo "UTC" > /etc/timezone && \
  chmod 0755 /etc/timezone 
ENV LANG=en_US.utf8
ENV LC_ALL=en_US.utf-8
ENV LANGUAGE=en_US:en
ENV PYTHONIOENCODING=utf-8

# Download required files directly instead of copying from assets
RUN apt-get install -y wget && \
    wget https://bootstrap.pypa.io/pip/3.6/get-pip.py -O /tmp/get-pip.py && \
    wget https://sourceforge.net/projects/wsjt/files/wsjtx-2.7.0/wsjtx-2.7.0.tgz/download -O /tmp/wsjtx-2.7.0.tgz

# Install supporting apps needed to build/run
RUN apt-get install -y \
      git \
      build-essential \
      cmake \
      cmake-data \
      pkg-config \
      doxygen \
      swig \
      texinfo \
      dh-autoreconf \
      python3 \
      python3-dev \
      python3-ephem \
      gfortran \
      gr-osmosdr \
      gnuradio \
      gnuradio-dev \
      libudev-dev \
      libusb-1.0-0-dev \
      qttools5-dev \
      qttools5-dev-tools \
      qtmultimedia5-dev \
      libqt5serialport5-dev \
      libssl-dev \
      libffi-dev \
      libfftw3-dev \
      libboost-all-dev \
      libboost-log-dev \
      libboost-system-dev \
      libboost-thread-dev \
      libboost-filesystem-dev && \
    python3 /tmp/get-pip.py && \
    pip install --upgrade pip

WORKDIR /build

# Add modules/plugins - Updated WSJT-X to use git
RUN tar zxvf /tmp/wsjtx-2.7.0.tgz && \
  cd wsjtx-2.7.0 && \
  mkdir build && cd build && \
  cmake -DWSJT_SKIP_MANPAGES=ON -DWSJT_GENERATE_DOCS=OFF ../ && \
  cmake --build . && cmake --build . --target install && ldconfig && \
  cd /build && rm -rf wsjtx-2.7.0

# Replace gr-air-modes with modern gr-adsb (GNU Radio 3.10 compatible)
RUN apt-get install -y python3-colorama && \
  git clone https://github.com/mhostetter/gr-adsb.git && \
  cd gr-adsb && \
  mkdir build && cd build && \
  cmake ../ && make && make install && ldconfig && \
  cd /build && rm -rf gr-adsb

# Rest of your modules remain the same...
RUN git clone https://github.com/EliasOenal/multimon-ng.git && \
  cd multimon-ng && \
  mkdir build && cd build && cmake ../ && make && make install && ldconfig && \
  cd /build && rm -rf multimon-ng

RUN git clone https://github.com/pothosware/SoapySDR.git && \
  cd SoapySDR && \
  git fetch --all --tags --prune && \
  git checkout tags/soapy-sdr-0.7.2 && \
  mkdir build && cd build && cmake ../ && make && make install && ldconfig && \
  cd /build && rm -rf SoapySDR

# Your updated rtl_433 section (this is correct!)
RUN git clone https://github.com/merbanan/rtl_433.git && \
  apt-get install -y librtlsdr-dev && \
  cd rtl_433 && \
  git fetch --all --tags --prune && \
  git checkout tags/25.12 && \
  mkdir build && cd build && cmake ../ && make && make install && ldconfig && \
  cd /build && rm -rf rtl_433

RUN git clone https://github.com/argilo/gr-dsd.git && \
  apt-get install -y libsndfile1-dev libitpp-dev && \
  cd gr-dsd && \
  git checkout master && \
  mkdir build && cd build && cmake ../ && make && make install && ldconfig && \
  cd /build && rm -rf gr-dsd

# Install your Python 3 compatible ShinySDR fork
RUN git clone https://github.com/geransmith/shinysdr.git -b python3-docker-compatibility && \
    cd shinysdr && \
    pip install --break-system-packages twisted txws service-identity pyserial ephem && \
    python3 setup.py build && \
    python3 setup.py install && \
    python3 setup.py fetch_deps && \
    cd / && rm -rf shinysdr

# Clean up APT when done.
RUN apt-get purge -y \
      git \
      build-essential \
      cmake \
      cmake-data \
      pkg-config \
      doxygen \
      swig \
      texinfo \
      dh-autoreconf \
      gnuradio-dev \
      libudev-dev \
      libusb-1.0-0-dev \
      qttools5-dev \
      qttools5-dev-tools \
      qtmultimedia5-dev \
      libqt5serialport5-dev \
      libfftw3-dev && \
  apt-get autoclean -y && \
  apt-get autoremove -y && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add mgmt scripts
COPY shinysdr-entrypoint.sh /usr/local/bin/shinysdr-entrypoint.sh
RUN chmod +x /usr/local/bin/shinysdr-entrypoint.sh

# Fire it up!
EXPOSE 8100 8101
ENTRYPOINT ["shinysdr-entrypoint.sh"]
CMD ["start"]
