FROM ruby:latest
MAINTAINER Julien Fabre <ju.pryz@gmail.com>

EXPOSE 4000
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "gem: --no-rdoc --no-ri" >> ~/.gemrc

RUN apt-get -y update
RUN apt-get install -y \
  build-essential \
  make \
  ruby \
  ruby-dev \
  nodejs

RUN gem install github-pages

ADD . /blog
WORKDIR /blog

CMD ["jekyll", "serve"]
