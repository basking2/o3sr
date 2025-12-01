FROM docker.io/library/ruby:3.4 AS build

RUN mkdir /build
COPY . /build
WORKDIR /build
RUN bundle install && rake build

FROM docker.io/library/ruby:3.4 AS img

COPY --from=build /build/pkg/o3sr-*.gem / 
RUN gem install /o3sr-*.gem && \
    rm /o3sr-*.gem
USER daemon
ENTRYPOINT [ "br" ]
 