package com.gektus.clashx.service;

import com.gektus.clashx.service.IAckInterface;

interface IEventInterface {
    oneway void onEvent(in String id, in byte[] data, in boolean isSuccess, in IAckInterface ack);
}
