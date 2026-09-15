package com.gektus.clashx.service.models

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class NotificationParams(
    val title: String = "GektusClashX",
    val stopText: String = "Stop",
) : Parcelable
