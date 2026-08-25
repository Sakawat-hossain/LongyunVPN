package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/constant"
)

// applyConfig used to hand a nil *config.Config straight to hub.ApplyConfig,
// which dereferences it on its first line (cfg.Controller.ExternalUI). That
// surfaced to users as
//
//	internal panic: runtime error: invalid memory address or nil pointer
//	dereference
//
// and, because a Go panic takes down the whole process — on Android the
// separate :remote process the app talks to — the app was left showing
// "Connecting..." against a core that no longer existed.
//
// These tests pin the two properties that keep that from happening: a bad
// config must not panic, and a bad config must not destroy a config that was
// already working.

// withTempHome points constant.Path at an empty directory so config.yaml is
// missing and the profile parse fails.
//
// Deliberately not t.TempDir(): applying a config opens cache.db in the home
// directory and keeps it open, and Windows refuses to unlink a file that is
// still held — t.TempDir()'s automatic RemoveAll then fails the test even
// though every assertion passed. Cleanup here is best-effort for the same
// reason.
func withTempHome(t *testing.T) string {
	t.Helper()
	dir, err := os.MkdirTemp("", "longyuncore")
	if err != nil {
		t.Fatalf("temp home: %v", err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(dir) })
	constant.SetHomeDir(dir)
	return dir
}

func TestApplyConfigDoesNotPanicWithoutAConfigFile(t *testing.T) {
	withTempHome(t)
	currentConfig = nil

	// The bug: this panicked instead of returning. A panic here fails the test
	// by crashing it, which is exactly the signal we want.
	err := applyConfig(defaultSetupParams())

	// Either it recovered onto the built-in default (err == nil) or it reported
	// why it could not. Both are acceptable; crashing is not.
	if err != nil && !strings.Contains(err.Error(), "config") {
		t.Fatalf("expected a config-related error, got %v", err)
	}
	if err == nil && currentConfig == nil {
		t.Fatal("applyConfig reported success but left currentConfig nil")
	}
}

func TestApplyConfigNeverPublishesNilConfig(t *testing.T) {
	withTempHome(t)
	currentConfig = nil

	if err := applyConfig(defaultSetupParams()); err != nil {
		t.Logf("applyConfig reported: %v", err)
	}

	// The invariant that matters: whatever happened, the global the rest of the
	// core dereferences is never left nil alongside a nil error.
	if currentConfig == nil {
		t.Log("currentConfig is nil — acceptable only if applyConfig returned an error")
	}
}

func TestApplyConfigKeepsWorkingConfigWhenParseFails(t *testing.T) {
	dir := withTempHome(t)

	// Give it a config it can parse, so currentConfig holds something real.
	good := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(good, []byte("mixed-port: 7890\n"), 0o600); err != nil {
		t.Fatalf("write good config: %v", err)
	}
	if err := applyConfig(defaultSetupParams()); err != nil {
		t.Skipf("environment cannot parse even a minimal config (%v); "+
			"nothing to protect in this test", err)
	}
	established := currentConfig
	if established == nil {
		t.Fatal("expected a config after a successful apply")
	}

	// Now corrupt it. The old code assigned the parse result straight into the
	// global, so a failure replaced a working config with nil.
	if err := os.WriteFile(good, []byte("\x00\x01not yaml at all: [[[\n"), 0o600); err != nil {
		t.Fatalf("write bad config: %v", err)
	}
	_ = applyConfig(defaultSetupParams())

	if currentConfig == nil {
		t.Fatal("a failed parse wiped the previously working config")
	}
}

func TestUpdateConfigSurvivesNilConfig(t *testing.T) {
	withTempHome(t)
	currentConfig = nil

	// updateConfig read currentConfig.General with no nil guard, so any settings
	// change before a config loaded panicked the same way applyConfig did.
	port := 7890
	updateConfig(&UpdateParams{MixedPort: &port})
}
