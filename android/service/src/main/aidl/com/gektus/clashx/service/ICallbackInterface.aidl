package com.gektus.clashx.service;

import com.gektus.clashx.service.IAckInterface;

interface ICallbackInterface {
    oneway void onResult(in byte[] data, in boolean isSuccess, in IAckInterface ack);
}
