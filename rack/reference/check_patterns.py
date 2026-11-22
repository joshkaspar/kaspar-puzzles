"""Reference checker for Rack & Resonance module patterns (prototype, Python).

Port this to Dart as a test in the engine package. It checks every pair of
patterns, in all rotations and mirror images, for:
  - identical patterns (same size, same shape, same parts), and
  - a smaller pattern hiding inside a larger one (one placement would complete both).
Parts: T tube, K knob, J jack, C coil, H chip. '.' is an empty cell.
Run: python3 check_patterns.py
"""
# Each pattern: list of rows; '.' = no cell. Parts: T tube, K knob, J jack, C coil, H chip
P = {
 'VCF':        ['KC'],
 'Random Gen': ['HH'],
 'Oscilloscope':['TJ'],
 'Overdrive':  ['CT', 'T.'],
 'Phaser':     ['HK', 'C.'],
 'Reverb':     ['TC', 'C.'],
 'Bitcrusher': ['HJH'],
 'LFO':        ['KJ', 'H.'],
 'Envelope':   ['JK', 'K.'],
 'Clock':      ['KHJ'],
 'VCA':        ['J.', 'KT', 'J.'],
 'Wavefolder': ['TK', 'CJ'],
 'Comb Filter':['TC.', '.CJ'],
 'Sample & Hold':['J.', 'HK', 'J.'],
 'Quantizer':  ['H.', 'K.', 'HJ'],
 'Delay':      ['HT.', '.HJ', '..K'],
}
def cells(rows):
    return {(r,c):ch for r,row in enumerate(rows) for c,ch in enumerate(row) if ch!='.'}
def norm(cs):
    mr=min(r for r,c in cs); mc=min(c for r,c in cs)
    return frozenset(((r-mr,c-mc),v) for (r,c),v in cs.items())
def orients(cs):
    out=set(); cur=dict(cs)
    for flip in (False,True):
        d={((r,-c) if flip else (r,c)):v for (r,c),v in cs.items()}
        for _ in range(4):
            d={(c,-r):v for (r,c),v in d.items()}
            out.add(norm(d))
    return out
O={k:orients(cells(v)) for k,v in P.items()}
def contains(big,small):
    bc=dict(next(iter(O[big])))
    for o in O[small]:
        o=dict(o)
        for (br,bcc) in bc:
            for (sr,sc) in o:
                dr,dc=br-sr,bcc-sc
                if all(bc.get((r+dr,c+dc))==v for (r,c),v in o.items()):
                    return True
    return False
problems=[]
names=list(P)
for a in names:
    for b in names:
        if a==b: continue
        na,nb=len(cells(P[a])),len(cells(P[b]))
        if na==nb and O[a]==O[b]: problems.append(f'IDENTICAL {a} = {b}')
        elif na>nb and contains(a,b): problems.append(f'{b} hides inside {a}')
print('\n'.join(problems) or 'No duplicates or hidden patterns.')
from collections import Counter
cnt=Counter(ch for v in P.values() for row in v for ch in row if ch!='.')
print(dict(cnt), sum(cnt.values()))
