FROM alpine:3.21

RUN apk --no-cache add git jq curl grep coreutils perl

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
