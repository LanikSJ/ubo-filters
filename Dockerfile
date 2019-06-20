FROM alpine:3.10.0
RUN apk --no-cache add python3 && mkdir -p /app
COPY . /app
