ARG NODE_TAG="15-alpine3.13"
FROM node:${NODE_TAG} as Runner
WORKDIR /usr/src/app
RUN apk add --no-cache bash git curl jq openssh-client
RUN yarn global add conventional-changelog-cli conventional-recommended-bump
COPY release-version.sh /usr/local/bin/release-version
RUN chmod a+x /usr/local/bin/release-version
ENV CURRENT_VERSION="" \
    DRY_RUN="0" \
    GH_REPOSITORY="pixelfederation/swoole-bundle" \
    GH_COMMITER_NAME="Rastusik" \
    GH_COMMITER_EMAIL="mfris@pixelfederation.com" \
    GH_TOKEN="" \
    GH_RELEASE_DRAFT="false" \
    GH_RELEASE_PRERELEASE="false"
ENTRYPOINT ["release-version"]
