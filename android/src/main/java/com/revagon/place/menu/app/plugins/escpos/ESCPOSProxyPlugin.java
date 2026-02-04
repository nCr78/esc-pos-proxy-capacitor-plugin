package com.revagon.place.menu.app.plugins.escpos;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.OutputStream;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Future;
import java.net.NetworkInterface;
import java.util.Enumeration;

import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.os.Handler;
import android.os.Looper;
import android.content.Context;
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

  @PluginMethod
  public void ping(PluginCall call) {
    String ip = call.getString("ip");
    int port = call.getInt("port", 9100);
    if (ip == null || ip.isEmpty()) {
      call.reject("IP address is required");
      return;
    }

    getBridge().execute(() -> {
      PingResult result = pingHost(ip, port, 2000);
      JSObject ret = new JSObject();
      ret.put("online", result.online);
      if (result.online && result.rttMs >= 0) {
        ret.put("rtt", result.rttMs);
      }
      call.resolve(ret);
    });
  }

  @PluginMethod
  public void discover(PluginCall call) {
    JSArray portArray = call.getArray("ports");
    int timeout = call.getInt("timeout", 10000);
    List<Integer> ports = parsePorts(portArray);

    getBridge().execute(() -> {
      JSArray printers = new JSArray();
      Set<String> seen = Collections.newSetFromMap(new ConcurrentHashMap<String, Boolean>());

      discoverMdns(printers, seen, timeout);
      scanSubnet(printers, seen, ports, timeout);

      JSObject ret = new JSObject();
      ret.put("printers", printers);
      call.resolve(ret);
    });
  }

  private List<Integer> parsePorts(JSArray portArray) {
    if (portArray == null) {
      return new ArrayList<>(Arrays.asList(9100, 9101, 9102));
    }

    List<Integer> ports = new ArrayList<>();
    for (int i = 0; i < portArray.length(); i++) {
      int port = portArray.optInt(i, -1);
      if (port > 0) {
        ports.add(port);
      }
    }
    if (ports.isEmpty()) {
      ports.addAll(Arrays.asList(9100, 9101, 9102));
    }
    return ports;
  }

  private void scanSubnet(JSArray printers, Set<String> seen, List<Integer> ports, int timeoutMs) {
    String localIp = getLocalIpv4();
    if (localIp == null || !localIp.contains(".")) {
      return;
    }

    String prefix = localIp.substring(0, localIp.lastIndexOf('.'));
    ExecutorService executor = Executors.newFixedThreadPool(20);
    int perHostTimeout = Math.min(1000, Math.max(200, timeoutMs / 4));
    List<Future<?>> futures = new ArrayList<>();

    for (int i = 1; i <= 254; i++) {
      String targetIp = prefix + "." + i;
      futures.add(executor.submit(() -> {
        for (int port : ports) {
          PingResult result = pingHost(targetIp, port, perHostTimeout);
          if (result.online) {
            addPrinter(printers, seen, targetIp, port, "scan");
            break;
          }
        }
      }));
    }

    executor.shutdown();
    try {
      executor.awaitTermination(timeoutMs, TimeUnit.MILLISECONDS);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    }
  }

  private void discoverMdns(JSArray printers, Set<String> seen, int timeoutMs) {
    NsdManager nsdManager = (NsdManager) getContext().getSystemService(Context.NSD_SERVICE);
    if (nsdManager == null) {
      return;
    }

    String[] services = {"_pdl-datastream._tcp.", "_printer._tcp."};
    CountDownLatch latch = new CountDownLatch(services.length);
    Handler mainHandler = new Handler(Looper.getMainLooper());

    for (String service : services) {
      NsdManager.DiscoveryListener listener = new NsdManager.DiscoveryListener() {
        @Override
        public void onStartDiscoveryFailed(String serviceType, int errorCode) {
          latch.countDown();
          try {
            nsdManager.stopServiceDiscovery(this);
          } catch (Exception ignored) {}
        }

        @Override
        public void onStopDiscoveryFailed(String serviceType, int errorCode) {
          latch.countDown();
        }

        @Override
        public void onDiscoveryStarted(String serviceType) {}

        @Override
        public void onDiscoveryStopped(String serviceType) {
          latch.countDown();
        }

        @Override
        public void onServiceFound(NsdServiceInfo serviceInfo) {
          nsdManager.resolveService(serviceInfo, new NsdManager.ResolveListener() {
            @Override
            public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {}

            @Override
            public void onServiceResolved(NsdServiceInfo serviceInfo) {
              InetAddress host = serviceInfo.getHost();
              if (host != null && host instanceof Inet4Address) {
                addPrinter(printers, seen, host.getHostAddress(), serviceInfo.getPort(), "mdns");
              }
            }
          });
        }

        @Override
        public void onServiceLost(NsdServiceInfo serviceInfo) {}
      };

      mainHandler.post(() -> nsdManager.discoverServices(service, NsdManager.PROTOCOL_DNS_SD, listener));
      mainHandler.postDelayed(() -> {
        try {
          nsdManager.stopServiceDiscovery(listener);
        } catch (Exception ignored) {}
      }, timeoutMs);
    }

    try {
      latch.await(timeoutMs + 500, TimeUnit.MILLISECONDS);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    }
  }

  private String getLocalIpv4() {
    try {
      Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
      while (interfaces.hasMoreElements()) {
        NetworkInterface intf = interfaces.nextElement();
        if (!intf.isUp() || intf.isLoopback()) {
          continue;
        }
        Enumeration<InetAddress> addresses = intf.getInetAddresses();
        while (addresses.hasMoreElements()) {
          InetAddress address = addresses.nextElement();
          if (address instanceof Inet4Address && !address.isLoopbackAddress()) {
            return address.getHostAddress();
          }
        }
      }
    } catch (Exception ignored) {}
    return null;
  }

  private PingResult pingHost(String ip, int port, int timeoutMs) {
    long start = System.nanoTime();
    try (Socket socket = new Socket()) {
      socket.connect(new InetSocketAddress(ip, port), timeoutMs);
      long rtt = (System.nanoTime() - start) / 1_000_000L;
      return new PingResult(true, rtt);
    } catch (Exception e) {
      return new PingResult(false, -1);
    }
  }

  private void addPrinter(JSArray printers, Set<String> seen, String ip, int port, String source) {
    String key = ip + ":" + port + ":" + source;
    if (!seen.add(key)) {
      return;
    }

    JSObject obj = new JSObject();
    obj.put("ip", ip);
    obj.put("port", port);
    obj.put("source", source);
    synchronized (printers) {
      printers.put(obj);
    }
  }

  private static class PingResult {
    final boolean online;
    final long rttMs;

    PingResult(boolean online, long rttMs) {
      this.online = online;
      this.rttMs = rttMs;
    }
  }
}
