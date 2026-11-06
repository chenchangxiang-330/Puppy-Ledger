package com.example.ledgerwidgethost;
import android.app.*;import android.appwidget.*;import android.content.*;import android.graphics.Color;import android.os.Bundle;import android.view.*;import android.widget.*;
/** Test-only real AppWidgetHost. Every panel is the RemoteViews supplied by the installed app. */
public class HostActivity extends Activity {
 private AppWidgetHost host;
 private int dp(int n){return Math.round(getResources().getDisplayMetrics().density*n);}
 @Override public void onCreate(Bundle state){super.onCreate(state);host=new AppWidgetHost(this,19);AppWidgetManager manager=AppWidgetManager.getInstance(this);ScrollView scroll=new ScrollView(this);LinearLayout list=new LinearLayout(this);list.setOrientation(1);list.setPadding(dp(12),dp(8),dp(12),dp(8));list.setBackgroundColor(Color.rgb(246,244,238));scroll.addView(list);setContentView(scroll);
 String[] cls={"QuickWidget","OverviewWidget","CalendarWidget"};int[] heights={117,120,218};int width=Math.max(180,Math.round(getResources().getDisplayMetrics().widthPixels/getResources().getDisplayMetrics().density)-24);
 for(int i=0;i<cls.length;i++){ComponentName component=new ComponentName("com.example.puppy_ledger.linepuppy","com.example.puppy_ledger."+cls[i]);int id=getPreferences(0).getInt(cls[i],-1);if(id<0||manager.getAppWidgetInfo(id)==null){id=host.allocateAppWidgetId();Bundle opts=new Bundle();opts.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,width);opts.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,heights[i]);opts.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH,width);opts.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,heights[i]);if(!manager.bindAppWidgetIdIfAllowed(id,component,opts)){host.deleteAppWidgetId(id);TextView fail=new TextView(this);fail.setText("Bind failed: "+cls[i]);list.addView(fail);continue;}getPreferences(0).edit().putInt(cls[i],id).commit();}
 AppWidgetProviderInfo info=manager.getAppWidgetInfo(id);AppWidgetHostView view=host.createView(this,id,info);view.setPadding(0,0,0,0);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,dp(heights[i]));lp.bottomMargin=dp(8);list.addView(view,lp);view.updateAppWidgetSize(null,width,heights[i],width,heights[i]);}
 }
 @Override protected void onStart(){super.onStart();host.startListening();}
 @Override protected void onStop(){host.stopListening();super.onStop();}
}
