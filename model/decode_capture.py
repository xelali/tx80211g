#!/usr/bin/env python3
"""Decode 802.11a/g legacy OFDM packets from an SDR capture with the reference receiver.

  decode_capture.py FILE [--fmt cf32|ci16|ci8] [--fs 20e6] [--max 50]

Samples are resampled to 20 Msps if --fs differs. Packet detection uses the short
training field autocorrelation (lag 16), then each packet goes through wifi.rx(),
which reports SIGNAL, EVM per symbol, pilot polarity mismatches and FCS.
"""
import argparse
import os
import sys
from fractions import Fraction

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wifi  # noqa: E402


def load(path, fmt):
    if fmt == "cf32":
        return np.fromfile(path, np.complex64).astype(complex)
    raw = np.fromfile(path, {"ci16": np.int16, "ci8": np.int8}[fmt]).astype(float)
    return raw[0::2] + 1j * raw[1::2]


def detect(x, thr=0.8, min_len=100):
    a = x[16:] * np.conj(x[:-16])
    p = np.abs(x[16:]) ** 2
    k = np.ones(48)
    c = np.abs(np.convolve(a, k, "valid")) / (np.convolve(p, k, "valid") + 1e-12)
    e = np.convolve(p, k, "valid")
    on = (c > thr) & (e > 10 * np.percentile(e, 5) + 1e-12)
    starts, i = [], 0
    while i < len(on):
        if on[i]:
            j = i
            while j < len(on) and on[j]:
                j += 1
            if j - i >= min_len:
                starts.append(i)
            i = j + 400
        else:
            i += 1
    return starts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--fmt", default="cf32", choices=["cf32", "ci16", "ci8"])
    ap.add_argument("--fs", type=float, default=20e6)
    ap.add_argument("--max", type=int, default=50)
    a = ap.parse_args()
    x = load(a.file, a.fmt)
    if a.fs != 20e6:
        from scipy.signal import resample_poly
        fr = Fraction(20e6 / a.fs).limit_denominator(1000)
        x = resample_poly(x, fr.numerator, fr.denominator)
    starts = detect(x)
    print(f"{len(x)} samples @20 Msps, {len(starts)} packet candidates")
    good = 0
    for n, s in enumerate(starts[:a.max]):
        seg = x[max(s - 32, 0):s + 400 + 80 * 700]
        r = wifi.rx(seg, search=400)
        good += r["ok"]
        msg = f"#{n:3d} @{s:9d}: "
        if "rate_code" not in r:
            print(msg + f"no SIGNAL ({r.get('error')})")
            continue
        msg += f"rate {r.get('mbps', '?')} len {r['length']} parity {'ok' if r['parity_ok'] else 'BAD'} " \
               f"CFO {r['cfo_hz'] / 1e3:+.1f} kHz SIG-EVM {r['signal_evm_db']:.1f} dB"
        if "evm_db" in r and len(r["evm_db"]):
            flips = sum(p != "++++" for p in r["pilot_match"])
            msg += f" data-EVM {np.mean(r['evm_db']):.1f} dB pilot-mismatch {flips}/{len(r['evm_db'])}"
        msg += f" FCS {'OK' if r.get('fcs_ok') else 'BAD'}" + (f" ({r['error']})" if "error" in r else "")
        print(msg)
    print(f"{good}/{min(len(starts), a.max)} decoded with good FCS")


if __name__ == "__main__":
    main()
