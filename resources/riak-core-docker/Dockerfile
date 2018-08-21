FROM ubuntu:17.10

RUN \
  sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y --no-install-recommends wget build-essential git ca-certificates && \
  wget http://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && \
  dpkg -i erlang-solutions_1.0_all.deb && \
  apt-get update && \
  apt-get install -y --no-install-recommends erlang-nox erlang-dev erlang-src && \
  wget https://s3.amazonaws.com/rebar3/rebar3 -O /usr/local/bin/rebar3 && \
  chmod 755 /usr/local/bin/rebar3

RUN useradd -ms /bin/bash devuser
USER devuser
WORKDIR /home/devuser

COPY validate_config /usr/local/bin/validate_config
