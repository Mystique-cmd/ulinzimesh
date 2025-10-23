package main
import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
	"github.com/joho/godotenv"

	_"github.com/lib/pq"
)

type FlowEvent struct {
    Hostname  string `json:"hostname"`
    Platform  string `json:"platform"`
    SrcIP     string `json:"src_ip"`
    SrcPort   int    `json:"src_port"`
    DstIP     string `json:"dst_ip"`
    DstPort   int    `json:"dst_port"`
    Protocol  string `json:"protocol"`
    Direction string `json:"direction"`
    BytesTx   int64  `json:"bytes_tx"`
    BytesRx   int64  `json:"bytes_rx"`
}


type server struct {
	db *sql.DB
	token string
	stmtUpsertH *sql.Stmt
	stmtInsertNF *sql.Stmt
}

func (s *server) withAuth(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Example: check for token or session
        token := r.Header.Get("Authorization")
        if token != "expected-token" {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }
        next.ServeHTTP(w, r)
    })
}

func validateFlowEvent(event *FlowEvent) error {
    // validation logic here
    return nil
}

func main(){
	err := godotenv.Load()
    if err != nil {
        log.Fatal("Error loading .env file")
    }

    connStr := os.Getenv("DATABASE_URL") // or build from individual vars
    fmt.Println("Connection string:", connStr)

    db, err := sql.Open("postgres", connStr)
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    s := &server{
        db:    db,
        token: os.Getenv("COLLECTOR_TOKEN"),
    }
    
	s.prepareStatements()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz",s.healthz)
	mux.HandleFunc("/readyz", s.readyz)
	mux.Handle("/ingest/flow", s.withAuth(http.HandlerFunc(s.ingestFlow)))

	addr := env("COLLECTOR_BIND", "127.0.0.1:9090")
	srv  := &http.Server{
		Addr:	addr,
		Handler:	withLogging(mux),
		ReadHeaderTimeout:	5* time.Second,
	}

	go func(){
		log.Printf("collector listening on %s", addr)
		if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed){
			log.Fatalf("server error: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<- stop
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	log.Printf("shutting down...")
	_ = srv. Shutdown(ctx)
}

func (s *server) prepareStatements(){
	var err error
	s.stmtUpsertH, err = s.db.Prepare (`
	insert into hosts(hostname, platform) values( $1, $2)
	on conflict (hostname) do update set last_seen_at = now() 
	returning host_id`)
	must(err)

	s.stmtInsertNF, err = s.db.Prepare(`
    INSERT INTO network_flows (
        host_id, ts, src_ip, src_port, dst_ip, dst_port, direction, bytes_tx, bytes_rx
    	) VALUES (
        $1, now(), $2, $3, $4, $5, $6, $7, $8
    	)
	`)
must(err)

}

func (s *server) ingestFlow(w http.ResponseWriter, r *http.Request){
	if r.Method != http.MethodPost{
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	defer r.Body.Close()

	var ev FlowEvent
	if err := json.NewDecoder(r.Body).Decode(&ev); err != nil{
		http.Error(w, "Invalid Json", http.StatusBadRequest)
		return
	}

	if err := validateFlowEvent(&ev); err != nil{
		http.Error(w, fmt.Sprintf("invalid event: %v", err), http.StatusBadRequest)
		return
	}

	tx, err := s.db.Begin()
	if err !=  nil {
		http.Error(w, "db begin failed", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	var hostID string
	if err := s.stmtUpsertH.QueryRow(ev.Hostname, ev.Platform).Scan(&hostID); err != nil {
   		http.Error(w, "host upsert failed", http.StatusInternalServerError)
    	return
	}

	_, err = s.stmtInsertNF.Exec(
    hostID, ev.SrcIP, ev.SrcPort, ev.DstIP, ev.DstPort, ev.Protocol, ev.Direction, ev.BytesTx, ev.BytesRx,
	)

	 w.Header().Set("Content-Type","application/json")
	 w.WriteHeader(http.StatusAccepted)
	 _, _ = w.Write([]byte(`{"status":"accepted"}`))
}

func (s *server) healthz( w http.ResponseWriter, r *http.Request){
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func (s *server)readyz(w http.ResponseWriter, r *http.Request){
	if err := s.db.Ping(); err != nil{
		http.Error(w, "db not ready", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ready"))
}

func validateFlow( ev FlowEvent) error {
	if ev.Hostname == "" {
		return errors.New("hostname required")
	}
	switch ev.Platform{
	case "linux","windows","macos":
	default:
		return errors.New("invalid platform")
	}
	if net.ParseIP(ev.SrcIP) == nil || net.ParseIP(ev.DstIP) == nil {
		return errors.New("invalid IP")
	}
	if ev.SrcPort < 0 || ev.SrcPort > 65535 || ev.DstPort < 0 || ev.DstPort > 65535 {
		return errors.New("invalid port")
	}
	switch strings.ToLower(ev.Direction){
	case "ingeress","egress":
	default:
		return errors.New("invalid direction")
	}
	ev.Protocol = strings.ToLower(ev.Protocol)
	return nil
}

func must(err error){
	if err != nil {
		log.Fatal(err)
	}
}

func mustOpenDB() *sql.DB {
	dsn := fmt.Sprintf ("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		env("PGHOST", "127.0.0.1"),
		env("PGPORT", "5432"),
		env("PGUSER", "ulinzi"),
		env("PGPASSWORD", "ulinzi"),
		env("PGDATABASE", "ulinzi"),
	)
	db, err := sql.Open("postgres", dsn)
	must(err)
	must(db.Ping())
	return db
}

func env(k, def string) string {
	if v := os.Getenv(k); v != ""{
		return v
	}
	return def
}

func withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request){
		start := time.Now()
		lrw := &logResponseWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(lrw, r)
		log.Printf("%s %s %d %s", r.Method, r.URL.Path, lrw.status, time.Since(start))
	})
}

type logResponseWriter struct{
	http.ResponseWriter
	status int
}

func (lrw *logResponseWriter) WriteHeader(code int){
	lrw.status = code
	lrw.ResponseWriter.WriteHeader(code)
}