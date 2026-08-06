// ICallbackInterface.aidl
package com.longyunvpn.app.service;

import com.longyunvpn.app.service.IAckInterface;

interface ICallbackInterface {
    oneway void onResult(in byte[] data,in boolean isSuccess, in IAckInterface ack);
}