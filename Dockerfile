FROM alpine:3.8
RUN apk --no-cache add python3 && mkdir -p /app
COPY . /app
