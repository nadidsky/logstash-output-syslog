# Use an official JRuby image as the base image
FROM jruby:9.2.13.0

# Set environment variables
ENV LOGSTASH_VERSION 8.6.1

# Install the necessary dependencies for plugin development and testing
RUN apt-get update && apt-get install -y wget git && \
    wget https://artifacts.elastic.co/downloads/logstash/logstash-${LOGSTASH_VERSION}-amd64.deb && \
    dpkg -i logstash-${LOGSTASH_VERSION}-amd64.deb && \
    rm logstash-${LOGSTASH_VERSION}-amd64.deb

# Create a new directory for your plugin development
WORKDIR /opt/logstash-plugins

# Copy your plugin code into the container

COPY docs docs
COPY lib lib
COPY Gemfile Gemfile
COPY logstash-output-syslog.gemspec logstash-output-syslog.gemspec
COPY Rakefile Rakefile

# Install the dependencies for your plugin using bundler
RUN jruby -S bundle install

COPY spec spec

# Run the tests for your plugin using RSpec
RUN jruby -S bundle exec rspec

CMD ls -lash 
