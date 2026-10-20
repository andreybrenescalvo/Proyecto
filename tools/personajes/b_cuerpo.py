"""Paso 1: el cuerpo con proporciones propias (sin músculos de superhéroe, cabeza y ojos apenas
más grandes) y exportado a glTF para verlo en Godot."""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blib import *

BODY = {
    "head": 1.08, "eyes": 1.12, "hands": 1.04, "smooth": 1.0,
    "shoulders": 0.94, "chest": 0.9, "waist": 1.06, "belly": 0.0,
}


def restyle(b, opts):
    arm, body = b["arm"], b["body"]
    V = co(body)
    E = edges(body)
    wh = group_weights(body, ["Head"])
    wn = group_weights(body, ["neck"])
    whand = group_weights(body, ["hand", "index", "middle", "ring", "pinky", "thumb"])
    wfoot = group_weights(body, ["foot", "ball"])
    head = bone_head(arm, "Head")
    # 1. Sin músculos marcados: suavizar el cuerpo, salvo cabeza, manos y pies.
    mask = np.clip(1.0 - wh - wn * 0.6 - whand - wfoot, 0, 1) * opts["smooth"]
    V = taubin(V, E, mask, iters=14)
    # 2. Menos forma de "V": hombros y pecho más chicos, cintura más ancha, panza.
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    torso = np.clip(1.0 - wh - whand - wfoot, 0, 1) * (np.abs(x) < 0.26)
    warm = group_weights(body, ["upperarm", "lowerarm", "clavicle"])
    chest_band = np.exp(-((z - 1.36) / 0.1) ** 2) * torso * (1 - warm)
    V[:, 1] += (y - (-0.0)) * (opts["chest"] - 1.0) * chest_band * (y < 0)
    sh = np.exp(-((z - 1.42) / 0.07) ** 2) * torso
    V[:, 0] += x * (opts["shoulders"] - 1.0) * sh * (1 - warm * 0.5)
    waist = np.exp(-((z - 1.08) / 0.14) ** 2) * torso * (1 - warm)
    V[:, 0] += x * (opts["waist"] - 1.0) * waist
    V[:, 1] += y * (opts["waist"] - 1.0) * waist * 0.6
    if opts["belly"]:
        bel = np.exp(-(((z - 1.05) / 0.16) ** 2 + (x / 0.18) ** 2)) * torso * (1 - warm) * np.clip(-y / 0.1 + 0.4, 0, 1)
        V[:, 1] -= opts["belly"] * bel
        V[:, 0] += x * opts["belly"] * 1.6 * bel
    # 3. Cabeza apenas más grande (desde el cuello).
    piv = head + np.array([0, 0, -0.03])
    V += (V - piv) * (opts["head"] - 1.0) * wh[:, None]
    # 4. Manos un poco más grandes.
    for side in ("l", "r"):
        wsd = group_weights(body, ["hand", "index", "middle", "ring", "pinky", "thumb"], side)
        hp = bone_head(arm, "hand_" + side)
        V += (V - hp) * (opts["hands"] - 1.0) * wsd[:, None]
    set_co(body, V)
    b["head_scale"] = opts["head"]
    # Ojos y cejas acompañan a la cabeza (y los ojos crecen un poco más).
    for key in ("eyes", "brows"):
        o = b[key]
        W = co(o)
        W = piv + (W - piv) * opts["head"]
        if key == "eyes":
            for s in (1, -1):
                sel = np.sign(W[:, 0]) == s
                c = W[sel].mean(0)
                W[sel] = c + (W[sel] - c) * opts["eyes"]
        set_co(o, W)
