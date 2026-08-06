// IRemoteInterface.aidl
package com.longyunvpn.app.service;

import com.longyunvpn.app.service.ICallbackInterface;
import com.longyunvpn.app.service.IEventInterface;
import com.longyunvpn.app.service.IResultInterface;
import com.longyunvpn.app.service.IVoidInterface;
import com.longyunvpn.app.service.models.VpnOptions;
import com.longyunvpn.app.service.models.NotificationParams;

interface IRemoteInterface {
    void invokeAction(in String data, in ICallbackInterface callback);
    void quickSetup(in String initParamsString, in String setupParamsString, in ICallbackInterface callback, in IVoidInterface onStarted);
    void updateNotificationParams(in NotificationParams params);
    void startService(in VpnOptions options, in long runTime, in IResultInterface result);
    void stopService(in IResultInterface result);
    void setEventListener(in IEventInterface event);
    void setCrashlytics(in boolean enable);
    long getRunTime();
}