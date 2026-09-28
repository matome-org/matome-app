FROM nginx:1.30.5-alpine@sha256:985220252f3863977e468f611ef118ebd01421289dd86ee1ae99cb068c3bce2b AS base

FROM base AS release

ARG WEB_RELEASE=v0.3.0
COPY scripts/fetch-web-release.sh /usr/local/bin/fetch-web-release
RUN fetch-web-release "$WEB_RELEASE" /web

FROM base

RUN rm -rf /usr/share/nginx/html/*
COPY --from=release /web/ /usr/share/nginx/html/
COPY packaging/web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
