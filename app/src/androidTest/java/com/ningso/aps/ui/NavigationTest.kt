package com.ningso.aps.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.ningso.aps.MainActivity
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NavigationTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    @Test fun tabsAndSystemBackStayInsideTheNativeApp() {
        compose.onNodeWithTag("nav-connect").performClick().assertIsSelected()
        compose.onNodeWithText("下一台，连接。").assertIsDisplayed()
        compose.onNodeWithTag("nav-activity").performClick().assertIsSelected()
        compose.onNodeWithTag("nav-overview").performClick().assertIsSelected()
        compose.onNodeWithContentDescription("设置").performClick()
        compose.onNodeWithText("少一点干扰。").assertIsDisplayed()
        compose.onNodeWithContentDescription("返回").performClick()
        compose.onNodeWithTag("power-control").assertExists()
    }
}
