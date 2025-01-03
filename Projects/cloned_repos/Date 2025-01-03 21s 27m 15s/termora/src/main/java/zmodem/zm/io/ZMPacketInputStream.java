package zmodem.zm.io;

import zmodem.xfer.io.ObjectInputStream;
import zmodem.xfer.util.ByteBuffer;
import zmodem.xfer.util.CRC;
import zmodem.xfer.zm.packet.*;
import zmodem.xfer.zm.proto.Action;
import zmodem.xfer.zm.proto.Escape;
import zmodem.xfer.zm.util.ZMPacket;
import zmodem.xfer.zm.util.ZModemCharacter;

import java.io.IOException;
import java.io.InputStream;


public class ZMPacketInputStream extends ObjectInputStream<ZMPacket> {

    private final InputStream netIs;
    private CRC dataCRC = new CRC(CRC.Type.CRC16);
    private boolean gotFIN = false;
    private boolean acceptsHeader = true;

    public ZMPacketInputStream(InputStream is) {
        netIs = is;
    }

    private boolean ignored(int b) {
        return b == 0x11 || b == 0x13 || b == 0x91 || b == 0x93;
    }

    private byte implRead() throws IOException {
        int n;
        do {
            n = netIs.read();
        } while (ignored(n));

        if (n == -1) {
            throw new IOException("Closed");
        }

        return (byte) n;
    }

    @Override
    public ZMPacket read() throws IOException {
        ByteBuffer zbuff = ByteBuffer.allocate(1024 * 10);
        boolean doread = true;
        Action action = Action.ESCAPE;

        int beforeStop = -1;
        int countCan = 0;

        while (doread) {
            byte n = implRead();

            if (gotFIN && n == 'O') {
                n = implRead();
                if (n == 'O') {
                    return new Finish();
                }
            }

            if (n == ZModemCharacter.ZDLE.value()) {
                n = (byte) netIs.read();

                if (n == ZModemCharacter.ZDLE.value())
                    countCan += 2;
                else
                    countCan = 0;

                Escape escape = Escape.detect(n, acceptsHeader);

                if (escape.action() != Action.ESCAPE && beforeStop < 0) {
                    action = escape.action();

                    if (escape.action() == Action.DATA)
                        beforeStop = dataCRC.size();
                    else
                        beforeStop = escape.len();

                    dataCRC.update(n);
                } else {
                    n = Escape.escapeIt(n);
                }

            }
            zbuff.put(n);

            if (beforeStop < 0)
                dataCRC.update(n);

            if (beforeStop == 0)
                doread = false;

            if (beforeStop > 0)
                beforeStop--;

            if (countCan >= 5) {
                doread = false;
                action = Action.CANCEL;
            }

        }
        zbuff.flip();

        ZMPacket r = null;
        switch (action) {
            case HEADER:
                r = Header.unmarshall(zbuff);


                if (((Header) r).format() == Format.BIN32)
                    dataCRC = new CRC(CRC.Type.CRC32);
                else
                    dataCRC = new CRC(CRC.Type.CRC16);

                if (((Header) r).type() == ZModemCharacter.ZFIN)
                    gotFIN = true;
                if (((Header) r).type() == ZModemCharacter.ZDATA || ((Header) r).type() == ZModemCharacter.ZFILE)
                    acceptsHeader = false;

                break;
            case DATA:
                dataCRC.finalized();

                r = DataPacket.unmarshall(zbuff, dataCRC);

                dataCRC = new CRC(dataCRC.type());

                if (((DataPacket) r).type() == ZModemCharacter.ZCRCG)
                    acceptsHeader = false;
                else
                    acceptsHeader = true;

                break;
            case CANCEL:
                r = new Cancel();
                dataCRC = new CRC(dataCRC.type());
                break;
        }

        return r;
    }

}
