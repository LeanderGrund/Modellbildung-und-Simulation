from pathlib import Path
import csv,json
ROOT=Path(__file__).resolve().parents[1]
def read(name):
    with (ROOT/name).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def unique(rows,keys):
    assert len(rows)==len({tuple(r[k] for k in keys) for r in rows}),keys
routes=read('processed/gtfs_routes.csv');trips=read('processed/gtfs_trips.csv')
times=read('processed/gtfs_stop_times.csv');stops=read('processed/gtfs_stops.csv')
shapes=read('processed/gtfs_shapes.csv')
for rows,keys in [(routes,['route_id']),(trips,['trip_id']),(times,['trip_id','stop_sequence']),(stops,['stop_id']),(shapes,['shape_id','shape_pt_sequence'])]:unique(rows,keys)
route_ids={r['route_id'] for r in routes};trip_ids={r['trip_id'] for r in trips};stop_ids={r['stop_id'] for r in stops};shape_ids={r['shape_id'] for r in shapes}
assert all(r['route_id'] in route_ids and r['shape_id'] in shape_ids for r in trips)
assert all(r['trip_id'] in trip_ids and r['stop_id'] in stop_ids for r in times)
assert all(not r['parent_station'] or r['parent_station'] in stop_ids for r in stops)
station_names={}
for line in ['s41','s42']:
    track=read(f'{line}_track_points.csv');stations=read(f'{line}_stations.csv');segments=read(f'{line}_segments.csv')
    assert len(stations)==27 and len(segments)==27
    unique(stations,['osm_stop_node_id']);unique(stations,['gtfs_parent_station_id'])
    assert (track[0]['latitude'],track[0]['longitude'])==(track[-1]['latitude'],track[-1]['longitude'])
    length=float(track[-1]['distance_m'])
    assert 36000<length<38000
    assert abs(sum(float(r['osm_length_m']) for r in segments)-length)<0.01
    assert all(float(b['distance_m'])>float(a['distance_m']) for a,b in zip(track,track[1:]))
    assert float(stations[0]['distance_m'])==0
    assert all(float(b['distance_m'])>float(a['distance_m']) for a,b in zip(stations,stations[1:]))
    assert all(52.3<float(r['latitude'])<52.7 and 13.05<float(r['longitude'])<13.8 for r in track)
    assert all(float(r['planned_drive_seconds'])>0 for r in segments)
    area=sum(float(a['longitude'])*float(b['latitude'])-float(b['longitude'])*float(a['latitude']) for a,b in zip(track,track[1:]))
    assert area<0 if line=='s41' else area>0
    station_names[line]=[r['station_name'] for r in stations]
    print(f'{line.upper()}: 27 Stationen, 27 Abschnitte, geschlossener Gleisring, {length/1000:.3f} km.')
assert station_names['s41'][0]==station_names['s42'][0]
assert station_names['s41'][1:]==list(reversed(station_names['s42'][1:]))
examples=json.loads((ROOT/'processed/example_trip_summary.json').read_text())
for r in examples:
    assert r['departure_to_return_arrival_seconds']==3558
    assert r['interior_dwell_seconds_min']==30 and r['interior_dwell_seconds_max']==48
    assert r['endpoint_dwell_unknown']
candidates=read('processed/gtfs_trip_candidates.csv')
for example in examples:
    candidate=next(r for r in candidates if r['trip_id']==example['trip_id'])
    assert candidate['active_on_2026_10_14']=='True'
print('GTFS-Schlüssel eindeutig; alle Fremdschlüssel aufgelöst; beide Beispielfahrten am 14.10.2026 gültig.')
print('Quellenabweichungen: GTFS-Shapes nicht als Gleislängen verwenden; siehe processed/geometry_quality.json.')
