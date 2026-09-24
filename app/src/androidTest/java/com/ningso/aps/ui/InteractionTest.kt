package com.ningso.aps.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.ningso.aps.model.*
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InteractionTest {
    @get:Rule val compose = createComposeRule()

    @Test fun startRequiresExplicitTrustConfirmation() {
        var started = false
        compose.setContent { SignalTheme { ConsentSheet("192.0.2.10", {}, { started = true }) } }
        compose.onNodeWithTag("confirm-start").performScrollTo().assertIsNotEnabled()
        compose.onNodeWithTag("trust-network").performScrollTo().performClick()
        compose.onNodeWithTag("confirm-start").performScrollTo().assertIsEnabled().performClick()
        compose.runOnIdle { assertTrue(started) }
    }
    @Test fun missingAddressCannotBeConfirmed() {
        compose.setContent { SignalTheme { ConsentSheet(null, {}, {}) } }
        compose.onNodeWithTag("trust-network").performScrollTo().performClick()
        compose.onNodeWithTag("confirm-start").performScrollTo().assertIsNotEnabled()
    }
    @Test fun conflictingOrOutOfRangePortCannotBeSaved() {
        compose.setContent { SignalTheme { PortSheet(Protocol.HTTP, ProxySettings(), RuntimeSnapshot(), {}, { _, _ -> }) } }
        compose.onNodeWithTag("port-input").performScrollTo().performTextReplacement("1080")
        compose.onNodeWithTag("save-port").performScrollTo().assertIsNotEnabled()
        compose.onNodeWithTag("port-input").performScrollTo().performTextReplacement("65536")
        compose.onNodeWithTag("save-port").performScrollTo().assertIsNotEnabled()
    }
    @Test fun validPortCommitsOnlyWhenSaveIsPressed() {
        var port: Int? = null
        compose.setContent { SignalTheme { PortSheet(Protocol.HTTP, ProxySettings(), RuntimeSnapshot(), {}, { next, _ -> port = next }) } }
        compose.onNodeWithTag("save-port").performScrollTo().assertIsNotEnabled()
        compose.onNodeWithTag("port-input").performScrollTo().performTextReplacement("18080")
        compose.runOnIdle { assertNull(port) }
        compose.onNodeWithTag("save-port").performScrollTo().assertIsEnabled().performClick()
        compose.runOnIdle { assertEquals(18080, port) }
    }
    @Test fun closingPortEditorDoesNotCommitDraft() {
        var saved = false
        compose.setContent { SignalTheme { PortSheet(Protocol.HTTP, ProxySettings(), RuntimeSnapshot(), {}, { _, _ -> saved = true }) } }
        compose.onNodeWithTag("port-input").performScrollTo().performTextReplacement("18080")
        compose.onNodeWithText("取消").performScrollTo().performClick()
        compose.runOnIdle { assertFalse(saved) }
    }
}
