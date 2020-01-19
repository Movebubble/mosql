FROM ruby:2.3.7 as builder

WORKDIR /mosql

COPY . ./
RUN gem build mosql.gemspec



FROM ruby:2.3.7

WORKDIR /mosql

COPY --from=builder /mosql/mosql-0.5.0.gem ./
COPY mongoriver-0.5.0.gem ./
COPY collections.yml /mosql/conf.d/
COPY collections-analytics.yml  /mosql/conf.d/

RUN gem install awesome_print
RUN gem install mosql-0.5.0.gem

ENTRYPOINT ["/usr/local/bundle/bin/mosql", "--help"]
