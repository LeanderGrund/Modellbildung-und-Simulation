from pathlib import Path
import csv,json
ROOT=Path(__file__).resolve().parents[1]
def read(name):
    with (ROOT/'processed'/name).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def write(name,rows):
    with (ROOT/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
quality=[];features=[]
summary={r['line']:r for r in json.loads((ROOT/'processed/osm_summary.json').read_text())}
for line in ['s41','s42']:
    points=read(f'{line}_osm_track_points.csv')
    osm_stations=read(f'{line}_osm_stations.csv')
    timetable=read(f'{line}_example_timetable.csv')
    gtfs_segments=read(f'{line}_example_segments.csv')
    length=summary[line.upper()]['length_m']
    source_index={r['osm_stop_node_id']:r for r in osm_stations}
    start_node=timetable[0]['osm_stop_node_id']
    start_distance=float(source_index[start_node]['distance_m'])
    core=points[:-1];start=next(i for i,r in enumerate(core) if r['osm_node_id']==start_node)
    rotated=core[start:]+core[:start]+[core[start]]
    point_rows=[]
    for i,r in enumerate(rotated):
        d=(float(r['distance_m'])-start_distance)%length if i<len(rotated)-1 else length
        point_rows.append({'point_index':i+1,'distance_m':round(d,3),'latitude':r['latitude'],'longitude':r['longitude'],'osm_node_id':r['osm_node_id']})
    assert all(float(b['distance_m'])>float(a['distance_m']) for a,b in zip(point_rows,point_rows[1:]))
    write(f'{line}_track_points.csv',point_rows)
    station_rows=[]
    for i,t in enumerate(timetable[:-1]):
        s=source_index[t['osm_stop_node_id']]
        station_rows.append({'station_sequence':i+1,'station_name':s['station_name'],'distance_m':round((float(s['distance_m'])-start_distance)%length,3),'latitude':s['latitude'],'longitude':s['longitude'],'osm_stop_node_id':s['osm_stop_node_id'],'gtfs_parent_station_id':t['gtfs_parent_station_id'],'gtfs_example_stop_id':t['gtfs_stop_id'],'gtfs_station_name':t['station_name'],'coordinate_source':'OpenStreetMap stop_position','distance_source':'OpenStreetMap ordered railway geometry; WGS84 ellipsoid'})
    assert len(station_rows)==27 and all(float(b['distance_m'])>float(a['distance_m']) for a,b in zip(station_rows,station_rows[1:]))
    write(f'{line}_stations.csv',station_rows)
    segment_rows=[]
    for i,(s,t) in enumerate(zip(station_rows,gtfs_segments)):
        nxt=station_rows[(i+1)%27]
        d=((float(nxt['distance_m'])-float(s['distance_m']))%length)
        seconds=int(t['planned_drive_seconds']);gtfs_length=float(t['gtfs_shape_length_m'])
        segment_rows.append({'segment_sequence':i+1,'from_station':s['station_name'],'to_station':nxt['station_name'],'osm_length_m':round(d,3),'planned_drive_seconds':seconds,'derived_osm_segment_average_kmh':round(d/seconds*3.6,3),'gtfs_shape_length_m':gtfs_length,'geometry_disagreement_percent':round((gtfs_length/d-1)*100,3),'departure_time':t['from_departure_time'],'arrival_time':t['to_arrival_time'],'service_date':'2026-10-14','timing_source_trip_id':'308542990' if line=='s41' else '308548978'})
    assert abs(sum(r['osm_length_m'] for r in segment_rows)-length)<0.01
    write(f'{line}_segments.csv',segment_rows)
    gtfs_length=sum(r['gtfs_shape_length_m'] for r in segment_rows)
    quality.append({'line':line.upper(),'station_count':27,'osm_length_m':length,'gtfs_example_shape_length_m':round(gtfs_length,3),'length_disagreement_percent':round((gtfs_length/length-1)*100,3),'max_derived_speed_osm_kmh':max(r['derived_osm_segment_average_kmh'] for r in segment_rows),'max_derived_speed_gtfs_kmh':max(float(r['derived_segment_average_kmh']) for r in gtfs_segments),'most_disagreeing_segment':max(segment_rows,key=lambda r:abs(r['geometry_disagreement_percent']))})
    features.append({'type':'Feature','properties':{'line':line.upper(),'source':'OpenStreetMap contributors','start_station':station_rows[0]['station_name'],'length_m':length,'relation_id':summary[line.upper()]['relation_id']},'geometry':{'type':'LineString','coordinates':[[float(r['longitude']),float(r['latitude'])] for r in point_rows]}})
    features.extend({'type':'Feature','properties':dict(r,line=line.upper()),'geometry':{'type':'Point','coordinates':[float(r['longitude']),float(r['latitude'])]}} for r in station_rows)
(ROOT/'ringbahn.geojson').write_text(json.dumps({'type':'FeatureCollection','features':features},ensure_ascii=False,indent=2)+'\n')
(ROOT/'processed/geometry_quality.json').write_text(json.dumps(quality,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(quality,ensure_ascii=False,indent=2))
