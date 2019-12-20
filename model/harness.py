#!/usr/bin/env python3
"""Test harness glue for the Tx80211 RTL simulation.

  harness.py stim  --out DIR [--len N] [--mbps R] [--extra N] [--seed S]
      Build a MAC data frame exactly like sw/tx80211.c and write
      DIR/fifo.hex (what the DMA pushes into the core), DIR/signal.txt, DIR/psdu.bin

  harness.py check --out DIR [--snr DB] [--trials N]
      Parse the xsim dumps in DIR, compare them stage by stage with the golden
      model, decode the waveform with the reference receiver.
"""
import argparse
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wifi  # noqa: E402

ADDR = bytes([0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
SEED_RTL = 0b1011101  # tx_controller.v default scrambler_seed
RTL_SCALE = 256.0     # RTL output LSBs per unit of the standard's normalisation


# ------------------------------------------------------------------ software model
def mac_frame(msdu, seq):
    """generate_mac_data_frame() from tx80211.c (little-endian ARM struct)"""
    hdr = struct.pack("<HH6s6s6sH", 0x0008, 0, ADDR, ADDR, ADDR, seq)
    body = hdr + bytes(msdu)
    return body + wifi.fcs(body)


def sw_fifo_bytes(psdu, extra):
    """What tx_80211() DMAs into the FIFO, one byte per 64-bit word: SERVICE + PSDU
    (tail/pad come from hardware), plus `extra` leftover bytes the core must drain."""
    return b"\0\0" + bytes(psdu) + bytes(extra)


def sw_signal(L, mbps):
    code = wifi.MBPS_TO_CODE[mbps]
    sig = sum(int(c) << i for i, c in enumerate(code))
    sig |= (L & 0xFFF) << 5
    sig |= (bin(sig).count("1") & 1) << 17
    return sig


# ------------------------------------------------------------------ dump parsing
def load(path, ncols):
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        return np.zeros((0, ncols), int)
    return np.loadtxt(path, dtype=int, ndmin=2)


def frames_from_stream(out):
    """split tx_out.txt (valid re im per clk) into frames of valid samples"""
    d = load(os.path.join(out, "tx_out.txt"), 3)
    v = d[:, 0].astype(bool)
    x = (d[:, 1] + 1j * d[:, 2])
    frames, gaps = [], []
    i = 0
    while i < len(v):
        if not v[i]:
            i += 1
            continue
        j = i
        # a frame ends after 200 consecutive idle cycles; shorter holes are recorded as gaps
        while j < len(v):
            if v[j]:
                j += 1
                continue
            k = j
            while k < len(v) and not v[k]:
                k += 1
            if k - j >= 200 or k == len(v):
                break
            gaps.append((len(frames), j - i, k - j))
            j = k
        frames.append((x[i:j], v[i:j]))
        i = j
    return frames, gaps


# ------------------------------------------------------------------ checks
def compare_bits(name, rtl, ref, show=True):
    n = min(len(rtl), len(ref))
    err = np.flatnonzero(rtl[:n] != ref[:n])
    status = "OK " if len(err) == 0 and len(rtl) == len(ref) else "BAD"
    msg = f"  [{status}] {name:<22} rtl={len(rtl):6d} ref={len(ref):6d} mismatches={len(err)}"
    if len(err):
        msg += f" first@{err[0]}"
    if show:
        print(msg)
    return len(err) == 0 and len(rtl) == len(ref)


def check(out, snr_list, trials):
    psdu = open(os.path.join(out, "psdu.bin"), "rb").read()
    meta = dict(line.split("=", 1) for line in open(os.path.join(out, "signal.txt")).read().split())
    mbps = int(meta["mbps"])
    L = len(psdu)
    ref_wave, st = wifi.tx(psdu, mbps, seed=SEED_RTL, return_stages=True)
    code = wifi.MBPS_TO_CODE[mbps]
    _, nbpsc, ncbps, ndbps, rate = wifi.RATES[code]
    print(f"== {out}: PSDU {L} bytes @ {mbps} Mbps, reference {st['nsym']} data symbols")

    nfr = max(1, sum(1 for l in open(os.path.join(out, "events.txt")) if " fire " in l))
    ns = st['nsym']
    print(f"-- stage comparison against golden model ({nfr} frame(s), each checked separately)")
    scr = load(os.path.join(out, "tap_scrambler.txt"), 1)[:, 0]
    conv = load(os.path.join(out, "tap_conv.txt"), 2)[:, 0]
    itv = load(os.path.join(out, "tap_itv.txt"), 1)[:, 0]
    mod = load(os.path.join(out, "tap_mod.txt"), 3)
    mod = mod[:, 0] + 1j * mod[:, 1]
    sig = load(os.path.join(out, "tap_sig_mod.txt"), 3)[:, 0]
    fin = load(os.path.join(out, "tap_ifft_in.txt"), 2)
    fin = (fin[:, 0] + 1j * fin[:, 1]) / 64
    sig_ref = np.real(st['sig_mod'] * 64).astype(int)
    pil, dat = wifi.bins(wifi.PILOT_SC), wifi.bins(wifi.DATA_SC)
    stages = [("scrambler out (+tail)", scr, st['scrambled'], 0),
              ("conv encoder+puncture", conv, st['coded'], 0),
              ("interleaver", itv, st['interleaved'], 0),
              ("constellation", mod, st['mod'] * 64, 3),
              ("SIGNAL field symbols", sig, sig_ref, 0)]
    for name, rtl, ref, tol in stages:
        n, bad, first = len(ref), 0, None
        for f in range(nfr):
            seg = rtl[f * n:(f + 1) * n]
            e = np.flatnonzero(np.abs(seg - ref[:len(seg)]) > tol) if len(seg) else []
            if len(seg) != n or len(e):
                bad += 1
                first = first or (f, len(seg), int(e[0]) if len(e) else None)
        print(f"  [{'OK ' if not bad else 'BAD'}] {name:<22} {n:6d} per frame, total {len(rtl):6d}, "
              f"bad frames {bad}/{nfr}" + (f" (frame {first[0]}: len {first[1]} first mismatch {first[2]})" if first else ""))
        if name.startswith("scrambler"):
            for f in range(min(nfr, 1)):
                tl = scr[f * n + 16 + 8 * L:f * n + 16 + 8 * L + 6]
                print(f"         tail bits after scrambler, frame {f} (must be 000000): {''.join(map(str, tl))}")
    X = fin[:len(fin) // 64 * 64].reshape(-1, 64)
    bad_p = bad_d = 0
    for f in range(nfr):
        for i in range(ns + 1):
            k = f * (ns + 1) + i
            if k >= len(X):
                bad_p += 1
                continue
            e = np.sign(np.real(st['freq'][i, pil])).astype(int)
            g = np.sign(np.real(X[k, pil])).astype(int)
            if not np.array_equal(e, g):
                bad_p += 1
                if bad_p <= 4:
                    print(f"     frame {f} sym {i:3d}: pilots expected {e.tolist()} got {g.tolist()}")
            bad_d += not np.allclose(X[k, dat], st['freq'][i, dat], atol=0.05)
    print(f"  [{'OK ' if bad_p == 0 else 'BAD'}] {'pilot polarity':<22} {bad_p} of {nfr * (ns + 1)} OFDM symbols wrong")
    print(f"  [{'OK ' if bad_d == 0 else 'BAD'}] {'IFFT input data bins':<22} {bad_d} of {nfr * (ns + 1)} OFDM symbols wrong")

    fo = load(os.path.join(out, "tap_ifft_out.txt"), 4)
    if len(fo):
        full = fo[:, 0] + 1j * fo[:, 1]
        print(f"  IFFT out (16 bit, before truncation to 8): max |re|,|im| = {np.abs(fo[:, 0]).max()}, "
              f"{np.abs(fo[:, 1]).max()}; {int(np.sum((np.abs(fo[:, 0]) > 127) | (np.abs(fo[:, 1]) > 127)))} "
              f"samples would wrap; overflow flag {int(fo[:, 3].sum())}; rms {np.sqrt(np.mean(np.abs(full) ** 2)):.1f} LSB")

    # ---- output waveform
    frames, gaps = frames_from_stream(out)
    print(f"-- output: {len(frames)} frame(s); holes in tx_valid inside frames: {len(gaps)}")
    for g in gaps[:5]:
        print(f"     frame {g[0]}: tx_valid low at sample {g[1]} for {g[2]} cycles")
    if not frames:
        print("  no output!")
        return
    segs = [("STS", 0, 160), ("LTS", 160, 320), ("SIGNAL", 320, 400)] + \
           [(f"DATA{i}", 400 + 80 * i, 480 + 80 * i) for i in range(st['nsym'])]
    print("  per-segment SNR of RTL vs golden waveform, dB (8-bit quantisation limit ~35):")
    for fi, (fx, _) in enumerate(frames):
        x = fx / RTL_SCALE
        n = min(len(x), len(ref_wave))
        line = []
        for name, a, b in segs:
            if b > n:
                line.append(f"{name}:missing")
                continue
            e = x[a:b] - ref_wave[a:b]
            line.append((name, 10 * np.log10(np.sum(np.abs(ref_wave[a:b]) ** 2) / max(np.sum(np.abs(e) ** 2), 1e-20))))
        worst = min((l for l in line if isinstance(l, tuple)), key=lambda t: t[1])
        miss = [l for l in line if isinstance(l, str)]
        print(f"     frame {fi}: {len(x)} samples (ref {len(ref_wave)}), worst segment {worst[0]} {worst[1]:.1f} dB"
              + (f", {miss}" if miss else ""))
        if fi == 0 and worst[1] < 30:
            txt = [f"{l[0]}:{l[1]:.0f}" if isinstance(l, tuple) else l for l in line]
            for i in range(0, len(txt), 10):
                print("        " + " ".join(txt[i:i + 10]))
    x = frames[0][0] / RTL_SCALE

    # ---- receiver
    pad = np.zeros(100)
    nok = 0
    for fi, (fx, _) in enumerate(frames):
        r = wifi.rx(np.concatenate([pad, fx / RTL_SCALE, pad]))
        nok += r["ok"]
        if fi == 0 or not r["ok"]:
            report_rx(f"frame {fi} noiseless", r, psdu)
    print(f"-- RX summary: {nok}/{len(frames)} frames decoded with good FCS (noiseless)")
    rng = np.random.default_rng(7)
    for snr in snr_list:
        ok = 0
        for _ in range(trials):
            y = np.concatenate([pad, x, pad])
            p = np.mean(np.abs(x[320:]) ** 2)
            y = y + np.sqrt(p / 10 ** (snr / 10) / 2) * (rng.normal(size=len(y)) + 1j * rng.normal(size=len(y)))
            ok += wifi.rx(y)["ok"]
        gref = 0
        for _ in range(trials):
            y = np.concatenate([pad, ref_wave, pad])
            p = np.mean(np.abs(ref_wave[320:]) ** 2)
            y = y + np.sqrt(p / 10 ** (snr / 10) / 2) * (rng.normal(size=len(y)) + 1j * rng.normal(size=len(y)))
            gref += wifi.rx(y)["ok"]
        print(f"  AWGN {snr:4.1f} dB: RTL PER {1 - ok / trials:5.2f}   golden PER {1 - gref / trials:5.2f}  ({trials} trials)")


def report_rx(tag, r, psdu):
    print(f"-- RX {tag}: ok={r['ok']} {r.get('error', '')}")
    if "rate_code" in r:
        print(f"     SIGNAL {r['signal_bits']} rate={r.get('mbps')} len={r['length']} parity_ok={r['parity_ok']}"
              f" EVM {r['signal_evm_db']:.1f} dB")
    if "evm_db" in r:
        ev = np.array(r["evm_db"])
        print(f"     data EVM dB: mean {ev.mean():.1f}, worst {ev.max():.1f} (sym {int(ev.argmax())})")
        flips = [i for i, s in enumerate(r["pilot_match"]) if s != "++++"]
        print(f"     symbols with unexpected pilot polarity: {len(flips)}/{len(ev)}"
              + (f" e.g. {[(i, r['pilot_match'][i]) for i in flips[:4]]}" if flips else ""))
        ph = np.degrees(np.array(r["pilot_phase"]))
        print(f"     pilot phase estimate deg: max |.| = {np.abs(ph).max():.0f}")
        print(f"     SERVICE {r['service_bits']} seed {r['scrambler_seed']:#x}  tail(scrambled domain) {r['tail_bits']}"
              f"  viterbi best end state {r['viterbi']['best_end_state']}")
        got = r["psdu"]
        be = np.sum(wifi.bytes_to_bits(got) != wifi.bytes_to_bits(psdu[:len(got)])) if len(got) == len(psdu) else -1
        print(f"     FCS ok={r['fcs_ok']}  bit errors vs sent PSDU: {be}")


# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("stim")
    s.add_argument("--out", required=True)
    s.add_argument("--len", type=int, default=100, help="MSDU length")
    s.add_argument("--mbps", type=int, default=6)
    s.add_argument("--extra", type=int, default=0, help="random bytes left in the FIFO after the frame")
    s.add_argument("--seed", type=int, default=1)
    c = sub.add_parser("check")
    c.add_argument("--out", required=True)
    c.add_argument("--snr", type=float, nargs="*", default=[])
    c.add_argument("--trials", type=int, default=20)
    a = ap.parse_args()
    if a.cmd == "stim":
        os.makedirs(a.out, exist_ok=True)
        rng = np.random.default_rng(a.seed)
        msdu = bytes(rng.integers(0, 256, a.len, dtype=np.uint8))
        psdu = mac_frame(msdu, a.seed)
        fb = sw_fifo_bytes(psdu, rng.integers(0, 256, a.extra, dtype=np.uint8))
        with open(os.path.join(a.out, "fifo.hex"), "w") as f:
            f.write("\n".join(f"{b:02x}" for b in fb) + "\n")
        open(os.path.join(a.out, "psdu.bin"), "wb").write(psdu)
        sig = sw_signal(len(psdu), a.mbps)
        open(os.path.join(a.out, "signal.txt"), "w").write(f"signal={sig:06x} mbps={a.mbps} len={len(psdu)}\n")
        print(f"{sig:06x}")
    else:
        check(a.out, a.snr, a.trials)


if __name__ == "__main__":
    main()
