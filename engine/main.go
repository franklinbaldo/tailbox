package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"tailscale.com/net/socks5"
	"tailscale.com/tsnet"
)

func main() {
	if err := run(); err != nil {
		log.Fatalf("tailbox: %v", err)
	}
}

func run() error {
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		var err error
		localAppData, err = os.UserConfigDir()
		if err != nil {
			return fmt.Errorf("find user configuration directory: %w", err)
		}
	}

	var (
		socksPort = flag.Int("socks-port", 1055, "local SOCKS5 proxy port")
		httpPort  = flag.Int("http-port", 1056, "local HTTP proxy port")
		hostname  = flag.String("hostname", "tailbox", "tailnet device name")
		stateDir  = flag.String(
			"state-dir",
			filepath.Join(localAppData, "TailBox", "state"),
			"persistent Tailscale identity directory",
		)
	)
	flag.Parse()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	server := &tsnet.Server{
		Dir:      *stateDir,
		Hostname: *hostname,
		UserLogf: func(format string, args ...any) {
			log.Printf(format, args...)
		},
	}
	defer server.Close()

	log.Printf("state: %s", *stateDir)
	log.Printf("connecting to Tailscale; authorize the URL below on first use")
	if _, err := server.Up(ctx); err != nil {
		return fmt.Errorf("connect to tailnet: %w", err)
	}

	socksAddress := net.JoinHostPort("127.0.0.1", fmt.Sprint(*socksPort))
	httpAddress := net.JoinHostPort("127.0.0.1", fmt.Sprint(*httpPort))
	socksListener, err := net.Listen("tcp", socksAddress)
	if err != nil {
		return fmt.Errorf("listen on SOCKS5 proxy %s: %w", socksAddress, err)
	}
	defer socksListener.Close()

	httpListener, err := net.Listen("tcp", httpAddress)
	if err != nil {
		return fmt.Errorf("listen on HTTP proxy %s: %w", httpAddress, err)
	}
	defer httpListener.Close()

	socksServer := &socks5.Server{
		Dialer: server.Dial,
		Logf:   log.Printf,
	}
	httpServer := &http.Server{
		Handler:           &proxyHandler{dial: server.Dial},
		ReadHeaderTimeout: 15 * time.Second,
	}

	errs := make(chan error, 2)
	go func() { errs <- socksServer.Serve(socksListener) }()
	go func() { errs <- httpServer.Serve(httpListener) }()

	log.Printf("SOCKS5 proxy: socks5://%s", socksAddress)
	log.Printf("HTTP proxy: http://%s", httpAddress)
	log.Printf("press Ctrl+C to stop TailBox")

	select {
	case <-ctx.Done():
		shutdownContext, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return httpServer.Shutdown(shutdownContext)
	case err := <-errs:
		if err == nil || err == http.ErrServerClosed {
			return nil
		}
		return err
	}
}

type proxyHandler struct {
	dial func(context.Context, string, string) (net.Conn, error)
}

func (p *proxyHandler) ServeHTTP(response http.ResponseWriter, request *http.Request) {
	if request.Method == http.MethodConnect {
		p.connect(response, request)
		return
	}

	outgoing := request.Clone(request.Context())
	outgoing.RequestURI = ""
	transport := &http.Transport{
		DialContext:       p.dial,
		DisableKeepAlives: true,
	}
	defer transport.CloseIdleConnections()

	result, err := transport.RoundTrip(outgoing)
	if err != nil {
		http.Error(response, err.Error(), http.StatusBadGateway)
		return
	}
	defer result.Body.Close()
	copyHeaders(response.Header(), result.Header)
	response.WriteHeader(result.StatusCode)
	_, _ = io.Copy(response, result.Body)
}

func (p *proxyHandler) connect(response http.ResponseWriter, request *http.Request) {
	upstream, err := p.dial(request.Context(), "tcp", request.Host)
	if err != nil {
		http.Error(response, err.Error(), http.StatusBadGateway)
		return
	}

	hijacker, ok := response.(http.Hijacker)
	if !ok {
		upstream.Close()
		http.Error(response, "HTTP hijacking unavailable", http.StatusInternalServerError)
		return
	}
	client, _, err := hijacker.Hijack()
	if err != nil {
		upstream.Close()
		return
	}

	_, _ = client.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
	go relay(client, upstream)
	go relay(upstream, client)
}

func relay(destination net.Conn, source net.Conn) {
	defer destination.Close()
	defer source.Close()
	_, _ = io.Copy(destination, source)
}

func copyHeaders(destination, source http.Header) {
	for name, values := range source {
		for _, value := range values {
			destination.Add(name, value)
		}
	}
}
