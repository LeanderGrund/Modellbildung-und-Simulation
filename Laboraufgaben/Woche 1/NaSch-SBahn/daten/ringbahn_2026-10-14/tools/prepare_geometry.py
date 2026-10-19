from pathlib import Path
import sys, csv, json, re
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'dependencies'))
from geographiclib.geodesic import Geodesic
GEOD=Geodesic.WGS84
def distance(a,b):return GEOD.Inverse(a[0],a[1],b[0],b[1])['s12']
def csvwrite(name,rows):
    with (ROOT/'processed'/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def csvread(name):
    with (ROOT/'processed'/name).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def tags(el):return {t.get('k'):t.get('v') for t in el.findall('tag')}
def norm(name):
    name=re.sub(r'^S\+U |^S | \(Berlin\)$| Bhf','',name)
    return name.replace('str.','straße').replace('Str.','Straße').replace('Strasse','Straße').lower().strip()
summary=[];osm_by_line={}
for line,rid in [('S41',14981),('S42',14983)]:
    root=ET.parse(ROOT/'raw'/f'osm_relation_{rid}_full.osm').getroot()
    nodes={int(e.get('id')):e for e in root.findall('node')}
    ways={int(e.get('id')):e for e in root.findall('way')}
    rels={int(e.get('id')):e for e in root.findall('relation')}
    relation=rels[rid];rel_tags=tags(relation)
    assert rel_tags['ref']==line and rel_tags['roundtrip']=='yes'
    stops=[int(m.get('ref')) for m in relation.findall('member') if m.get('type')=='node' and m.get('role')=='stop']
    assert stops[0]==stops[-1] and len(set(stops[:-1]))==27
    stops=stops[:-1]
    track_members=[m for m in relation.findall('member') if m.get('type')=='way' and not m.get('role','').startswith('platform')]
    pieces=[]
    for member in track_members:
        way=ways[int(member.get('ref'))]
        assert tags(way).get('railway') in ['rail','light_rail'],(line,member.get('ref'),tags(way))
        pieces.append([int(n.get('ref')) for n in way.findall('nd')])
    route=None
    for reverse in [False,True]:
        chain=pieces[0][::-1] if reverse else pieces[0][:]
        for piece in pieces[1:]:
            if chain[-1]==piece[0]:chain+=piece[1:]
            elif chain[-1]==piece[-1]:chain+=piece[-2::-1]
            else:break
        else:
            if chain[0]==chain[-1]:route=chain;break
    assert route is not None,(line,'Gleisstücke sind nicht lückenlos geschlossen')
    assert all(n in route for n in stops)
    start=route.index(stops[0]);core=route[:-1]
    route=core[start:]+core[:start]+[stops[0]]
    coords=[(float(nodes[n].get('lat')),float(nodes[n].get('lon'))) for n in route]
    cumulative=[0.0]
    for a,b in zip(coords,coords[1:]):cumulative.append(cumulative[-1]+distance(a,b))
    rows=[{'point_index':i+1,'osm_node_id':n,'latitude':c[0],'longitude':c[1],'distance_m':round(d,3)} for i,(n,c,d) in enumerate(zip(route,coords,cumulative))]
    csvwrite(f'{line.lower()}_osm_track_points.csv',rows)
    stop_rows=[]
    for i,node_id in enumerate(stops):
        node=nodes[node_id];t=tags(node);index=route.index(node_id)
        name=t.get('name','')
        stop_rows.append({'stop_sequence':i+1,'station_name':name,'osm_stop_node_id':node_id,'latitude':float(node.get('lat')),'longitude':float(node.get('lon')),'distance_m':round(cumulative[index],3),'ref_ifopt':t.get('ref:IFOPT',''),'uic_ref':t.get('uic_ref','')})
    assert all(b['distance_m']>a['distance_m'] for a,b in zip(stop_rows,stop_rows[1:]))
    csvwrite(f'{line.lower()}_osm_stations.csv',stop_rows)
    segments=[]
    for i,stop in enumerate(stop_rows):
        nxt=stop_rows[(i+1)%27]
        length=(nxt['distance_m']-stop['distance_m'])%cumulative[-1]
        segments.append({'segment_sequence':i+1,'from_station':stop['station_name'],'to_station':nxt['station_name'],'length_m':round(length,3),'from_distance_m':stop['distance_m'],'to_distance_m':nxt['distance_m'] if i<26 else round(cumulative[-1],3)})
    csvwrite(f'{line.lower()}_osm_segments.csv',segments)
    way_rows=[]
    for member in track_members:
        way=ways[int(member.get('ref'))];t=tags(way)
        way_rows.append({'osm_way_id':way.get('id'),'railway':t.get('railway',''),'maxspeed':t.get('maxspeed',''),'maxspeed_forward':t.get('maxspeed:forward',''),'maxspeed_backward':t.get('maxspeed:backward',''),'railway_track_ref':t.get('railway:track_ref',''),'all_tags_json':json.dumps(t,ensure_ascii=False,sort_keys=True)})
    csvwrite(f'{line.lower()}_osm_track_attributes.csv',way_rows)
    osm_by_line[line]={'stations':stop_rows,'coordinates':coords,'length_m':cumulative[-1]}
    summary.append({'line':line,'relation_id':rid,'station_count':len(stop_rows),'point_count':len(coords),'way_count':len(track_members),'length_m':round(cumulative[-1],3),'closed':True,'maxspeed_tagged_way_count':sum(bool(r['maxspeed'] or r['maxspeed_forward'] or r['maxspeed_backward']) for r in way_rows),'relation_tags':rel_tags})
(ROOT/'processed/osm_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
gtfs_stops={r['stop_id']:r for r in csvread('gtfs_stops.csv')}
gtfs_times=csvread('gtfs_stop_times.csv');gtfs_shapes=csvread('gtfs_shapes.csv');gtfs_trips={r['trip_id']:r for r in csvread('gtfs_trips.csv')}
trip_summary=[]
def seconds(value):return sum(int(v)*scale for v,scale in zip(value.split(':'),[3600,60,1]))
for line,trip_id in [('S41','308542990'),('S42','308548978')]:
    trip=gtfs_trips[trip_id]
    times=sorted([r for r in gtfs_times if r['trip_id']==trip_id],key=lambda r:int(r['stop_sequence']))
    assert len(times)==28
    parent=lambda r:gtfs_stops[r['stop_id']].get('parent_station') or r['stop_id']
    assert parent(times[0])==parent(times[-1]) and len(set(parent(r) for r in times[:-1]))==27
    shape=sorted([r for r in gtfs_shapes if r['shape_id']==trip['shape_id']],key=lambda r:int(r['shape_pt_sequence']))
    points=[(float(r['shape_pt_lat']),float(r['shape_pt_lon'])) for r in shape]
    cumulative=[0.0]
    for a,b in zip(points,points[1:]):cumulative.append(cumulative[-1]+distance(a,b))
    assert points[0]==points[-1]
    csvwrite(f'{line.lower()}_gtfs_shape_points.csv',[{'point_index':i+1,'shape_id':trip['shape_id'],'shape_pt_sequence':r['shape_pt_sequence'],'latitude':c[0],'longitude':c[1],'distance_m':round(d,3)} for i,(r,c,d) in enumerate(zip(shape,points,cumulative))])
    mapped=[];last=0
    osm_lookup={norm(s['station_name']):s for s in osm_by_line[line]['stations']}
    for i,row in enumerate(times):
        stop=gtfs_stops[row['stop_id']];coord=(float(stop['stop_lat']),float(stop['stop_lon']))
        index=len(points)-1 if i==27 else min(range(last,len(points)),key=lambda j:distance(coord,points[j]))
        last=index
        match=osm_lookup.get(norm(stop['stop_name']))
        assert match is not None,(line,stop['stop_name'],'kein OSM-Stationsmatch')
        mapped.append({'stop_sequence':i+1,'station_name':stop['stop_name'],'gtfs_stop_id':row['stop_id'],'gtfs_parent_station_id':parent(row),'latitude':coord[0],'longitude':coord[1],'arrival_time':row['arrival_time'],'departure_time':row['departure_time'],'planned_dwell_seconds':seconds(row['departure_time'])-seconds(row['arrival_time']),'endpoint_dwell_unknown':i in [0,27],'shape_distance_m':round(cumulative[index],3),'shape_point_offset_m':round(distance(coord,points[index]),3),'osm_stop_node_id':match['osm_stop_node_id'],'osm_station_match_method':'normalized_name','station_coordinate_difference_m':round(distance(coord,(match['latitude'],match['longitude'])),3)})
    assert all(b['shape_distance_m']>a['shape_distance_m'] for a,b in zip(mapped,mapped[1:]))
    csvwrite(f'{line.lower()}_example_timetable.csv',mapped)
    segments=[]
    for i,(a,b) in enumerate(zip(mapped,mapped[1:])):
        length=b['shape_distance_m']-a['shape_distance_m'];drive=seconds(b['arrival_time'])-seconds(a['departure_time'])
        assert drive>0
        segments.append({'segment_sequence':i+1,'from_station':a['station_name'],'to_station':b['station_name'],'gtfs_shape_length_m':round(length,3),'planned_drive_seconds':drive,'derived_segment_average_kmh':round(length/drive*3.6,3),'from_departure_time':a['departure_time'],'to_arrival_time':b['arrival_time']})
    csvwrite(f'{line.lower()}_example_segments.csv',segments)
    trip_summary.append({'line':line,'trip_id':trip_id,'service_id':trip['service_id'],'shape_id':trip['shape_id'],'reference_service_date':'2026-10-14','first_departure':mapped[0]['departure_time'],'return_arrival':mapped[-1]['arrival_time'],'departure_to_return_arrival_seconds':seconds(mapped[-1]['arrival_time'])-seconds(mapped[0]['departure_time']),'shape_length_m':round(cumulative[-1],3),'shape_point_count':len(shape),'interior_dwell_seconds_sum':sum(r['planned_dwell_seconds'] for r in mapped[1:-1]),'interior_dwell_seconds_min':min(r['planned_dwell_seconds'] for r in mapped[1:-1]),'interior_dwell_seconds_max':max(r['planned_dwell_seconds'] for r in mapped[1:-1]),'endpoint_dwell_unknown':True,'max_shape_point_offset_m':max(r['shape_point_offset_m'] for r in mapped),'max_osm_gtfs_station_difference_m':max(r['station_coordinate_difference_m'] for r in mapped),'trip_source_row':trip})
(ROOT/'processed/example_trip_summary.json').write_text(json.dumps(trip_summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'osm':summary,'gtfs_examples':trip_summary},ensure_ascii=False,indent=2))
