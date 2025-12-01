FROM docker.io/library/ruby:3.4 AS build

RUN mkdir /build
COPY . /build
WORKDIR /build
RUN rm -fr pkg && bundle install && rake build

FROM docker.io/library/ruby:3.4 AS img

COPY --from=build /build/pkg/o3sr-*.gem / 
RUN gem install /o3sr-*.gem && \
    rm /o3sr-*.gem && \
    mkdir /o3sr && \
    chown daemon:daemon /o3sr

WORKDIR /o3sr
ENV XDG_CONFIG_HOME=/
USER daemon
ENTRYPOINT [ "o3sr" ]
 