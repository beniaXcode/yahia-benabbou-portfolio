package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandleOK(t *testing.T) {
	for _, path := range []string{"/healthz", "/readyz"} {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		rec := httptest.NewRecorder()

		handleOK(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("%s: got status %d, want %d", path, rec.Code, http.StatusOK)
		}
		if body := rec.Body.String(); body != "ok" {
			t.Errorf("%s: got body %q, want %q", path, body, "ok")
		}
	}
}

func TestHandleVersion(t *testing.T) {
	version, commit, buildDate = "v1.2.3", "abc1234", "2026-09-14T00:00:00Z"
	defer func() { version, commit, buildDate = "dev", "unknown", "unknown" }()

	req := httptest.NewRequest(http.MethodGet, "/version", nil)
	rec := httptest.NewRecorder()

	handleVersion(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("got status %d, want %d", rec.Code, http.StatusOK)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("got Content-Type %q, want %q", ct, "application/json")
	}

	var got map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatalf("response is not valid JSON: %v", err)
	}

	want := map[string]string{"version": "v1.2.3", "commit": "abc1234", "buildDate": "2026-09-14T00:00:00Z"}
	for k, v := range want {
		if got[k] != v {
			t.Errorf("field %q: got %q, want %q", k, got[k], v)
		}
	}
}
