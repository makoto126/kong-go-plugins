FROM alexmiaomiao/kong-go-plugin-builder as builder

ARG PLUGIN

RUN go get github.com/Kong/go-pluginserver

RUN mkdir /go-plugins
COPY $PLUGIN/$PLUGIN.go /go-plugins/$PLUGIN.go
RUN go build -buildmode plugin -o /go-plugins/$PLUGIN.so /go-plugins/$PLUGIN.go

FROM kong

ARG PLUGIN

COPY --from=builder /go/bin/go-pluginserver /usr/local/bin/go-pluginserver
RUN mkdir /tmp/go-plugins
COPY --from=builder /go-plugins/$PLUGIN.so /tmp/go-plugins/$PLUGIN.so