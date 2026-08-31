package app_test

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/devdumpling/wlls/internal/app"
)

func TestRoutes(t *testing.T) {
	tests := []struct {
		name        string
		method      string
		path        string
		wantStatus  int
		wantType    string
		wantContent string
	}{
		{
			name:        "page",
			method:      http.MethodGet,
			path:        "/",
			wantStatus:  http.StatusOK,
			wantType:    "text/html",
			wantContent: "Hello, world.",
		},
		{
			name:        "health",
			method:      http.MethodGet,
			path:        "/healthz",
			wantStatus:  http.StatusOK,
			wantType:    "text/plain",
			wantContent: "ok\n",
		},
		{
			name:        "datastar patch",
			method:      http.MethodPost,
			path:        "/hello",
			wantStatus:  http.StatusOK,
			wantType:    "text/event-stream",
			wantContent: "Hello from a Datastar SSE response.",
		},
		{
			name:       "not found",
			method:     http.MethodGet,
			path:       "/missing",
			wantStatus: http.StatusNotFound,
			wantType:   "text/plain",
		},
	}

	handler := app.Routes()
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, tt.path, nil)
			res := httptest.NewRecorder()
			handler.ServeHTTP(res, req)

			result := res.Result()
			defer result.Body.Close()
			body, err := io.ReadAll(result.Body)
			if err != nil {
				t.Fatal(err)
			}
			if result.StatusCode != tt.wantStatus {
				t.Fatalf("status = %d, want %d", result.StatusCode, tt.wantStatus)
			}
			if got := result.Header.Get("Content-Type"); !strings.HasPrefix(got, tt.wantType) {
				t.Errorf("Content-Type = %q, want prefix %q", got, tt.wantType)
			}
			if tt.wantContent != "" && !strings.Contains(string(body), tt.wantContent) {
				t.Errorf("body does not contain %q: %s", tt.wantContent, body)
			}
		})
	}
}
