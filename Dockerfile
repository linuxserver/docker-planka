# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.20 AS buildstage

# set version label
ARG PLANKA_RELEASE

RUN \
  echo "**** install packages ****" && \
  apk add  --no-cache \
    giflib \
    libgsf \
    nodejs \
    vips && \
  apk add  --no-cache --virtual=build-dependencies \
    build-base \
    npm \
    py3-setuptools \
    python3-dev && \
  echo "**** install planka ****" && \
  if [ -z ${PLANKA_RELEASE+x} ]; then \
  PLANKA_RELEASE=$(curl -s https://api.github.com/repos/plankanban/planka/releases/latest \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  mkdir -p /build && \
  curl -o \
    /tmp/planka.tar.gz -L \
    "https://github.com/plankanban/planka/archive/${PLANKA_RELEASE}.tar.gz" && \
  tar xf \
    /tmp/planka.tar.gz -C \
    /build --strip-components=1 && \
  cd /build/server && \
  npm install pnpm --global && \
  pnpm import && \
  pnpm install --prod && \
  cd /build/client && \
  pnpm import && \
  pnpm install --prod && \
  DISABLE_ESLINT_PLUGIN=true npm run build && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    $HOME/.cache \
    $HOME/.local \
    $HOME/.npm \
    /tmp/*

FROM ghcr.io/linuxserver/baseimage-alpine:3.20

ARG BUILD_DATE
ARG VERSION
ARG PLANKA_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thespad"

RUN \
  apk add  --no-cache \
    nodejs \
    postgresql16-client && \
    printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version

COPY --from=buildstage /build/server/ /app
COPY --from=buildstage /build/server/.env.sample /app/.env
COPY --from=buildstage /build/client/build /app/public/
COPY --from=buildstage /build/client/build/index.html /app/views/index.ejs

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 1337

VOLUME /config
