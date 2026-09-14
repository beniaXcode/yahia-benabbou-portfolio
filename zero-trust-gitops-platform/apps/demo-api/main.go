// demo-api is a deliberately small stand-in workload: the platform around it
// is what this repository is actually about.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// Set via -ldflags "-X main.version=... -X main.commit=... -X main.buildDate=..."
var (
	version   = "dev"
	commit    = "unknown"
	buildDate = "unknown"
)

func main() {
	addr := ":" + portOrDefault()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", handleOK)
	mux.HandleFunc("/readyz", handleOK)
	mux.HandleFunc("/version", handleVersion)

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("demo-api %s listening on %s", version, addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("listen: %v", err)
		}
	}()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	<-ctx.Done()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}

func portOrDefault() string {
	if p := os.Getenv("PORT"); p != "" {
		return p
	}
	return "8080"
}

func handleOK(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func handleVersion(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"version":   version,
		"commit":    commit,
		"buildDate": buildDate,
	})
}
