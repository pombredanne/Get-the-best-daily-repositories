#!/usr/bin/python3

import os
import sys
import stat
import time
import socket
import argparse
import unittest
import subprocess
from datetime import datetime

selfHost = ""
peerHost = ""
macUpper = "98:ed:5c"
peerMacL = ""
peerMacA = ""
selfMac  = ""
selfMacA = ""
selfDev  = ""
peerDev  = ""
selfLock = ""
peerLock = ""
verbose  = 0
connVCI  = "0"
tagSeqi  = "0"

modpath  = "/sys/module/modttpoe/parameters"
procpath = "/proc/net/modttpoe"

def getDev (nn):
    return "vl100"

def selfHostname():
    return subprocess.run (['uname', '-n'],
                           stdout=subprocess.PIPE).stdout.decode().strip()

def peerHostname (mac):
    if ((mac[0] != '0') or (mac[1] != '0') or (mac[2] != ':') or
        (mac[3] != '0') or (mac[4] != '0') or (mac[5] != ':')):
        print (f"Warning: Cannot resolve target={options.target} to hostname")
        return "node-unknown"
    else:
        return f"node-{mac[-2:]}"

def setUpModule():
    global peerHost
    global macUpper
    global peerMacL
    global peerMacA
    global selfMacL
    global selfMac
    global selfMacA
    global selfDev
    global peerDev
    global selfLock
    global peerLock
    global verbose
    global connVCI
    global tagSeqi

    if "-vv" in sys.argv[1:] or "--vverbose" in sys.argv[1:]:
        verbose = 2
    if "-v" in sys.argv[1:] or "--verbose" in sys.argv[1:]:
        verbose = 1

    if verbose:
        print (f"v---------------------------------------v")

    if verbose:
        print (f" Start tests: {datetime.now()}")
    if (options.self_dev):
        selfDev = options.self_dev
        if verbose:
            print (f"     SelfDev: {selfDev} (override)")
    else:
        selfDev = getDev (selfHostname())
        if verbose == 2:
            print (f"     selfDev: {selfDev} (default)")

    if (not options.target):
        print (f"Error: Missing --target")
        sys.exit (-1)

    if (options.vci):
        connVCI = options.vci

    if (connVCI != "0" and connVCI != "1" and connVCI != "2"):
        print (f"Error: Invalid vci {connVCI}")
        sys.exit (-1)

    cmd = (f"ip link show dev {selfDev}")
    out = subprocess.run (str.split (cmd), stdout=subprocess.PIPE)
    if (out.returncode):
        print (f"Error: {cmd} failed")
        sys.exit (-1)

    selfMac = str(out.stdout.split()[-3], encoding='utf-8')
    rarg = selfMac.split(':')
    if ((rarg[-6] != "98") and (rarg[-5] != "ed") and (rarg[-4] != "5c")):
        print (f"Error: '{selfDev}' is not a TTP device: {selfMac}")
        sys.exit (-1)

    selfMacA = f"{rarg[-3]}{rarg[-2]}{rarg[-1]}"

#    print (f"{selfMacA} <- selfMacA")
#    sys.exit (-1)

    targ = options.target.split(':')
    if (len(targ) == 1):
        peerMacL = ":00:00"
        peerMacA = "0000"
    elif (len(targ) == 2):
        peerMacL = ":00"
        peerMacA = "00"
    elif (len(targ) == 3):
        peerMacL = ""
        peerMacA = ""
    else:
        print (f"Error: Bad --target='{options.target}'")
        sys.exit (-1)

    for tt in targ:
        if (len(tt) == 1):
            peerMacL = f"{peerMacL}:0{tt}"
            peerMacA = f"{peerMacA}0{tt}"
        elif (len(tt) == 2):
            peerMacL = f"{peerMacL}:{tt}"
            peerMacA = f"{peerMacA}{tt}"
        else:
            print (f"Error: Bad --target='{options.target}'")
            sys.exit (-1)
    peerMacL = peerMacL[1:]

    if not options.no_remote:
        peerHost = peerHostname (peerMacL)
    else:
        print (f"--no-remote: skipping ssh remote '{peerHost}'")

    if (peerHost == selfHostname()):
        print (f"Error: Self --target='{options.target}'")
        sys.exit (-1)

    if os.path.exists ("/dev/noc_debug"):
        po = subprocess.run (['file', '/dev/noc_debug'],
                             stdout=subprocess.PIPE).stdout.decode().strip()
        if ("character special (446/0)" not in po):
            print (f"Error: 'self' /dev/noc_debug not 'char' dev (446/0) (UNEXPECTED)")
            sys.exit (-1)

    if peerHost:
        po = subprocess.run (['ssh', peerHost, 'ls', '/dev/noc_debug', '2>/dev/null'],
                             stdout=subprocess.PIPE).stdout.decode().strip()
        if ("/dev/noc_debug" in po):
            po = subprocess.run (['ssh', peerHost, 'file', '/dev/noc_debug'],
                                 stdout=subprocess.PIPE).stdout.decode().strip()
            if ("character special (446/0)" not in po):
                print (f"Error: 'peer' /dev/noc_debug not 'char' dev (446/0) (UNEXPECTED)")
                sys.exit (-1)

    selfLock = f"/mnt/mac/.locks/ttp-host-lock-{selfHostname}"
    try:
        os.open (selfLock, os.O_CREAT | os.O_EXCL, stat.S_IRUSR)
    except FileExistsError as e:
        print (f"Error: selfHost already locked ({selfLock} exists)")
        sys.exit (-1)

    if peerHost:
        peerLock = f"/mnt/mac/.locks/ttp-host-lock-{peerHost}"
        try:
            os.open (peerLock, os.O_CREAT | os.O_EXCL, stat.S_IRUSR)
        except FileExistsError as e:
            print (f"Error: {peerHost} already locked ({peerLock} exists)")
            os.remove (selfLock)
            sys.exit (-1)

    if verbose:
        print (f"   Self Host: {selfHostname()}")
        print (f"    MAC addr: {selfMac}")
        print (f"   Peer Host: {peerHost}")
        print (f" Use Gateway: {options.use_gw}")
        print (f"  L MAC addr: {macUpper}:{peerMacL}")
        print (f"  A MAC addr: {macUpper}:{peerMacA}")
        if options.vci:
            print (f"    Conn VCI: {connVCI}")
        else:
            if verbose == 2:
                print (f"    Conn VCI: 0 (default)")
        print (f"     Verbose: {verbose}")

    if (options.peer_dev):
        peerDev = options.peer_dev
        if verbose:
            print (f"     PeerDev: {peerDev} (override)")
    else:
        peerDev = getDev (options.target)
        if verbose == 2:
            print (f"     PeerDev: {peerDev} (default)")

    if peerHost:
        rv = os.system (f"ssh {peerHost} 'ifconfig {peerDev} 1>/dev/null'")
        if (rv != 0):
            print (f"Error: Peer device '{peerDev}' not found")
            os.remove (selfLock)
            os.remove (peerLock)
            sys.exit (-1)

    if (options.no_load):
        print (f"Skipping local module reload in setup:-")
    else:
        rv = os.system (f"sudo insmod /mnt/mac/modttpoe.ko"
                        f" verbose={verbose} dev={selfDev}")
        if (rv != 0):
            print (f"Error: 'insmod modttpoe' on 'self' failed")
            os.remove (selfLock)
            os.remove (peerLock)
            sys.exit (-1)
        # set vc (first) and target on 'self'
        if options.vci:
            rv = os.system (f"echo {connVCI} |"
                            f" sudo tee {modpath}/vci 1>/dev/null")
            if (rv != 0):
                print (f"Error: Set vci on 'self' failed")
                tearDownModule()
                sys.exit (-1)

        lct = 10
        while (options.use_gw and lct):
            pf = open (f"/sys/module/modttpoe/parameters/gwmac", "r")
            pfo = pf.read().strip()
            pf.close()
            if verbose == 2:
                print (f" GW MAC addr: {pfo}")
            if pfo == "00:00:00:00:00:00":
                time.sleep (1)
                lct = lct - 1
                continue

            print (f" GW MAC addr: {pfo}")
            rv = os.system (f"echo 1 |"
                            f" sudo tee {modpath}/use_gw 1>/dev/null")
            if (rv != 0):
                print (f"Error: Set use_gw on 'self' failed")
                tearDownModule()
                sys.exit (-1)
            break

        if lct == 0:
            print (f"Error: Detect gateway on 'self' failed")
            tearDownModule()
            sys.exit (-1)

        rv = os.system (f"echo {peerMacA} |"
                        f" sudo tee {modpath}/target 1>/dev/null")
        if (rv != 0):
            print (f"Error: Set target on 'self' failed")
            tearDownModule()
            sys.exit (-1)

    tagSeqi = int(subprocess.run (["cat", f"{modpath}/tag_seq"],
                                  stdout=subprocess.PIPE).stdout.decode().strip())

    if tagSeqi != 1:
        if verbose:
            print (f"     Tag Seq: {tagSeqi} (override)")
    elif verbose == 2:
        print (f"     Tag Seq: {tagSeqi} (default)")

    if (options.no_load):
        print (f"Skipping peer module reload in setup:-")
    else:
        if peerHost:
            rv = os.system (f"ssh {peerHost}"
                            f" 'sudo insmod /mnt/mac/modttpoe.ko"
                            f" verbose={verbose} dev={peerDev}'")
            if (rv != 0):
                print (f"Error: 'insmod modttpoe' on 'peer' failed")
                os.system ("sudo rmmod modttpoe 1>/dev/null")
                os.remove (selfLock)
                os.remove (peerLock)
                sys.exit (-1)

    # to test setting peer target.vci in setup-module (change 0 --> 1 to enable)
    if (0):
        # set vc (first) and target on 'peer'
        if options.vci:
            if peerHost:
                rv = os.system (f"ssh {peerHost} 'echo {connVCI} |"
                                f" sudo tee {modpath}/vci 1>/dev/null'")
                if (rv != 0):
                    print (f"Error: Set vci {connVCI} on 'peer' failed")
                    tearDownModule()
                    sys.exit (-1)
            rv = os.system (f"ssh {peerHost} 'echo {selfMacA} |"
                        f" sudo tee {modpath}/target 1>/dev/null'")
            if (rv != 0):
                print (f"Error: Set target {selfMacA} on 'peer' failed")
                tearDownModule()
                sys.exit (-1)

    # exit early control (change 0 --> 1 to enable)
    if (0):
        if verbose:
            print (f"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
            tearDownModule()
            sys.exit (f"DEBUG: Exit early (disable condition to proceed..)")


def tearDownModule():
    if verbose == 2:
        print (f"**** Waiting 10 sec before tear-down:-\n"
               f" Hit ^C to stop and examine state before modules are unloaded.")
        time.sleep (10)

    if (options.no_unload):
        print (f"Skipping local and peer module unload in tear-down:-")
    else:
        os.system (f"sudo rmmod modttpoe 1>/dev/null")
        if peerHost:
            os.system (f"ssh {peerHost} 'sudo rmmod modttpoe 1>/dev/null'")
    os.remove (selfLock)
    if peerHost:
        os.remove (peerLock)

# This "Test0_Seq_IDs" test-suite needs to be the first test to run, as it checks RX and TX seq-IDs
# which depend on how many payloads were sent and received.
#@unittest.skip ("<comment>")
class Test0_Seq_IDs (unittest.TestCase):

    #@unittest.skip (f"skip close with EOF")
    def test1_seq_clr (self):
        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")

    #@unittest.skip ("<comment>")
    def test2_tx1_seq (self):
        if (options.no_load):
            self.skipTest (f"requires module reload")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"cat /mnt/mac/tests/greet | sudo tee /dev/noc_debug > /dev/null")
        time.sleep (1.0)
        x = os.system (f"ssh {peerHost} 'diff /dev/noc_debug /mnt/mac/tests/greet'")
        if x != 0:
            self.fail (f"received file did not match sent file 'greet'")
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        needle = f" {tagSeqi:7}  {(tagSeqi+2):7}  {(tagSeqi+1):7}  "
        if verbose == 2:
            print()
            print (pfo)
        if needle not in pfo or peerMacL not in pfo:
            self.fail (f"did not find proper TX seq_ID (expected {needle})")
        os.system (f"cat /mnt/mac/tests/greet | sudo tee /dev/noc_debug > /dev/null")
        time.sleep (0.1)
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        needle = f" {tagSeqi:7}  {(tagSeqi+3):7}  {(tagSeqi+2):7}"
        if verbose == 2:
            print()
            print (pfo)
        if needle not in pfo or peerMacL not in pfo:
            self.fail (f"did not find proper TX seq_ID (expected 4)")
        pf = open (f"{modpath}/stats", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            for ll in pfo.split ("\n"):
                if "skb_" in ll:
                    print (ll)
        if "skb_ct: 0" not in pfo or "skb_rx: 3" not in pfo:
            self.fail (f"did not find proper [skb, rx] count (expected [0, 3])")

    #@unittest.skip ("<comment>")
    def test3_rx1_seq (self):
        if (options.no_load):
            self.skipTest (f"requires module reload")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        # set vc (first) and target on 'peer'
        if options.vci:
            rv = os.system (f"ssh {peerHost} 'echo {connVCI} "
                            f" | sudo tee {modpath}/vci 1>/dev/null'")
            if (rv != 0):
                self.fail (f"Error: Set vci {connVCI} on 'peer' failed")
        rv = os.system (f"ssh {peerHost} 'echo {selfMacA} "
                        f" | sudo tee {modpath}/target 1>/dev/null'")
        if (rv != 0):
            self.fail (f"Error: Set target {selfMacA} on 'peer' failed")

        os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
        os.system (f"ssh {peerHost} 'cat /mnt/mac/tests/greet |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        time.sleep (0.1)
        os.system (f"diff /dev/noc_debug /mnt/mac/tests/greet")
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        needle = f" {(tagSeqi+1):7}  {(tagSeqi+3):7}  {(tagSeqi+2):7}"
        if verbose == 2:
            print()
            print (pfo)
        if needle not in pfo or peerMacL not in pfo:
            self.fail (f"did not find proper RX seq_ID (expected rx:2)")
        os.system (f"ssh {peerHost} 'cat /mnt/mac/tests/greet |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        time.sleep (0.1)
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        needle = f" {(tagSeqi+2):7}  {(tagSeqi+3):7}  {(tagSeqi+2):7}"
        if verbose == 2:
            print()
            print (pfo)
        if needle not in pfo or peerMacL not in pfo:
            self.fail (f"did not find proper RX seq_ID (expected rx:3)")

    #@unittest.skip ("<comment>")
    def test4_tx2_seq (self):
        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
        time.sleep (0.1)
        os.system (f"ssh {peerHost} 'cat /mnt/mac/tests/4000 |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        os.system (f"ssh {peerHost} 'echo -n expect-this-to-be-dropped |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        time.sleep (0.1)
        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")


#@unittest.skip ("<comment>")
class Test1_Proc (unittest.TestCase):

    def test1_proc_stats (self):
        if verbose == 2:
            print()
            pf = open (f"{modpath}/stats", "r")
            print (pf.read())
            pf.close()
        else:
            os.system (f"cat {modpath}/stats > /dev/null")

    #@unittest.skip ("<comment>")
    def test2_ttpoe_tags (self):
        if verbose == 2:
            print()
            pf = open (f"{procpath}/tags", "r")
            print (pf.read())
            pf.close()
        else:
            os.system (f"cat {procpath}/tags > /dev/null")

    #@unittest.skip ("<comment>")
    def test3_debug__500 (self):
        if (options.no_load):
            self.skipTest (f"requires module reload")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        time.sleep (0.1)
        os.system (f"cat /mnt/mac/tests/500 | sudo tee /dev/noc_debug > /dev/null")
        time.sleep (0.1)
        x = os.system (f"ssh {peerHost} 'diff /dev/noc_debug /mnt/mac/tests/500'")
        if x != 0:
            self.fail (f"received file did not match sent file '500'")


    #@unittest.skip ("<comment>")
    def test4_debug_1000 (self):
        if (options.no_load):
            self.skipTest ("requires module reload")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        time.sleep (0.1)
        os.system (f"cat /mnt/mac/tests/1000 | sudo tee /dev/noc_debug > /dev/null")
        time.sleep (0.1)
        x = os.system (f"ssh {peerHost} 'diff /dev/noc_debug /mnt/mac/tests/1000'")
        if x != 0:
            self.fail (f"received file did not match sent file '1000'")


    #@unittest.skip ("<comment>")
    def test5_debug_2000 (self):
        if (options.no_load):
            self.skipTest (f"requires module reload")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        time.sleep (0.1)
        os.system (f"cat /mnt/mac/tests/2000 | sudo tee /dev/noc_debug > /dev/null")
        time.sleep (0.1)
        x = os.system (f"ssh {peerHost} 'diff /dev/noc_debug /mnt/mac/tests/2000'")
        if x != 0:
            self.fail (f"received file did not match sent file '2000'")


    #@unittest.skip ("<comment>")
    def test6_debug_3000 (self):
        if (options.no_load):
            self.skipTest (f"requires module reload")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        time.sleep (0.1)
        os.system (f"cat /mnt/mac/tests/3000 | sudo tee /dev/noc_debug > /dev/null")
        time.sleep (0.1)
        x = os.system (f"ssh {peerHost} 'diff /dev/noc_debug /mnt/mac/tests/3000'")
        if x != 0:
            self.fail (f"received file did not match sent file '3000'")


    #@unittest.skip ("<comment>")
    def test7_debug_4000 (self):
        if (options.no_load):
            self.skipTest (f"requires module reload")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        time.sleep (0.1)
        os.system (f"cat /mnt/mac/tests/4000 | sudo tee /dev/noc_debug > /dev/null")
        time.sleep (1.1)
        x = os.system (f"ssh {peerHost} 'diff /dev/noc_debug /mnt/mac/tests/4000'")
        if x != 0:
            self.fail (f"received file did not match sent file '4000'")


#@unittest.skip ("<comment>")
class Test2_Packet (unittest.TestCase):

    def test1_get_open (self):
        if (options.no_packet):
            self.skipTest (f"no packet tests")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost}"
                   f" 'cd /tmp; sudo trafgen -p -o {peerDev} "
                   f" -i /mnt/mac/tests/ttp_common.cfg -n 1"
                   f" -D DST_MAC=\"{selfMac}\""
                   f" -D SRC_MAC=\"{macUpper}:{peerMacL}\""
                   f" -D SVTR=5"
                   f" -D TOTLN=\"c16(46)\""
                   f" -D SRC_NODE=\"0,0,x{selfMacA}\""
                   f" -D DST_NODE=\"0,0,x{peerMacA}\""
                   f" -D NOCLN=\"c16(26)\""
                   f" -D CODE=0"
                   f" -D VCID=\"c8({connVCI})\""
                   f" -D TXID=\"c32(2)\" "
                   f" -D RXID=\"c32(1)\" "
                   f" -D PAYLOAD=\\\""
                   f"hello-tesla-OPEN"
                   f"\\\" > /dev/null'")
        time.sleep (0.1)
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            print (pfo)
        if "OP" not in pfo or peerMacL not in pfo:
            self.fail ("did not find proper tag")

    #@unittest.skip ("<comment>")
    def test2_snd_open (self):
        if (options.no_packet):
            self.skipTest (f"no packet tests")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"cd /tmp; sudo trafgen -p -o {selfDev}"
                   f" -i /mnt/mac/tests/ttp_common.cfg -n 1"
                   f" -D DST_MAC=\"{macUpper}:{peerMacL}\""
                   f" -D SRC_MAC=\"{selfMac}\""
                   f" -D SVTR=5"
                   f" -D TOTLN=\"c16(46)\""
                   f" -D SRC_NODE=\"0,0,x{selfMacA}\""
                   f" -D DST_NODE=\"0,0,x{peerMacA}\""
                   f" -D NOCLN=\"c16(26)\""
                   f" -D CODE=0"
                   f" -D VCID=\"c8({connVCI})\""
                   f" -D TXID=\"c32(2)\" "
                   f" -D RXID=\"c32(1)\" "
                   f" -D PAYLOAD=\\\""
                   f"hello-tesla-OPEN"
                   f"\\\" > /dev/null")
        time.sleep (0.1)
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            print (pfo)
        if "OP" not in pfo or peerMacL not in pfo:
            self.fail (f"did not find proper tag")

    #@unittest.skip ("<comment>")
    def test3_get_pyld (self):
        if (options.no_packet):
            self.skipTest (f"no packet tests")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost}"
                   f" 'cd /tmp; sudo trafgen -p -o {peerDev}"
                   f" -i /mnt/mac/tests/ttp_common.cfg -n 5 -t 100ms"
                   f" -D DST_MAC=\"{selfMac}\""
                   f" -D SRC_MAC=\"{macUpper}:{peerMacL}\""
                   f" -D SVTR=5"
                   f" -D TOTLN=\"c16(690)\""
                   f" -D SRC_NODE=\"0,0,x{selfMacA}\""
                   f" -D DST_NODE=\"0,0,x{peerMacA}\""
                   f" -D NOCLN=\"c16(670)\""
                   f" -D CODE=6"
                   f" -D VCID=\"c8({connVCI})\""
                   f" -D TXID=\"c32(2)\" "
                   f" -D RXID=\"c32(1)\" "
                   f" -D PAYLOAD=\\\""
                   f"Wikipedia\\ is\\ an\\ online\\ open-content\\ collaborative\\ encyclopedia,"
                   f"\\ that\\ is,\\ a\\ voluntary\\ association\\ of\\ individuals\\ and\\ groups"
                   f"\\ working\\ to\\ develop\\ a\\ common\\ resource\\ of\\ human\\ knowledge."
                   f"\\ The\\ structure\\ of\\ the\\ project\\ allows\\ anyone\\ with\\ an\\ Internet"
                   f"\\ connection\\ to\\ alter\\ its\\ content.\\ Please\\ be\\ advised\\ that"
                   f"\\ nothing\\ found\\ here\\ has\\ necessarily\\ been\\ reviewed\\ by\\ people"
                   f"\\ with\\ the\\ expertise\\ required\\ to\\ provide\\ you\\ with\\ complete,"
                   f"\\ accurate,\\ or\\ reliable\\ information.\\ That\\ is\\ not\\ to\\ say\\ that"
                   f"\\ you\\ will\\ not\\ find\\ valuable\\ and\\ accurate\\ information\\ in"
                   f"\\ Wikipedia,\\ much\\ of\\ the\\ time\\ you\\ will.\\ However,\\ Wikipedia"
                   f"\\ cannot\\ guarantee\\ the\\ validity\\ of\\ the\\ information\\ found\\ here."
                   f"\\\" > /dev/null'")
        time.sleep (0.1)
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            print (pfo)
        if "OP" not in pfo or peerMacL not in pfo:
            self.fail (f"did not find proper tag")

    #@unittest.skip ("<comment>")
    def test4_snd_pyld (self):
        if (options.no_packet):
            self.skipTest (f"no packet tests")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"cd /tmp; sudo trafgen -p -o {selfDev}"
                   f" -i /mnt/mac/tests/ttp_common.cfg -n 5 -t 100ms"
                   f" -D DST_MAC=\"{macUpper}:{peerMacL}\""
                   f" -D SRC_MAC=\"{selfMac}\""
                   f" -D SVTR=5"
                   f" -D TOTLN=\"c16(690)\""
                   f" -D SRC_NODE=\"0,0,x{selfMacA}\""
                   f" -D DST_NODE=\"0,0,x{peerMacA}\""
                   f" -D NOCLN=\"c16(670)\""
                   f" -D CODE=6"
                   f" -D VCID=\"c8({connVCI})\""
                   f" -D TXID=\"c32(2)\" "
                   f" -D RXID=\"c32(1)\" "
                   f" -D PAYLOAD=\\\""
                   f"Wikipedia\\ is\\ an\\ online\\ open-content\\ collaborative\\ encyclopedia,"
                   f"\\ that\\ is,\\ a\\ voluntary\\ association\\ of\\ individuals\\ and\\ groups"
                   f"\\ working\\ to\\ develop\\ a\\ common\\ resource\\ of\\ human\\ knowledge."
                   f"\\ The\\ structure\\ of\\ the\\ project\\ allows\\ anyone\\ with\\ an\\ Internet"
                   f"\\ connection\\ to\\ alter\\ its\\ content.\\ Please\\ be\\ advised\\ that"
                   f"\\ nothing\\ found\\ here\\ has\\ necessarily\\ been\\ reviewed\\ by\\ people"
                   f"\\ with\\ the\\ expertise\\ required\\ to\\ provide\\ you\\ with\\ complete,"
                   f"\\ accurate,\\ or\\ reliable\\ information.\\ That\\ is\\ not\\ to\\ say\\ that"
                   f"\\ you\\ will\\ not\\ find\\ valuable\\ and\\ accurate\\ information\\ in"
                   f"\\ Wikipedia,\\ much\\ of\\ the\\ time\\ you\\ will.\\ However,\\ Wikipedia"
                   f"\\ cannot\\ guarantee\\ the\\ validity\\ of\\ the\\ information\\ found\\ here."
                   f"\\\" > /dev/null")
        time.sleep (0.1)
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            print (pfo)
        if "OP" not in pfo or peerMacL not in pfo:
            self.fail (f"did not find proper tag")

    #@unittest.skip ("<comment>")
    def test5_get_clos (self):
        if (options.no_packet):
            self.skipTest (f"--no-packet specified")

        if (options.use_gw):
            self.skipTest (f"--use_gw specified")

        if (options.no_load):
            self.skipTest (f"requires module reload")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost}"
                   f" 'cd /tmp; sudo trafgen -p -o {peerDev}"
                   f" -i /mnt/mac/tests/ttp_common.cfg -n 1"
                   f" -D DST_MAC=\"{selfMac}\""
                   f" -D SRC_MAC=\"{macUpper}:{peerMacL}\""
                   f" -D SVTR=5"
                   f" -D TOTLN=\"c16(46)\""
                   f" -D SRC_NODE=\"0,0,x{peerMacA}\""
                   f" -D DST_NODE=\"0,0,x{selfMacA}\""
                   f" -D NOCLN=\"c16(26)\""
                   f" -D CODE=3"
                   f" -D VCID=\"c8({connVCI})\""
                   f" -D TXID=\"c32(2)\" "
                   f" -D RXID=\"c32(1)\" "
                   f" -D PAYLOAD=\\\""
                   f"hello-tesla-CLOSE"
                   f"\\\" > /dev/null'")
        time.sleep (0.1)
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            print (pfo)
        if "OP" in pfo and peerMacL in pfo:
            self.fail (f"found unexpected tag")

    #@unittest.skip ("<comment>")
    def test6_snd_clos (self):
        if (options.no_packet):
            self.skipTest (f"--no-packet specified")

        if (options.use_gw):
            self.skipTest (f"--use_gw specified")

        if (options.no_load):
            self.skipTest (f"requires module reload")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"cd /tmp; sudo trafgen -p -o {selfDev}"
                   f" -i /mnt/mac/tests/ttp_common.cfg -n 1"
                   f" -D DST_MAC=\"{macUpper}:{peerMacL}\""
                   f" -D SRC_MAC=\"{selfMac}\""
                   f" -D SVTR=5"
                   f" -D TOTLN=\"c16(46)\""
                   f" -D SRC_NODE=\"0,0,x{selfMacA}\""
                   f" -D DST_NODE=\"0,0,x{peerMacA}\""
                   f" -D NOCLN=\"c16(26)\""
                   f" -D CODE=3"
                   f" -D VCID=\"c8({connVCI})\""
                   f" -D TXID=\"c32(2)\" "
                   f" -D RXID=\"c32(1)\" "
                   f" -D PAYLOAD=\\\""
                   f"hello-tesla-CLOSE"
                   f"\\\" > /dev/null")
        time.sleep (0.1)
        pf = open (f"{procpath}/tags", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            print (pfo)
        if "OP" in pfo and peerMacL in pfo:
            self.fail (f"found unexpected tag")


#@unittest.skip ("<comment>")
class Test3_Noc_db (unittest.TestCase):

    def test1_show_tag (self):
        if not peerHost:
            self.skipTest (f"--no-remote specified")

        if verbose == 2:
            print()
            os.system (f"cat {procpath}/tags")
            print()
            os.system (f"ssh {peerHost} 'cat {procpath}/tags'")

    #@unittest.skip ("<comment>")
    def test2_show_dbg (self):
        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
        os.system (f"cat /mnt/mac/tests/greet | sudo tee /dev/noc_debug > /dev/null")
        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        os.system (f"ssh {peerHost} 'cat /mnt/mac/tests/greet |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        if verbose == 2:
            print()
            os.system (f"cat /dev/noc_debug")
            print()
            os.system (f"ssh {peerHost} 'cat /dev/noc_debug'")


#@unittest.skip ("<comment>")
class Test4_Traffic (unittest.TestCase):

    #@unittest.skip ("<comment>")
    def test1_traffic (self):
        if (options.no_traffic):
            self.skipTest (f"no traffic")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
        os.system (f"cat /mnt/mac/tests/500 | sudo tee /dev/noc_debug > /dev/null")

    def test2_traffic (self):
        if (options.no_traffic):
            self.skipTest (f"no traffic")

        if (options.traffic):
            ra = int(options.traffic)
            if (ra < 0 or ra > 10):
                ra = 10
        else:
            ra = 10

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        for rep in range (1, ra):
            os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
            os.system (f"cat /mnt/mac/tests/1000 | sudo tee /dev/noc_debug > /dev/null")

    #@unittest.skip ("<comment>")
    def test3_traffic (self):
        if (options.no_traffic):
            self.skipTest (f"no traffic")

        if (options.traffic):
            self.skipTest (f"no big traffic")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        for rep in range (1, 100):
            os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
            os.system (f"cat /mnt/mac/tests/2000 | sudo tee /dev/noc_debug > /dev/null")

    def test4_traffic (self):
        if (options.no_traffic):
            self.skipTest (f"no traffic")

        if (options.traffic):
            self.skipTest (f"no big traffic")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        for rep in range (1, 20):
            os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
            os.system (f"cat /mnt/mac/tests/3000 | sudo tee /dev/noc_debug > /dev/null")

    def test5_traffic (self):
        if (options.no_traffic):
            self.skipTest (f"no traffic")

        if (options.traffic):
            self.skipTest (f"no big traffic")

        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat /dev/null |"
                   f" sudo tee /dev/noc_debug > /dev/null'")
        for rep in range (1, 100): # crashes when using 190
            os.system (f"cat /dev/null | sudo tee /dev/noc_debug > /dev/null")
            os.system (f"cat /mnt/mac/tests/4000 | sudo tee /dev/noc_debug > /dev/null")

#@unittest.skip ("<comment>")
class Test5_Cleanup (unittest.TestCase):

    def test1_cleanup (self):
        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat {procpath}/tags' > /tmp/peer_tags")
        time.sleep (0.1)
        pf = open ("/tmp/peer_tags", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            print (pfo)
        if "OP" in pfo and peerMacL in pfo:
            self.fail (f"peer: found unexpected tag")

    #@unittest.skip ("<comment>")
    def test2_cleanup (self):
        time.sleep (0.1)
        pf = open (f"{modpath}/stats", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            print (pfo)
        if "skb_ct: 0" not in pfo:
            self.fail (f"local skb_ct expected 0")

    def test3_cleanup (self):
        time.sleep (0.1)
        if not peerHost:
            self.skipTest (f"--no-remote specified")

        os.system (f"ssh {peerHost} 'cat {modpath}/stats' > /tmp/peer_stats")
        pf = open (f"/tmp/peer_stats", "r")
        pfo = pf.read()
        pf.close()
        if verbose == 2:
            print()
            print (pfo)
        if "skb_ct: 0" not in pfo:
            self.fail (f"peer: skb_ct expected 0")


if __name__ == '__main__':
    parser = argparse.ArgumentParser (add_help=False)
    parser.add_argument ('--self-dev')                        # [--self-dev=<dev>]
    parser.add_argument ('--peer-dev')                        # [--peer-dev=<dev>]
    parser.add_argument ('--vci')                             # [--vci=<vc>]
    parser.add_argument ('--target')                          # [--target=<NN>]
    parser.add_argument ('--use-gw', action='store_true')     # [--use-gw]
    parser.add_argument ('--no-unload', action='store_true')  # [--no-unload]
    parser.add_argument ('--no-load', action='store_true')    # [--no-load]
    parser.add_argument ('--no-traffic', action='store_true') # [--no-traffic]
    parser.add_argument ('--traffic')                         # [--traffic=<NN>]
    parser.add_argument ('--no-packet', action='store_true')  # [--no-packet]
    parser.add_argument ('--no-remote', action='store_true')  # [--no-remote]

    options, args = parser.parse_known_args()
    sys.argv[1:] = args

    unittest.main()
