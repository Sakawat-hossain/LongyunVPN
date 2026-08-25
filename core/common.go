package main

import (
	b "bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/common/batch"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/component/updater"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/constant/features"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/hub/route"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/log"
	rp "github.com/metacubex/mihomo/rules/provider"
	"github.com/metacubex/mihomo/tunnel"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"sync/atomic"
)

var (
	currentConfig *config.Config
	version       = 0
	isRunning     atomic.Bool
	runLock       sync.Mutex
	mBatch, _     = batch.New[bool](context.Background(), batch.WithConcurrencyNum[bool](50))
	debugError    = false
)

func getExternalProvidersRaw() map[string]cp.Provider {
	eps := make(map[string]cp.Provider)
	for n, p := range tunnel.Providers() {
		if p.VehicleType() != cp.Compatible {
			eps[n] = p
		}
	}
	for n, p := range tunnel.RuleProviders() {
		if p.VehicleType() != cp.Compatible {
			eps[n] = p
		}
	}
	return eps
}

func toExternalProvider(p cp.Provider) (*ExternalProvider, error) {
	switch p.(type) {
	case *provider.ProxySetProvider:
		psp := p.(*provider.ProxySetProvider)
		return &ExternalProvider{
			Name:             psp.Name(),
			Type:             psp.Type().String(),
			VehicleType:      psp.VehicleType().String(),
			Count:            psp.Count(),
			UpdateAt:         psp.UpdatedAt(),
			Path:             psp.Vehicle().Path(),
			SubscriptionInfo: psp.GetSubscriptionInfo(),
		}, nil
	case *rp.RuleSetProvider:
		rsp := p.(*rp.RuleSetProvider)
		return &ExternalProvider{
			Name:        rsp.Name(),
			Type:        rsp.Type().String(),
			VehicleType: rsp.VehicleType().String(),
			Count:       rsp.Count(),
			UpdateAt:    rsp.UpdatedAt(),
			Path:        rsp.Vehicle().Path(),
		}, nil
	default:
		return nil, errors.New("not external provider")
	}
}

func sideUpdateExternalProvider(p cp.Provider, bytes []byte) error {
	switch p.(type) {
	case *provider.ProxySetProvider:
		psp := p.(*provider.ProxySetProvider)
		_, _, err := psp.SideUpdate(bytes)
		if err == nil {
			return err
		}
		return nil
	case rp.RuleSetProvider:
		rsp := p.(*rp.RuleSetProvider)
		_, _, err := rsp.SideUpdate(bytes)
		if err == nil {
			return err
		}
		return nil
	default:
		return errors.New("not external provider")
	}
}

func updateListeners() {
	if !isRunning.Load() {
		return
	}
	if currentConfig == nil {
		return
	}
	listeners := currentConfig.Listeners
	general := currentConfig.General
	listener.PatchInboundListeners(listeners, tunnel.Tunnel, true)

	allowLan := general.AllowLan
	listener.SetAllowLan(allowLan)
	inbound.SetSkipAuthPrefixes(general.SkipAuthPrefixes)
	inbound.SetAllowedIPs(general.LanAllowedIPs)
	inbound.SetDisAllowedIPs(general.LanDisAllowedIPs)

	bindAddress := general.BindAddress
	listener.SetBindAddress(bindAddress)
	listener.ReCreateHTTP(general.Port, tunnel.Tunnel)
	listener.ReCreateSocks(general.SocksPort, tunnel.Tunnel)
	listener.ReCreateRedir(general.RedirPort, tunnel.Tunnel)
	listener.ReCreateTProxy(general.TProxyPort, tunnel.Tunnel)
	listener.ReCreateMixed(general.MixedPort, tunnel.Tunnel)
	listener.ReCreateShadowSocks(general.ShadowSocksConfig, tunnel.Tunnel)
	listener.ReCreateVmess(general.VmessConfig, tunnel.Tunnel)
	listener.ReCreateTuic(general.TuicServer, tunnel.Tunnel)
	if !features.Android {
		listener.ReCreateTun(general.Tun, tunnel.Tunnel)
	}
}

func stopListeners() {
	listener.StopListener()
}

func patchSelectGroup(mapping map[string]string) {
	for name, proxy := range tunnel.AllProxies() {
		outbound, ok := proxy.(*adapter.Proxy)
		if !ok {
			continue
		}

		selector, ok := outbound.ProxyAdapter.(outboundgroup.SelectAble)
		if !ok {
			continue
		}

		selected, exist := mapping[name]
		if !exist {
			continue
		}

		selector.ForceSet(selected)
	}
}

func defaultSetupParams() *SetupParams {
	return &SetupParams{
		TestURL:     "https://www.gstatic.com/generate_204",
		SelectedMap: map[string]string{},
	}
}

func readFile(path string) ([]byte, error) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	return data, err
}

func updateConfig(params *UpdateParams) {
	runLock.Lock()
	defer runLock.Unlock()
	if currentConfig == nil {
		// Same crash as applyConfig's, reached from a different door: any
		// settings change before a config has successfully loaded would
		// dereference nil here. updateListeners already guards this way.
		logError("updateConfig: no config loaded yet, ignoring update")
		return
	}
	general := currentConfig.General
	if params.MixedPort != nil {
		general.MixedPort = *params.MixedPort
	}
	if params.Sniffing != nil {
		general.Sniffing = *params.Sniffing
		tunnel.SetSniffing(general.Sniffing)
	}
	if params.FindProcessMode != nil {
		general.FindProcessMode = *params.FindProcessMode
		tunnel.SetFindProcessMode(general.FindProcessMode)
	}
	if params.TCPConcurrent != nil {
		general.TCPConcurrent = *params.TCPConcurrent
		dialer.SetTcpConcurrent(general.TCPConcurrent)
	}
	if params.Interface != nil {
		general.Interface = *params.Interface
		dialer.DefaultInterface.Store(general.Interface)
	}
	if params.UnifiedDelay != nil {
		general.UnifiedDelay = *params.UnifiedDelay
		adapter.UnifiedDelay.Store(general.UnifiedDelay)
	}
	if params.Mode != nil {
		general.Mode = *params.Mode
		tunnel.SetMode(general.Mode)
	}
	if params.LogLevel != nil {
		general.LogLevel = *params.LogLevel
		log.SetLevel(general.LogLevel)
	}
	if params.IPv6 != nil {
		general.IPv6 = *params.IPv6
		resolver.DisableIPv6 = !general.IPv6
	}
	if params.ExternalController != nil {
		currentConfig.Controller.ExternalController = *params.ExternalController
		route.ReCreateServer(&route.Config{
			Addr: currentConfig.Controller.ExternalController,
		})
	}

	if params.Tun != nil {
		general.Tun.Enable = params.Tun.Enable
		// Every field below is a pointer, and the caller only sends the ones it
		// wants changed. Dereferencing unconditionally panicked the core (and
		// took the VPN down with it) on any partial tun update.
		if params.Tun.AutoRoute != nil {
			general.Tun.AutoRoute = *params.Tun.AutoRoute
		}
		if params.Tun.Device != nil {
			general.Tun.Device = *params.Tun.Device
		}
		if params.Tun.RouteAddress != nil {
			general.Tun.RouteAddress = *params.Tun.RouteAddress
		}
		if params.Tun.DNSHijack != nil {
			general.Tun.DNSHijack = *params.Tun.DNSHijack
		}
		if params.Tun.Stack != nil {
			general.Tun.Stack = *params.Tun.Stack
		}
	}

	if params.GeoAutoUpdate != nil {
		updater.SetGeoAutoUpdate(*params.GeoAutoUpdate)
	}
	if params.GeoUpdateInterval != nil {
		updater.SetGeoUpdateInterval(*params.GeoUpdateInterval)
	}

	updateListeners()
	registerGeoUpdater()
}

// Starts (or restarts) the periodic GEO database refresh.
//
// Setting geo-auto-update in the config only stores the flag: mihomo starts the
// updater goroutine from its standalone main(), which we never run, so nothing
// was ever scheduled and the databases only changed when the user asked. The
// WithCancel variant cancels a previous goroutine first, so calling it on every
// config apply cannot pile up tickers.
func registerGeoUpdater() {
	if updater.GeoAutoUpdate() {
		updater.RegisterGeoUpdaterWithCancel()
	}
}

func applyConfig(params *SetupParams) error {
	runLock.Lock()
	defer runLock.Unlock()
	constant.DefaultTestURL = params.TestURL

	// Parse into a local first. This used to assign straight into the global,
	// which meant a failed parse replaced a perfectly good running config with
	// nil — and then handed that nil to hub.ApplyConfig, whose very first act is
	// to read cfg.Controller.ExternalUI. That is the
	//
	//   internal panic: runtime error: invalid memory address or nil pointer
	//   dereference
	//
	// users hit on connect: the fallback's error was discarded with `_`, so when
	// both the profile and the built-in default failed to parse the code walked
	// into a nil dereference instead of reporting why. A panic here kills the
	// whole core process, which on Android is the separate :remote process, so
	// the app is left showing "Connecting..." against a core that no longer
	// exists.
	cfg, err := executor.ParseWithPath(filepath.Join(constant.Path.HomeDir(), "config.yaml"))
	if err != nil {
		var fallbackErr error
		cfg, fallbackErr = config.ParseRawConfig(config.DefaultRawConfig())
		if fallbackErr != nil {
			return fmt.Errorf(
				"config unusable: %w (built-in default also failed: %v)", err, fallbackErr)
		}
	}
	if cfg == nil {
		// Belt and braces: a nil config with a nil error would still crash, and
		// the cost of checking is nothing next to taking the core down.
		return fmt.Errorf("config parsed to nil (original error: %v)", err)
	}

	currentConfig = cfg
	hub.ApplyConfig(currentConfig)
	patchSelectGroup(params.SelectedMap)
	updateListeners()
	registerGeoUpdater()
	// Reclaim the replaced config's memory off the hot path. This used to be a
	// synchronous runtime.GC() before the lock, stalling every connect / proxy
	// switch / settings change with a stop-the-world GC. Running it in a
	// goroutine after the new config is live keeps the memory hygiene without
	// blocking config application.
	go runtime.GC()
	return err
}

func UnmarshalJson(data []byte, v any) error {
	decoder := json.NewDecoder(b.NewReader(data))
	decoder.UseNumber()
	err := decoder.Decode(v)
	return err
}

// Runs fn in a goroutine that cannot take the process down with it.
//
// A panic in any goroutine ends the whole program in Go — there is no
// per-goroutine boundary. On Android that program is the separate :remote
// process the app talks to, so a single bad lookup in a background task made
// the core vanish with nothing to explain it, and the app just saw a dead core.
// handleAction already recovers on its own goroutine; everything spawned beyond
// it was unprotected. The callback a panicking task owed its caller still goes
// unanswered, but the caller times out against a core that is alive instead of
// one that is gone.
func safeGo(name string, fn func()) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				buf := make([]byte, 4096)
				n := runtime.Stack(buf, false)
				logError("panic in %s: %v\n%s", name, r, buf[:n])
			}
		}()
		fn()
	}()
}

func logError(format string, args ...interface{}) {
	log.Errorln(format, args...)
	if debugError {
		fmt.Fprintf(os.Stderr, "[ERROR] "+format+"\n", args...)
	}
}
