package com.budgetme.budgettracker

import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class BudgetNotificationListenerService : NotificationListenerService() {

    companion object {
        private val UPI_PACKAGES = setOf(
            "com.phonepe.app",
            "com.google.android.apps.nbu.paisa.user", // GPay
            "net.one97.paytm",
            "in.org.npci.upiapp",           // BHIM
            "com.axis.mobile",
            "com.snapwork.hdfc",
            "com.sbi.lotusintouch",
            "com.icicibank",
            "com.kotak.mahindra.kotak_mobile_banking",
            "com.dbs.ind.digibank",
        )

        private val AMOUNT_REGEX = Regex("""(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)""")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!UPI_PACKAGES.contains(sbn.packageName)) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val full = "$title $text"

        val match = AMOUNT_REGEX.find(full) ?: return
        val amount = match.groupValues[1].replace(",", "")

        // Write hint to FlutterSharedPreferences so the overlay widget can poll it.
        // Flutter's shared_preferences prefixes all keys with "flutter."
        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        prefs.edit()
            .putString("flutter.native_payment_hint_amount", amount)
            .putString(
                "flutter.native_payment_hint_ts",
                System.currentTimeMillis().toString()
            )
            .apply()
    }
}
