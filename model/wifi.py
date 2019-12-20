"""IEEE 802.11a (legacy OFDM, 20 MHz) reference transmitter and receiver.

Written from the standard (IEEE 802.11-2016 clause 17) so it can serve as a
golden model for the RTL and as a receiver for simulated or captured waveforms.
All sample streams are complex numpy arrays at 20 Msps, normalised so that
x = ifft(X) with numpy's 1/64 factor (the standard's convention).
"""
import zlib
import numpy as np

# rate code (R1..R4 as written in the standard, R1 first) -> parameters
RATES = {
    #  code   Mbps  Nbpsc Ncbps Ndbps  coding
    "1101": (6,  1, 48,  24,  (1, 2)),
    "1111": (9,  1, 48,  36,  (3, 4)),
    "0101": (12, 2, 96,  48,  (1, 2)),
    "0111": (18, 2, 96,  72,  (3, 4)),
    "1001": (24, 4, 192, 96,  (1, 2)),
    "1011": (36, 4, 192, 144, (3, 4)),
    "0001": (48, 6, 288, 192, (2, 3)),
    "0011": (54, 6, 288, 216, (3, 4)),
}
MBPS_TO_CODE = {v[0]: k for k, v in RATES.items()}

DATA_SC = [k for k in range(-26, 27) if k not in (0, -21, -7, 7, 21)]
PILOT_SC = [-21, -7, 7, 21]
PILOT_BASE = np.array([1, 1, 1, -1], dtype=float)

LTS_F = np.array([1, 1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 1, 1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 0,
                  1, -1, -1, 1, 1, -1, 1, -1, 1, -1, -1, -1, -1, -1, 1, 1, -1, -1, 1, -1, 1, -1, 1, 1, 1, 1],
                 dtype=complex)  # k = -26..26
STS_F = np.sqrt(13 / 6) * np.array(
    [0, 0, 1 + 1j, 0, 0, 0, -1 - 1j, 0, 0, 0, 1 + 1j, 0, 0, 0, -1 - 1j, 0, 0, 0, -1 - 1j, 0, 0, 0, 1 + 1j, 0, 0, 0,
     0, 0, 0, 0, -1 - 1j, 0, 0, 0, -1 - 1j, 0, 0, 0, 1 + 1j, 0, 0, 0, 1 + 1j, 0, 0, 0, 1 + 1j, 0, 0, 0, 1 + 1j, 0, 0])


def bins(sc):
    """subcarrier index (-32..31) -> FFT bin"""
    return np.asarray(sc) % 64


def spectrum(f53):
    X = np.zeros(64, complex)
    X[bins(np.arange(-26, 27))] = f53
    return X


# ---------------------------------------------------------------- bit helpers
def bytes_to_bits(b):
    return np.unpackbits(np.frombuffer(bytes(b), np.uint8), bitorder="little")


def bits_to_bytes(bits):
    return np.packbits(np.asarray(bits, np.uint8), bitorder="little").tobytes()


def fcs(data):
    return zlib.crc32(bytes(data)).to_bytes(4, "little")


def fcs_ok(psdu):
    return len(psdu) >= 4 and fcs(psdu[:-4]) == bytes(psdu[-4:])


# ---------------------------------------------------------------- scrambler
def scrambler_seq(state7, n):
    """state7 = [x7, x6, ..., x1] (x7 is the oldest bit). Returns n output bits."""
    s = list(state7)
    out = np.zeros(n, np.uint8)
    for i in range(n):
        fb = s[0] ^ s[3]  # x7 ^ x4
        out[i] = fb
        s = s[1:] + [fb]
    return out


def seed_bits(seed_int):
    """seed as the RTL writes it, scrambler[7:1] = seed -> [x7..x1]"""
    return [(seed_int >> i) & 1 for i in range(6, -1, -1)]


PILOT_POLARITY = 1 - 2 * scrambler_seq([1] * 7, 127).astype(float)  # p_0 .. p_126


# ---------------------------------------------------------------- conv code
def _parity(x):
    return bin(x).count("1") & 1


# state: 6 bits, bit5 = most recent input. window = (u << 6) | state; bit6 = delay 0
_G0, _G1 = 0o133, 0o171
_OUT = np.array([[(_parity(((u << 6) | s) & _G0), _parity(((u << 6) | s) & _G1)) for u in (0, 1)]
                 for s in range(64)], np.uint8)  # [state][u] -> (A, B)


def conv_encode(bits):
    s = 0
    out = np.zeros(2 * len(bits), np.uint8)
    for i, u in enumerate(bits):
        out[2 * i], out[2 * i + 1] = _OUT[s][u]
        s = ((u << 6) | s) >> 1
    return out


PUNCT = {(1, 2): [1, 1], (3, 4): [1, 1, 1, 0, 0, 1], (2, 3): [1, 1, 1, 0]}


def puncture(coded, rate):
    p = np.array(PUNCT[rate], bool)
    return coded[np.resize(p, len(coded))]


def depuncture(soft, rate, n_coded):
    p = np.array(PUNCT[rate], bool)
    mask = np.resize(p, n_coded)
    out = np.zeros(n_coded)
    out[mask] = soft[:mask.sum()]
    return out


def viterbi(soft, force_zero=True):
    """soft: pairs (A,B) interleaved, positive = bit 1, 0 = erasure.
    Returns (bits, final_state_metric_info)."""
    n = len(soft) // 2
    y = soft[:2 * n].reshape(n, 2)
    ns = np.arange(64)
    u = ns >> 5
    prev = np.stack([((ns << 1) & 63) | b for b in (0, 1)])  # [2][64]
    outs = np.stack([_OUT[prev[b], u] for b in (0, 1)]).astype(float) * 2 - 1  # [2][64][2]
    metric = np.full(64, -1e18)
    metric[0] = 0
    dec = np.zeros((n, 64), np.uint8)
    for t in range(n):
        m = metric[prev] + outs[..., 0] * y[t, 0] + outs[..., 1] * y[t, 1]  # [2][64]
        b = (m[1] > m[0]).astype(np.uint8)
        dec[t] = b
        metric = np.where(b, m[1], m[0])
    best = int(np.argmax(metric))
    state = 0 if force_zero else best
    bits = np.zeros(n, np.uint8)
    for t in range(n - 1, -1, -1):
        bits[t] = state >> 5
        state = prev[dec[t, state], state]
    return bits, {"best_end_state": best, "metric_gap_state0": float(metric[best] - metric[0])}


# ---------------------------------------------------------------- interleaver
def interleave_perm(ncbps, nbpsc):
    s = max(nbpsc // 2, 1)
    k = np.arange(ncbps)
    i = (ncbps // 16) * (k % 16) + k // 16
    j = s * (i // s) + (i + ncbps - (16 * i) // ncbps) % s
    return j  # coded bit k goes to position j


def interleave(bits, ncbps, nbpsc):
    j = interleave_perm(ncbps, nbpsc)
    out = np.zeros_like(bits)
    for n in range(len(bits) // ncbps):
        blk = bits[n * ncbps:(n + 1) * ncbps]
        o = np.zeros_like(blk)
        o[j] = blk
        out[n * ncbps:(n + 1) * ncbps] = o
    return out


def deinterleave(soft, ncbps, nbpsc):
    j = interleave_perm(ncbps, nbpsc)
    out = np.zeros_like(soft)
    for n in range(len(soft) // ncbps):
        out[n * ncbps:(n + 1) * ncbps] = soft[n * ncbps:(n + 1) * ncbps][j]
    return out


# ---------------------------------------------------------------- mapping
_PAM = {1: {(0,): -1, (1,): 1},
        2: {(0, 0): -3, (0, 1): -1, (1, 1): 1, (1, 0): 3},
        3: {(0, 0, 0): -7, (0, 0, 1): -5, (0, 1, 1): -3, (0, 1, 0): -1,
            (1, 1, 0): 1, (1, 1, 1): 3, (1, 0, 1): 5, (1, 0, 0): 7}}
KMOD = {1: 1.0, 2: 1 / np.sqrt(2), 4: 1 / np.sqrt(10), 6: 1 / np.sqrt(42)}


def constellation(nbpsc):
    """returns (points[2^nbpsc], bits[2^nbpsc][nbpsc])"""
    pts, bl = [], []
    for v in range(2 ** nbpsc):
        b = [(v >> (nbpsc - 1 - i)) & 1 for i in range(nbpsc)]
        if nbpsc == 1:
            p = _PAM[1][(b[0],)]
        else:
            h = nbpsc // 2
            p = _PAM[h][tuple(b[:h])] + 1j * _PAM[h][tuple(b[h:])]
        pts.append(p * KMOD[nbpsc])
        bl.append(b)
    return np.array(pts, complex), np.array(bl, np.uint8)


def modulate(bits, nbpsc):
    pts, bl = constellation(nbpsc)
    w = 1 << np.arange(nbpsc - 1, -1, -1)
    idx = bits.reshape(-1, nbpsc) @ w
    lut = np.zeros(2 ** nbpsc, complex)
    for p, b in zip(pts, bl):
        lut[b @ w] = p
    return lut[idx]


def demap_llr(sym, nbpsc, noise_var=1.0):
    """max-log LLR, positive = bit 1"""
    pts, bl = constellation(nbpsc)
    d = np.abs(sym[:, None] - pts[None, :]) ** 2
    llr = np.zeros((len(sym), nbpsc))
    for i in range(nbpsc):
        d1 = np.where(bl[:, i] == 1, d, np.inf).min(1)
        d0 = np.where(bl[:, i] == 0, d, np.inf).min(1)
        llr[:, i] = (d0 - d1) / noise_var
    return llr.reshape(-1)


# ---------------------------------------------------------------- OFDM
def ofdm_symbol_freq(data48, n):
    """data48: 48 complex data symbols; n: symbol index for pilot polarity (0 = SIGNAL)"""
    X = np.zeros(64, complex)
    X[bins(DATA_SC)] = data48
    X[bins(PILOT_SC)] = PILOT_BASE * PILOT_POLARITY[n % 127]
    return X


def _windowed(seg_body, ext):
    """seg with +1 sample periodic extension, raised-edge window (T_TR = 100 ns)"""
    s = np.concatenate([seg_body, [ext]])
    s[0] *= 0.5
    s[-1] *= 0.5
    return s


def overlap_add(segments):
    out = np.zeros(sum(len(s) - 1 for s in segments) + 1, complex)
    pos = 0
    for s in segments:
        out[pos:pos + len(s)] += s
        pos += len(s) - 1
    return out


def preamble_segments():
    sts = np.fft.ifft(spectrum(STS_F))
    lts = np.fft.ifft(spectrum(LTS_F))
    sts_seg = _windowed(np.tile(sts, 10)[:160], sts[0])
    lts_seg = _windowed(np.concatenate([lts[32:], lts, lts]), lts[0])
    return [sts_seg, lts_seg]


def symbol_segment(X):
    x = np.fft.ifft(X)
    return _windowed(np.concatenate([x[48:], x]), x[0])


def signal_bits(rate_code, length):
    b = [int(c) for c in rate_code] + [0] + [(length >> i) & 1 for i in range(12)]
    b += [sum(b) & 1] + [0] * 6
    return np.array(b, np.uint8)


def tx(psdu, mbps=6, seed=0b1011101, zero_tail=True, return_stages=False):
    """Standard-compliant PPDU. Returns complex samples (and intermediate stages)."""
    code = MBPS_TO_CODE[mbps]
    _, nbpsc, ncbps, ndbps, rate = RATES[code]
    L = len(psdu)
    nsym = -(-(16 + 8 * L + 6) // ndbps)
    ndata = nsym * ndbps
    bits = np.zeros(ndata, np.uint8)
    bits[16:16 + 8 * L] = bytes_to_bits(psdu)
    scr = bits ^ scrambler_seq(seed_bits(seed), ndata)
    if zero_tail:
        scr[16 + 8 * L:16 + 8 * L + 6] = 0
    coded = puncture(conv_encode(scr), rate)
    itv = interleave(coded, ncbps, nbpsc)
    syms = modulate(itv, nbpsc)

    sig = signal_bits(code, L)
    sig_coded = conv_encode(sig)
    sig_itv = interleave(sig_coded, 48, 1)
    sig_syms = modulate(sig_itv, 1)

    Xs = [ofdm_symbol_freq(sig_syms, 0)]
    Xs += [ofdm_symbol_freq(syms[n * 48:(n + 1) * 48], n + 1) for n in range(nsym)]
    segs = preamble_segments() + [symbol_segment(X) for X in Xs]
    wave = overlap_add(segs)
    if return_stages:
        return wave, dict(scrambled=scr, coded=coded, interleaved=itv, mod=syms, sig_mod=sig_syms,
                          freq=np.array(Xs), nsym=nsym, sig_bits=sig)
    return wave


# ---------------------------------------------------------------- receiver
def rx(samples, verbose=False, cfo_correct=True, force_zero_tail=True, search=None):
    """Decode one PPDU from a complex sample stream. Returns a report dict."""
    r = np.asarray(samples, complex)
    rep = {"ok": False}
    lts_t = np.fft.ifft(spectrum(LTS_F))
    if len(r) < 400:
        rep["error"] = "too short"
        return rep
    # fine timing: cross-correlate with one LTS period, pick the pair of peaks 64 apart
    xc = np.abs(np.correlate(r, lts_t, "valid"))
    pair = xc[:-64] + xc[64:]
    if search is not None:
        pair = pair[:search]
    t1 = int(np.argmax(pair))
    rep["lts_start"] = t1
    # CFO from the two LTS copies
    l1, l2 = r[t1:t1 + 64], r[t1 + 64:t1 + 128]
    cfo = np.angle(np.vdot(l1, l2)) / 64 if cfo_correct else 0.0
    rep["cfo_rad_per_sample"] = cfo
    rep["cfo_hz"] = cfo * 20e6 / (2 * np.pi)
    n = np.arange(len(r))
    r = r * np.exp(-1j * cfo * (n - t1))
    l1, l2 = r[t1:t1 + 64], r[t1 + 64:t1 + 128]
    Lf = (np.fft.fft(l1) + np.fft.fft(l2)) / 2
    H = np.ones(64, complex)
    used = bins(np.arange(-26, 27))
    ref = spectrum(LTS_F)
    nz = used[ref[used] != 0]
    H[nz] = Lf[nz] / ref[nz]
    rep["lts_snr_db"] = 10 * np.log10(np.sum(np.abs(Lf[nz]) ** 2) /
                                      max(np.sum(np.abs(np.fft.fft(l1)[nz] - np.fft.fft(l2)[nz]) ** 2) / 2, 1e-30))

    def symbol(idx):
        st = t1 + 128 + 80 * idx + 16
        if st + 64 > len(r):
            return None
        Y = np.fft.fft(r[st:st + 64]) / H
        pil = Y[bins(PILOT_SC)]
        exp_p = PILOT_BASE * PILOT_POLARITY[idx % 127]
        c = np.sum(pil * exp_p)
        ph = np.angle(c)
        Y = Y * np.exp(-1j * ph)
        return Y[bins(DATA_SC)], ph, pil

    # SIGNAL
    s = symbol(0)
    if s is None:
        rep["error"] = "no SIGNAL symbol"
        return rep
    d, ph, pil = s
    soft = deinterleave(demap_llr(d, 1), 48, 1)
    sb, _ = viterbi(soft)
    code = "".join(str(b) for b in sb[:4])
    length = int(sum(int(sb[5 + i]) << i for i in range(12)))
    parity_ok = (sum(sb[:17]) & 1) == sb[17]
    rep.update(signal_bits="".join(map(str, sb)), rate_code=code, length=length, parity_ok=bool(parity_ok),
               signal_evm_db=_evm_db(d, 1), signal_pilot_phase=ph)
    if code not in RATES or not parity_ok:
        rep["error"] = "bad SIGNAL"
        return rep
    mbps, nbpsc, ncbps, ndbps, rate = RATES[code]
    rep["mbps"] = mbps
    nsym = -(-(16 + 8 * length + 6) // ndbps)
    rep["nsym"] = nsym
    soft_all, evms, phases, pil_signs = [], [], [], []
    for i in range(nsym):
        s = symbol(i + 1)
        if s is None:
            rep["error"] = f"stream ends at data symbol {i} of {nsym}"
            rep["missing_symbols"] = nsym - i
            soft_all.append(np.zeros(ncbps * (nsym - i)))
            break
        d, ph, pil = s
        evms.append(_evm_db(d, nbpsc))
        phases.append(ph)
        exp_p = PILOT_BASE * PILOT_POLARITY[(i + 1) % 127]
        pil_signs.append("".join("+" if np.real(p * e) > 0 else "-" for p, e in zip(pil, exp_p)))
        soft_all.append(deinterleave(demap_llr(d, nbpsc), ncbps, nbpsc))
    soft_all = np.concatenate(soft_all)
    rep["evm_db"] = evms
    rep["pilot_phase"] = phases
    rep["pilot_match"] = pil_signs  # '+' = pilot has expected polarity
    ndata = nsym * ndbps
    dep = depuncture(soft_all, rate, 2 * ndata)
    # the trellis is terminated by the 6 tail bits, i.e. before the pad bits
    nterm = 16 + 8 * length + 6
    bits, vinfo = viterbi(dep[:2 * nterm], force_zero=force_zero_tail)
    bits = np.concatenate([bits, viterbi(dep, force_zero=False)[0][nterm:]])
    rep["viterbi"] = vinfo
    # descrambler: find seed that gives zero SERVICE bits
    best = None
    for seed in range(1, 128):
        seq = scrambler_seq(seed_bits(seed), 16)
        errs = int(np.sum((bits[:16] ^ seq)[:7]))
        if best is None or errs < best[0]:
            best = (errs, seed)
    seed = best[1]
    desc = bits ^ scrambler_seq(seed_bits(seed), ndata)
    rep["scrambler_seed"] = seed
    rep["service_bits"] = "".join(map(str, desc[:16]))
    rep["tail_bits"] = "".join(map(str, bits[16 + 8 * length:16 + 8 * length + 6]))
    psdu = bits_to_bytes(desc[16:16 + 8 * length])
    rep["psdu"] = psdu
    rep["fcs_ok"] = fcs_ok(psdu)
    rep["ok"] = rep["fcs_ok"] and "error" not in rep
    rep["decoded_bits"] = bits
    return rep


def _evm_db(d, nbpsc):
    pts, _ = constellation(nbpsc)
    near = pts[np.argmin(np.abs(d[:, None] - pts[None, :]), 1)]
    return 10 * np.log10(np.mean(np.abs(d - near) ** 2) / np.mean(np.abs(near) ** 2) + 1e-30)
