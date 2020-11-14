FROM ruby:slim

RUN apt-get update && apt-get install -y \
  wget \
  ffmpeg

ENV STREAM_TESTER_VERSION=v0.9.38
ENV STREAM_TESTER_URL=https://github.com/livepeer/stream-tester/releases/download/${STREAM_TESTER_VERSION}/streamtester.Linux.gz

WORKDIR /opt

# install streamtester
RUN wget -O streamtester.gz $STREAM_TESTER_URL \
  && gunzip streamtester.gz \
  && chmod +x streamtester

# Add test videos
RUN wget https://eric-test-livepeer.s3.amazonaws.com/bbb/bbb_30s.ts
RUN wget https://storage.googleapis.com/lp_testharness_assets/bbb_sunflower_1080p_30fps_normal_2min.mp4

# setup application
WORKDIR /app

# install dependencies
ADD ./Gemfile* /app/
# packages required for the json gem, which is required by the pagerduty gem
RUN apt-get update && apt-get install -y \
  gcc \
  make
RUN bundle install

# add source code
ADD . /app
