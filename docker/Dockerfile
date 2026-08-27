# tailwag-derper — container build of Tailscale's DERP relay
# (cmd/derper, from the tailscale.com module), used as tailwag's
# break-glass rendezvous/relay node. BSD-3-Clause upstream.

FROM golang:1.25-bookworm AS build
WORKDIR /src
ENV CGO_ENABLED=0 GOFLAGS=-trimpath
# @latest for now — pin to a specific tag once you've settled on one.
# derper makes no CLI/version stability promise upstream, same as tailcat.
RUN go install tailscale.com/cmd/derper@latest

# distroless/base, NOT -nonroot: derper binds 80/443 itself, which
# means either running as root in-container or granting
# CAP_NET_BIND_SERVICE explicitly. Root-in-container is the simpler
# choice here — the container boundary (plus this being a single-
# purpose VM with nothing else on it) is the isolation that matters.
FROM gcr.io/distroless/base-debian12
COPY --from=build /go/bin/derper /derper
VOLUME ["/var/lib/derper-certs"]
EXPOSE 443/tcp 80/tcp 3478/udp
ENTRYPOINT ["/derper"]
