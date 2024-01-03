# Build.
FROM golang:1.21 as build

MAINTAINER "fonsi@google.com"

WORKDIR /go/src/app
COPY . .

RUN go mod download
RUN CGO_ENABLED=0 go build -o /go/bin/app

# Actual container image based on distroless.
FROM gcr.io/distroless/static-debian11
COPY --from=build /go/bin/app /
CMD ["/app"]
