// IEventInterface.aidl
package com.longyunvpn.app.service;

import com.longyunvpn.app.service.IAckInterface;

interface IEventInterface {
    oneway void onEvent(in String id, in byte[] data,in boolean isSuccess, in IAckInterface ack);
}