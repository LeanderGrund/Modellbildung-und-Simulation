"""S41-Signalkandidaten aus OSM-Wegen und der geordneten Streckengeometrie ableiten."""
from pathlib import Path
import collections,csv,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT
tags=lambda e:{t.get('k'):t.get('v') for t in e.findall('tag')}
root=ET.parse(ROOT/'raw/osm_relation_14981_full.osm').getroot()
with (ROOT/'s41_track_points.csv').open(encoding='utf-8-sig') as file: track=list(csv.DictReader(file))
sequence=[p['osm_node_id'] for p in track]
edges=set(zip(sequence,sequence[1:]))
distances={p['osm_node_id']:float(p['distance_m']) for p in track[:-1]}
relation=next(r for r in root.findall('relation') if r.get('id')=='14981')
way_ids={m.get('ref') for m in relation.findall('member') if m.get('type')=='way' and not m.get('role','').startswith('platform')}
orientations=collections.defaultdict(set)
for way in root.findall('way'):
    if way.get('id') not in way_ids: continue
    nodes=[n.get('ref') for n in way.findall('nd')]
    direction=set()
    for a,b in zip(nodes,nodes[1:]):
        if (a,b) in edges: direction.add(1)
        if (b,a) in edges: direction.add(-1)
    assert len(direction)==1,(way.get('id'),direction)
    for node in nodes: orientations[node].update(direction)
signals=[]
for node in root.findall('node'):
    node_id=node.get('id');data=tags(node)
    if node_id not in distances or data.get('railway')!='signal':continue
    mapped_direction=data.get('railway:signal:direction')
    votes={o*(1 if mapped_direction=='forward' else -1) for o in orientations[node_id]} if mapped_direction in ['forward','backward'] else set()
    if votes!={1}:continue
    common={'osm_node_id':node_id,'osm_url':'https://www.openstreetmap.org/node/'+node_id,
        'distance_m':distances[node_id],'ref':data.get('ref',''),
        'mapped_direction':mapped_direction,'latitude':node.get('lat'),'longitude':node.get('lon')}
    for category,target in [('main',signals),('combined',signals)]:
        value=data.get('railway:signal:'+category)
        if value in [None,'no'] or data.get('railway:signal:'+category+':deactivated')=='yes':continue
        target.append(dict(common,category=category,signal_type=value,
            function=data.get('railway:signal:'+category+':function',''),
            caption=data.get('railway:signal:'+category+':caption',''),
            status='OSM-Kandidat; nicht betrieblich verifiziert'))
for name,rows in [('s41_signalkandidaten.csv',signals)]:
    rows.sort(key=lambda x:x['distance_m'])
    with (OUT/name).open('w',encoding='utf-8-sig',newline='') as file:
        writer=csv.DictWriter(file,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
assert len(signals)==117
print('117 gerichtete Haupt-/Mehrabschnittssignale gespeichert; keine bestätigten Blockgrenzen.')
