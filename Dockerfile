FROM ruby:slim

RUN apt-get update && apt-get install -y \
  wget

ENV STREAM_TESTER_VERSION=v0.9.38
ENV STREAM_TESTER_URL=https://github.com/livepeer/stream-tester/releases/download/${STREAM_TESTER_VERSION}/streamtester.Linux.gz \
    ASSET_URL=https://storage.googleapis.com/lp_testharness_assets/bbb_sunflower_1080p_30fps_normal_2min.mp4

WORKDIR /opt

# download asset to stream
RUN wget -O asset.mp4 $ASSET_URL

# install streamtester
RUN wget -O streamtester.gz $STREAM_TESTER_URL \
  && gunzip streamtester.gz \
  && chmod +x streamtester

# setup application
WORKDIR /app

# install dependencies
ADD ./Gemfile* /app/
RUN bundle install

# add source code
ADD . /app
