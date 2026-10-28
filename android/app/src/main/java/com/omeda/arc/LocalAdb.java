/*
 * Arc TV
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

package com.omeda.arc;

import android.util.Base64;

import java.io.ByteArrayOutputStream;
import java.io.Closeable;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.math.BigInteger;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.Charset;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.RSAKeyGenParameterSpec;
import java.security.spec.X509EncodedKeySpec;

import javax.crypto.Cipher;

/**
 * A minimal ADB client for the classic TCP transport (the "adb connect host:5555" protocol),
 * used by Arc TV to run a few package-manager commands on the TV it is installed on.
 * The TV shows its usual "Allow USB debugging?" prompt the first time.
 */
final class LocalAdb implements Closeable {

    interface Listener {
        void onWaitingForApproval();
    }

    private static final int A_CNXN = 0x4e584e43;
    private static final int A_AUTH = 0x48545541;
    private static final int A_OPEN = 0x4e45504f;
    private static final int A_OKAY = 0x59414b4f;
    private static final int A_CLSE = 0x45534c43;
    private static final int A_WRTE = 0x45545257;
    private static final int A_STLS = 0x534c5453;

    private static final int VERSION = 0x01000001;
    private static final int MAX_PAYLOAD = 256 * 1024;

    private static final int AUTH_TOKEN = 1;
    private static final int AUTH_SIGNATURE = 2;
    private static final int AUTH_RSAPUBLICKEY = 3;

    private static final int KEY_BYTES = 256; // 2048-bit RSA
    private static final Charset UTF8 = Charset.forName("UTF-8");

    /** ASN.1 DigestInfo prefix for SHA-1; adb signs the 20-byte token as if it were a SHA-1 digest. */
    private static final byte[] SHA1_DIGEST_INFO = new byte[] {
            0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14
    };

    private final Socket socket;
    private final DataInputStream in;
    private final OutputStream out;
    private int nextLocalId = 1;

    private LocalAdb(Socket socket) throws IOException {
        this.socket = socket;
        this.in = new DataInputStream(socket.getInputStream());
        this.out = socket.getOutputStream();
    }

    static LocalAdb connect(String host, int port, KeyPair keys, Listener listener) throws IOException {
        Socket socket = new Socket();
        try {
            socket.connect(new InetSocketAddress(host, port), 3000);
            socket.setTcpNoDelay(true);
        } catch (IOException e) {
            try {
                socket.close();
            } catch (IOException ignored) {
            }
            throw e;
        }
        LocalAdb adb = new LocalAdb(socket);
        try {
            adb.handshake(keys, listener);
        } catch (java.net.SocketTimeoutException e) {
            adb.close();
            // Reported separately from connection timeouts so callers do not retry another address.
            throw new IOException("No answer from the TV in time. Try again and approve the \"Allow USB debugging?\" prompt.", e);
        } catch (IOException | RuntimeException e) {
            adb.close();
            throw e;
        }
        return adb;
    }

    private void handshake(KeyPair keys, Listener listener) throws IOException {
        socket.setSoTimeout(10000);
        send(A_CNXN, VERSION, MAX_PAYLOAD, "host::arc-tv\0".getBytes(UTF8));
        boolean signatureSent = false;
        boolean keySent = false;
        while (true) {
            Message message = read();
            if (message.command == A_CNXN) {
                return;
            }
            if (message.command == A_STLS) {
                throw new IOException("This TV only accepts encrypted (wireless debugging) connections.");
            }
            if (message.command != A_AUTH || message.arg0 != AUTH_TOKEN) {
                continue;
            }
            if (!signatureSent) {
                send(A_AUTH, AUTH_SIGNATURE, 0, sign(keys.getPrivate(), message.payload));
                signatureSent = true;
            } else if (!keySent) {
                send(A_AUTH, AUTH_RSAPUBLICKEY, 0, publicKeyPayload((RSAPublicKey) keys.getPublic()));
                keySent = true;
                if (listener != null) {
                    listener.onWaitingForApproval();
                }
                // Give the person time to answer the prompt on the TV.
                socket.setSoTimeout(120000);
            } else {
                throw new IOException("Debugging permission was not granted on the TV.");
            }
        }
    }

    /** Runs a shell command and returns its output (stdout and stderr). */
    String shell(String command, int timeoutMs) throws IOException {
        int localId = nextLocalId++;
        send(A_OPEN, localId, 0, ("shell:" + command + "\0").getBytes(UTF8));
        socket.setSoTimeout(timeoutMs);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        while (true) {
            Message message = read();
            if (message.arg1 != localId) {
                continue;
            }
            if (message.command == A_WRTE) {
                output.write(message.payload);
                send(A_OKAY, localId, message.arg0, null);
            } else if (message.command == A_CLSE) {
                break;
            }
            // A_OKAY: the stream was opened or our acknowledgement was received.
        }
        return new String(output.toByteArray(), UTF8);
    }

    @Override
    public void close() {
        try {
            socket.close();
        } catch (IOException ignored) {
        }
    }

    private static final class Message {
        final int command;
        final int arg0;
        final int arg1;
        final byte[] payload;

        Message(int command, int arg0, int arg1, byte[] payload) {
            this.command = command;
            this.arg0 = arg0;
            this.arg1 = arg1;
            this.payload = payload;
        }
    }

    private Message read() throws IOException {
        byte[] header = new byte[24];
        in.readFully(header);
        ByteBuffer buffer = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN);
        int command = buffer.getInt();
        int arg0 = buffer.getInt();
        int arg1 = buffer.getInt();
        int length = buffer.getInt();
        buffer.getInt(); // checksum (not verified by modern adbd either)
        int magic = buffer.getInt();
        if (magic != ~command) {
            throw new IOException("Unexpected data from the debugging service.");
        }
        if (length < 0 || length > 16 * 1024 * 1024) {
            throw new IOException("Unexpected message size from the debugging service.");
        }
        byte[] payload = new byte[length];
        in.readFully(payload);
        return new Message(command, arg0, arg1, payload);
    }

    private void send(int command, int arg0, int arg1, byte[] payload) throws IOException {
        int length = payload == null ? 0 : payload.length;
        ByteBuffer buffer = ByteBuffer.allocate(24 + length).order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(command);
        buffer.putInt(arg0);
        buffer.putInt(arg1);
        buffer.putInt(length);
        buffer.putInt(checksum(payload));
        buffer.putInt(~command);
        if (length > 0) {
            buffer.put(payload);
        }
        out.write(buffer.array());
        out.flush();
    }

    private static int checksum(byte[] payload) {
        int sum = 0;
        if (payload != null) {
            for (byte b : payload) {
                sum += b & 0xff;
            }
        }
        return sum;
    }

    // ---- RSA authentication ----------------------------------------------------------------

    static byte[] sign(PrivateKey key, byte[] token) throws IOException {
        int dataLength = SHA1_DIGEST_INFO.length + token.length;
        if (dataLength > KEY_BYTES - 11) {
            throw new IOException("Unexpected authentication token.");
        }
        // EMSA-PKCS1-v1_5 block: 00 01 FF..FF 00 || DigestInfo(SHA-1) || token
        byte[] block = new byte[KEY_BYTES];
        block[0] = 0x00;
        block[1] = 0x01;
        int separator = KEY_BYTES - dataLength - 1;
        for (int i = 2; i < separator; i++) {
            block[i] = (byte) 0xff;
        }
        block[separator] = 0x00;
        System.arraycopy(SHA1_DIGEST_INFO, 0, block, separator + 1, SHA1_DIGEST_INFO.length);
        System.arraycopy(token, 0, block, separator + 1 + SHA1_DIGEST_INFO.length, token.length);
        try {
            Cipher cipher = Cipher.getInstance("RSA/ECB/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key);
            return cipher.doFinal(block);
        } catch (GeneralSecurityException e) {
            throw new IOException("Could not sign the debugging challenge.", e);
        }
    }

    /** Encodes the public key in adb's format: base64(RSAPublicKey struct) + " name" + NUL. */
    static byte[] publicKeyPayload(RSAPublicKey publicKey) {
        BigInteger modulus = publicKey.getModulus();
        BigInteger r32 = BigInteger.ONE.shiftLeft(32);
        BigInteger n0inv = r32.subtract(modulus.mod(r32).modInverse(r32));
        BigInteger rr = BigInteger.ONE.shiftLeft(KEY_BYTES * 8 * 2).mod(modulus);

        ByteBuffer struct = ByteBuffer.allocate(4 + 4 + KEY_BYTES + KEY_BYTES + 4).order(ByteOrder.LITTLE_ENDIAN);
        struct.putInt(KEY_BYTES / 4);
        struct.putInt(n0inv.intValue());
        struct.put(littleEndian(modulus));
        struct.put(littleEndian(rr));
        struct.putInt(publicKey.getPublicExponent().intValue());

        String encoded = Base64.encodeToString(struct.array(), Base64.NO_WRAP);
        return (encoded + " arc-tv@tv\0").getBytes(UTF8);
    }

    private static byte[] littleEndian(BigInteger value) {
        byte[] bigEndian = value.toByteArray();
        byte[] result = new byte[KEY_BYTES];
        for (int i = 0; i < KEY_BYTES && i < bigEndian.length; i++) {
            result[i] = bigEndian[bigEndian.length - 1 - i];
        }
        return result;
    }

    /** Loads this app's adb key pair, creating it on first use. */
    static KeyPair loadOrCreateKeys(File directory) throws IOException {
        File privateFile = new File(directory, "adbkey.pk8");
        File publicFile = new File(directory, "adbkey.x509");
        try {
            KeyFactory factory = KeyFactory.getInstance("RSA");
            if (privateFile.exists() && publicFile.exists()) {
                PrivateKey privateKey = factory.generatePrivate(new PKCS8EncodedKeySpec(readFile(privateFile)));
                PublicKey publicKey = factory.generatePublic(new X509EncodedKeySpec(readFile(publicFile)));
                return new KeyPair(publicKey, privateKey);
            }
            KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
            generator.initialize(new RSAKeyGenParameterSpec(KEY_BYTES * 8, RSAKeyGenParameterSpec.F4));
            KeyPair keys = generator.generateKeyPair();
            if (!directory.exists() && !directory.mkdirs()) {
                throw new IOException("Could not create " + directory);
            }
            writeFile(privateFile, keys.getPrivate().getEncoded());
            writeFile(publicFile, keys.getPublic().getEncoded());
            return keys;
        } catch (GeneralSecurityException e) {
            throw new IOException("Could not create the debugging key.", e);
        }
    }

    private static byte[] readFile(File file) throws IOException {
        InputStream input = new FileInputStream(file);
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int count;
            while ((count = input.read(buffer)) != -1) {
                output.write(buffer, 0, count);
            }
            return output.toByteArray();
        } finally {
            input.close();
        }
    }

    private static void writeFile(File file, byte[] data) throws IOException {
        OutputStream output = new FileOutputStream(file);
        try {
            output.write(data);
        } finally {
            output.close();
        }
    }
}
