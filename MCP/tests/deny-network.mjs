// Test-only preload. If the stdio server attempts outbound networking, the test fails.
import net from "node:net";
import tls from "node:tls";
import http from "node:http";
import https from "node:https";
import dns from "node:dns";
import dgram from "node:dgram";
import { syncBuiltinESMExports } from "node:module";

const denied = () => { throw new Error("DAYVAULT_TEST_NETWORK_DENIED"); };
globalThis.fetch = denied;
net.connect = net.createConnection = denied;
net.Socket.prototype.connect = denied;
tls.connect = denied;
http.request = http.get = https.request = https.get = denied;
dns.lookup = dns.resolve = denied;
dns.promises.lookup = dns.promises.resolve = denied;
dgram.createSocket = denied;
syncBuiltinESMExports();
