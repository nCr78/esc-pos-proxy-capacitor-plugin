package com.revagon.place.menu.app.plugins.escpos;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.OutputStream;
import java.net.Socket;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.nio.ByteBuffer;
import java.util.Iterator;
import org.json.JSONException;

@CapacitorPlugin(name = "ESCPOSProxy")
public class ESCPOSProxyPlugin extends Plugin {

    private ESCPOSProxy implementation = new ESCPOSProxy();

    @PluginMethod
    public void print(PluginCall call) {
      try {
        System.out.println(call);
            String ip = call.getString("ip");
            int port = call.getInt("port", 9100);
            JSObject dataObject = call.getObject("message");
            if (dataObject == null) {
              call.reject("Data object is null");
              return;
            }

            // Extract byte array from JSON object
            byte[] data = extractByteArrayFromJSON(dataObject);

            sendEscPosCommand(ip, port, data);

            JSObject ret = new JSObject();
            ret.put("status", implementation.print("printed"));
            call.resolve(ret);
        } catch (JSONException e) {
            call.reject("Failed to read data array", e);
        }
    }

    private void sendEscPosCommand(String ip, int port, byte[] message) {
      // Define the timeout values in milliseconds
      int connectionTimeout = 5000; // 5 seconds
      int readTimeout = 5000; // 5 seconds

      try (Socket socket = new Socket()) {
        // Set the connection timeout
        socket.connect(new InetSocketAddress(ip, port), connectionTimeout);

        // Set the read timeout
        socket.setSoTimeout(readTimeout);

        try (OutputStream out = socket.getOutputStream()) {
          out.write(message);
          out.flush();
        }
      } catch (Exception e) {
        e.printStackTrace();
      }
    }

  private byte[] extractByteArrayFromJSON(JSObject dataObject) throws JSONException {
    int length = dataObject.length();
    byte[] data = new byte[length];
    Iterator<String> keys = dataObject.keys();
    int index = 0;
    while (keys.hasNext()) {
      String key = keys.next();
      data[index++] = (byte) dataObject.getInt(key);
    }
    return data;
  }
}
