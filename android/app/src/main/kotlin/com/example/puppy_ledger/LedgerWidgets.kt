package com.example.puppy_ledger

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.graphics.*
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.widget.RemoteViews
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.abs

class QuickWidget : LedgerWidgetProvider()

class OverviewWidget : LedgerWidgetProvider()

class CalendarWidget : LedgerWidgetProvider()

abstract class LedgerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        refresh(context)

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) = refresh(context)

    override fun onDisabled(context: Context) = refresh(context)

    private fun refresh(context: Context) {
        val work = goAsync()
        LedgerWidgets.refresh(context) { work?.finish() }
    }
}

class WidgetClock : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val work = goAsync()
        LedgerWidgets.refresh(context) { work.finish() }
    }
}

/** Read Flutter's committed SQLite data even if its engine/process is stopped. */
private data class Snapshot(
    val today: Calendar,
    val todayKey: String,
    val days: Set<String>,
    val income: Long,
    val expense: Long,
    val balance: Long,
    val shortcuts: List<Pair<String, String>>,
    val theme: String,
    val goldenIncome: Boolean,
    val ready: Boolean,
)

private fun dayKey(c: Calendar) =
    SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = c.timeZone }.format(c.time)

private fun readLedger(context: Context): Snapshot {
    val now = Calendar.getInstance()
    val today = dayKey(now)
    val month = now.clone() as Calendar
    month.set(Calendar.DAY_OF_MONTH, 1)
    val first = dayKey(month)
    month.add(Calendar.MONTH, 1)
    val end = dayKey(month)
    val path = File(context.getDir("flutter", Context.MODE_PRIVATE), "puppy_ledger.db")
    val empty = Snapshot(now, today, emptySet(), 0, 0, 0, emptyList(), "lemon", true, false)
    if (!path.isFile) return empty
    return try {
        SQLiteDatabase.openDatabase(
                path.path,
                null,
                SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS,
            )
            .use { db ->
                // Old ledgers finish their atomic upgrade in Flutter before becoming widget data.
                if (db.version !in 2..3) return@use empty
                var income = 0L
                var expense = 0L
                var balance = 0L
                val days = mutableSetOf<String>()
                db.rawQuery(
                        "SELECT date, kind, SUM(cents) FROM entries WHERE date>=? AND date<? GROUP BY date,kind",
                        arrayOf(first, end),
                    )
                    .use { cur ->
                        while (cur.moveToNext()) {
                            val day = cur.getString(0)
                            val amount = cur.getLong(2)
                            val incoming = cur.getString(1) == "income"
                            days.add(day)
                            balance += if (incoming) amount else -amount
                            if (day == today) {
                                if (incoming) income += amount else expense += amount
                            }
                        }
                    }
                val cats = mutableListOf<Pair<String, String>>()
                db.rawQuery(
                        "SELECT c.id,c.name FROM categories c LEFT JOIN entries e ON e.categoryId=c.id WHERE c.kind='expense' AND c.active=1 GROUP BY c.id ORDER BY COUNT(e.id) DESC,c.rowid LIMIT 4",
                        null,
                    )
                    .use { cur ->
                        while (cur.moveToNext()) cats.add(cur.getString(0) to cur.getString(1))
                    }
                db.rawQuery("SELECT themeKey,goldenIncome FROM settings WHERE singleton=1", null)
                    .use { cur ->
                        if (!cur.moveToFirst()) empty
                        else
                            Snapshot(
                                now,
                                today,
                                days,
                                income,
                                expense,
                                balance,
                                cats,
                                cur.getString(0),
                                cur.getInt(1) == 1,
                                true,
                            )
                    }
            }
    } catch (e: Exception) {
        Log.w("PuppyWidget", "Ledger unavailable: ${e.javaClass.simpleName}")
        empty
    }
}

object LedgerWidgets {
    const val OPEN = "com.example.puppy_ledger.action.WIDGET_OPEN"
    private val worker = Executors.newSingleThreadExecutor()
    private val providers =
        listOf(QuickWidget::class.java, OverviewWidget::class.java, CalendarWidget::class.java)
    private val dogs = mutableMapOf<Boolean, Bitmap>()

    fun refresh(context: Context, complete: (() -> Unit)? = null) {
        val app = context.applicationContext
        worker.execute {
            try {
                val manager = AppWidgetManager.getInstance(app)
                val sets = providers.map { manager.getAppWidgetIds(ComponentName(app, it)) }
                val active = sets.any { it.isNotEmpty() }
                schedule(app, active)
                if (active) {
                    val data = readLedger(app)
                    sets.forEachIndexed { i, ids ->
                        if (ids.isNotEmpty()) manager.updateAppWidget(ids, render(app, i, data))
                    }
                }
            } catch (e: Exception) {
                Log.w("PuppyWidget", "Refresh failed: ${e.javaClass.simpleName}")
            } finally {
                complete?.invoke()
            }
        }
    }

    private fun schedule(c: Context, active: Boolean) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi =
            PendingIntent.getBroadcast(
                c,
                19,
                Intent(c, WidgetClock::class.java).setAction("ledger.MIDNIGHT"),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        if (!active) {
            am.cancel(pi)
            return
        }
        val next =
            Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, pi)
    }

    private fun launch(c: Context, mode: String, value: String = ""): PendingIntent {
        val data =
            Uri.Builder()
                .scheme("puppyledger-widget")
                .authority(mode)
                .appendQueryParameter("value", value)
                .build()
        val intent =
            Intent(c, MainActivity::class.java)
                .setAction(OPEN)
                .setData(data)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
        return PendingIntent.getActivity(
            c,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun dog(c: Context, golden: Boolean): Bitmap =
        dogs.getOrPut(golden) {
            val file = if (golden) "golden_coin" else "white_coin"
            val source =
                c.assets.open("flutter_assets/assets/avatars/$file.jpg").use {
                    BitmapFactory.decodeStream(
                        it,
                        null,
                        BitmapFactory.Options().apply { inSampleSize = 4 },
                    )
                } ?: error("Missing widget portrait")
            val bitmap = Bitmap.createBitmap(90, 90, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val side = minOf(source.width, source.height)
            val x = (source.width - side) / 2
            val y = (source.height - side) / 2
            canvas.clipPath(Path().apply { addCircle(45f, 45f, 45f, Path.Direction.CW) })
            canvas.drawBitmap(
                source,
                Rect(x, y, x + side, y + side),
                Rect(0, 0, 90, 90),
                Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
            )
            source.recycle()
            bitmap
        }

    private fun money(n: Long): String {
        val a = abs(n)
        return String.format(Locale.US, "%s¥%d.%02d", if (n < 0) "−" else "", a / 100, a % 100)
    }

    private fun render(c: Context, type: Int, s: Snapshot): RemoteViews {
        val (bg, tile) =
            when (s.theme) {
                "peach" -> R.drawable.widget_peach to R.drawable.tile_peach
                "sage" -> R.drawable.widget_sage to R.drawable.tile_sage
                else -> R.drawable.widget_lemon to R.drawable.tile_lemon
            }
        val v = RemoteViews(c.packageName, R.layout.widget_shell)
        v.setInt(android.R.id.background, "setBackgroundResource", bg)
        v.setImageViewBitmap(
            R.id.widget_dog,
            dog(c, if (type == 0) !s.goldenIncome else s.goldenIncome),
        )
        v.setTextViewText(R.id.widget_title, listOf("快捷记账", "收支概览", "记账日历")[type])
        v.setTextViewText(
            R.id.widget_period,
            if (type == 2) "${s.today.get(Calendar.YEAR)}年${s.today.get(Calendar.MONTH)+1}月"
            else "${s.today.get(Calendar.MONTH)+1}月${s.today.get(Calendar.DAY_OF_MONTH)}日",
        )
        v.setOnClickPendingIntent(android.R.id.background, launch(c, "day", s.todayKey))
        v.removeAllViews(R.id.widget_body)
        fun row() = RemoteViews(c.packageName, R.layout.widget_row)
        fun cell(
            label: String,
            color: Int?,
            action: PendingIntent?,
            desc: String = label,
            font: Float = 13f,
        ): RemoteViews {
            val cell = RemoteViews(c.packageName, R.layout.widget_cell)
            cell.setTextViewText(R.id.widget_cell, label)
            cell.setTextViewTextSize(R.id.widget_cell, TypedValue.COMPLEX_UNIT_SP, font)
            cell.setContentDescription(R.id.widget_cell, desc)
            if (color != null) cell.setInt(R.id.widget_cell, "setBackgroundResource", color)
            if (action != null) cell.setOnClickPendingIntent(R.id.widget_cell, action)
            return cell
        }
        if (!s.ready) {
            val r = row()
            r.addView(R.id.widget_row, cell("打开账本以加载", tile, launch(c, "day", s.todayKey)))
            v.addView(R.id.widget_body, r)
            return v
        }
        when (type) {
            0 -> {
                val cats = s.shortcuts
                if (cats.isEmpty()) {
                    val r = row()
                    r.addView(R.id.widget_row, cell("选择支出分类", tile, launch(c, "expense")))
                    v.addView(R.id.widget_body, r)
                } else {
                    for (pair in cats.chunked(2)) {
                        val r = row()
                        for ((id, name) in pair) r.addView(
                            R.id.widget_row,
                            cell(name, tile, launch(c, "expense", id), "记支出：$name"),
                        )
                        v.addView(R.id.widget_body, r)
                    }
                }
            }
            1 -> {
                for ((label, value) in
                    listOf("今日收入" to s.income, "今日支出" to s.expense, "本月结余" to s.balance)) {
                    val line = RemoteViews(c.packageName, R.layout.widget_amount)
                    line.setTextViewText(R.id.widget_label, label)
                    line.setTextViewText(R.id.widget_amount, money(value))
                    v.addView(R.id.widget_body, line)
                }
            }
            2 -> {
                val header = row()
                for (d in listOf("一", "二", "三", "四", "五", "六", "日")) header.addView(
                    R.id.widget_row,
                    cell(d, null, null, font = 10f),
                )
                v.addView(R.id.widget_body, header)
                val date = s.today.clone() as Calendar
                date.set(Calendar.DAY_OF_MONTH, 1)
                val offset = (date.get(Calendar.DAY_OF_WEEK) + 5) % 7
                val count = date.getActualMaximum(Calendar.DAY_OF_MONTH)
                for (w in 0 until (offset + count + 6) / 7) {
                    val week = row()
                    for (col in 0..6) {
                        val n = w * 7 + col - offset + 1
                        if (n !in 1..count) {
                            week.addView(R.id.widget_row, cell("", null, null))
                            continue
                        }
                        date.set(Calendar.DAY_OF_MONTH, n)
                        val key = dayKey(date)
                        val marked = s.days.contains(key)
                        week.addView(
                            R.id.widget_row,
                            cell(
                                n.toString(),
                                if (marked) tile else null,
                                launch(c, "day", key),
                                "$key，${if(marked)"有流水" else "无流水"}",
                                12f,
                            ),
                        )
                    }
                    v.addView(R.id.widget_body, week)
                }
            }
        }
        return v
    }
}
