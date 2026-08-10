package main

import (
	"os"
	"runtime"
	"runtime/debug"
)

// init tunes the Go runtime for the host platform.
//
// On memory-constrained Android we lower the GC target percentage so the
// collector runs before the native heap doubles, keeping the process's memory
// footprint smaller and reducing the chance the OS kills the app under memory
// pressure. For a VPN core the steady-state allocation rate is low (GC pressure
// comes mostly from config reloads, not proxied traffic), so the extra CPU cost
// is negligible. Desktop keeps the default (100) for throughput.
//
// A GOGC value provided in the environment always wins — the runtime applies it
// at startup and we don't override an explicit operator choice. A GOMEMLIMIT
// soft cap set in the environment is likewise honored automatically.
func init() {
	if runtime.GOOS != "android" {
		return
	}
	if _, ok := os.LookupEnv("GOGC"); ok {
		return
	}
	debug.SetGCPercent(50)
}
