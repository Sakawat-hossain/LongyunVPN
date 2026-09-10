package com.longyunvpn.app.common

import android.content.Intent
import android.os.IBinder
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * ServiceDelegate is the seam between the app process and the `:remote`
 * process that runs the core. Every device-specific failure reported so far
 * lives on one side of it or the other — a bind that never completes on a cold
 * or throttled process, a start that races another, an OEM killer taking the
 * service out from under a call in flight.
 *
 * What matters is not that it succeeds. It is that it *fails in a bounded,
 * reportable way*: a call that hangs forever leaves the UI on "Connecting"
 * until the app is force-stopped, which is what the affected phones were doing.
 */
class ServiceDelegateTest {

    private fun delegate(): ServiceDelegate<String> =
        ServiceDelegate(Intent()) { _: IBinder -> "service" }

    @Test
    fun `a call against an unbound delegate gives up rather than hanging`() = runTest {
        // Nothing is bound and nothing ever will be. Before this was bounded,
        // the coroutine parked on the state flow forever and the Flutter call
        // above it never returned — indistinguishable from a frozen app.
        val result = delegate().useService(timeoutMillis = 50) { it }
        assertTrue("expected a failure, got $result", result.isFailure)
    }

    @Test
    fun `the failure is returned, not thrown`() = runTest {
        // Callers branch on the Result. If this threw instead, every call site
        // would need its own try/catch and the ones that forgot would take a
        // coroutine down silently.
        val result = delegate().useService(timeoutMillis = 50) { it }
        assertTrue(result.isFailure)
        assertNotNull(result.exceptionOrNull())
    }

    @Test
    fun `the timeout is honoured rather than ignored`() = runTest {
        val started = System.currentTimeMillis()
        delegate().useService(timeoutMillis = 100) { it }
        val elapsed = System.currentTimeMillis() - started
        // Generous upper bound: the point is that it returns at all, on
        // roughly the requested budget, not that it is precise.
        assertTrue("took ${elapsed}ms for a 100ms timeout", elapsed < 5_000)
    }

    @Test
    fun `the block never runs when nothing is bound`() = runTest {
        // A block that ran against a service that is not there would operate on
        // a stale or absent binder — worse than not running at all.
        var ran = false
        delegate().useService(timeoutMillis = 50) { ran = true }
        assertFalse("the block ran with no service bound", ran)
    }

    @Test
    fun `unbind on a delegate that was never bound is harmless`() {
        // stop() paths call this unconditionally, including after a start that
        // failed before binding.
        delegate().unbind()
    }

    @Test
    fun `unbind is idempotent`() {
        // Reached from several places at once — a user stop, a service
        // disconnect callback, and the stop that follows a failed start.
        val delegate = delegate()
        delegate.unbind()
        delegate.unbind()
        delegate.unbind()
    }

    @Test
    fun `state starts empty so nothing is mistaken for a live service`() {
        assertTrue(delegate().serviceState.value == null)
    }

    @Test
    fun `a delegate stays usable after a failed call`() = runTest {
        // One timeout must not latch the delegate permanently unusable. That
        // exact failure — a latch left set with no service behind it — is what
        // kept phones on "Connecting..." for the rest of the process lifetime,
        // however many times the user retried.
        val delegate = delegate()
        assertTrue(delegate.useService(timeoutMillis = 50) { it }.isFailure)
        assertTrue(delegate.useService(timeoutMillis = 50) { it }.isFailure)
        delegate.unbind()
        assertTrue(delegate.useService(timeoutMillis = 50) { it }.isFailure)
    }
}
