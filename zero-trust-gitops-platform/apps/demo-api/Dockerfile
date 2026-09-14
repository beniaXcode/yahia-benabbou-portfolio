# Builder and runtime digests resolved live against the real registries
# (Docker Hub / gcr.io) and recorded in ../docs/versions.md — never guessed.
# syntax=docker/dockerfile:1

FROM golang:1.27.1-alpine@sha256:cf6fca6641884b8433441b2b0652976f975e1d0fdd26d177eaaf8596087f3125 AS builder

ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_DATE=unknown

WORKDIR /src
COPY go.mod ./
COPY main.go ./

RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOFLAGS=-trimpath go build -trimpath \
    -ldflags "-s -w -X main.version=${VERSION} -X main.commit=${COMMIT} -X main.buildDate=${BUILD_DATE}" \
    -o /out/demo-api .

FROM gcr.io/distroless/static-debian12@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab

COPY --from=builder /out/demo-api /demo-api

USER 65532:65532

ENTRYPOINT ["/demo-api"]
