from pathlib import Path
import csv, io, zipfile, json, collections, hashlib
from datetime import date

ROOT = Path(__file__).resolve().parents[1]
DATE = date(2026,10,14)
TODAY = DATE.strftime('%Y%m%d')
def read(z,name):
    return csv.DictReader(io.TextIOWrapper(z.open(name),encoding='utf-8-sig',newline=''))
def write_csv(path, rows, fields):
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields)
        writer.writeheader();writer.writerows(rows)
input_zip = ROOT/'raw/vbb_gtfs.zip'
if not input_zip.exists(): input_zip = ROOT/'raw/vbb_ringbahn_gtfs_subset.zip'
source_sha256 = hashlib.sha256(input_zip.read_bytes()).hexdigest()
with zipfile.ZipFile(input_zip) as z:
    routes=[r for r in read(z,'routes.txt') if r['route_short_name'] in ['S41','S42'] and r['route_type']=='109']
    route_by_id={r['route_id']:r for r in routes}
    trips=[r for r in read(z,'trips.txt') if r['route_id'] in route_by_id]
    trip_by_id={r['trip_id']:r for r in trips}
    stop_times=[r for r in read(z,'stop_times.txt') if r['trip_id'] in trip_by_id]
    stop_ids={r['stop_id'] for r in stop_times}
    all_stops=list(read(z,'stops.txt'))
    parent_ids={r['parent_station'] for r in all_stops if r['stop_id'] in stop_ids and r.get('parent_station')}
    stops=[r for r in all_stops if r['stop_id'] in stop_ids|parent_ids]
    shapes_ids={r['shape_id'] for r in trips}
    shapes=[r for r in read(z,'shapes.txt') if r['shape_id'] in shapes_ids]
    service_ids={r['service_id'] for r in trips}
    calendars=[r for r in read(z,'calendar.txt') if r['service_id'] in service_ids]
    exceptions=[r for r in read(z,'calendar_dates.txt') if r['service_id'] in service_ids]
    agency_ids={r['agency_id'] for r in routes}
    agency=[r for r in read(z,'agency.txt') if r['agency_id'] in agency_ids]
    frequencies=[r for r in read(z,'frequencies.txt') if r['trip_id'] in trip_by_id]
    subset={'routes.txt':routes,'trips.txt':trips,'stop_times.txt':stop_times,'stops.txt':stops,'shapes.txt':shapes,'calendar.txt':calendars,'calendar_dates.txt':exceptions,'agency.txt':agency,'frequencies.txt':frequencies}
    source_fields = {name: read(z,name).fieldnames for name in subset}

# Eingabe schließen, bevor ein gleichnamiger Auszug neu geschrieben wird.
with zipfile.ZipFile(ROOT/'raw/vbb_ringbahn_gtfs_subset.zip','w',compression=zipfile.ZIP_DEFLATED) as out:
    for name,rows in subset.items():
        fields=source_fields[name]
        s=io.StringIO(newline='');w=csv.DictWriter(s,fieldnames=fields);w.writeheader();w.writerows(rows)
        out.writestr(name,s.getvalue())
for name,rows in subset.items():
    write_csv(ROOT/'processed'/('gtfs_'+name.replace('.txt','.csv')),rows,source_fields[name])
weekday=DATE.strftime('%A').lower()
active={r['service_id'] for r in calendars if r['start_date'] <= TODAY <= r['end_date'] and r[weekday]=='1'}
for r in exceptions:
    if r['date']==TODAY:
        if r['exception_type']=='1':active.add(r['service_id'])
        elif r['exception_type']=='2':active.discard(r['service_id'])
by_trip=collections.defaultdict(list)
for r in stop_times:by_trip[r['trip_id']].append(r)
stop_by_id={r['stop_id']:r for r in stops}
candidates=[]
for trip in trips:
    times=sorted(by_trip[trip['trip_id']],key=lambda r:int(r['stop_sequence']))
    stations=[stop_by_id[r['stop_id']].get('parent_station') or r['stop_id'] for r in times]
    candidates.append({'line':route_by_id[trip['route_id']]['route_short_name'],'trip_id':trip['trip_id'],'route_id':trip['route_id'],'service_id':trip['service_id'],'shape_id':trip['shape_id'],'active_on_2026_10_14':trip['service_id'] in active,'stop_count':len(times),'unique_stations':len(set(stations)),'first_departure':times[0]['departure_time'] if times else '', 'last_arrival':times[-1]['arrival_time'] if times else '', 'first_station':stop_by_id[times[0]['stop_id']]['stop_name'] if times else '', 'last_station':stop_by_id[times[-1]['stop_id']]['stop_name'] if times else ''})
write_csv(ROOT/'processed/gtfs_trip_candidates.csv',candidates,list(candidates[0]))
summary={'reference_service_date':DATE.isoformat(),'route_count':len(routes),'trip_count':len(trips),'stop_times_count':len(stop_times),'stop_count_including_parent_stations':len(stops),'shape_count':len(shapes_ids),'shape_point_count':len(shapes),'active_trip_count':sum(r['active_on_2026_10_14'] for r in candidates),'calendar_start':min(r['start_date'] for r in calendars),'calendar_end':max(r['end_date'] for r in calendars),'source_zip_sha256':source_sha256}
(ROOT/'processed/gtfs_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary,ensure_ascii=False))
for line in ['S41','S42']:
    full=[r for r in candidates if r['line']==line and r['unique_stations']==27 and r['stop_count']>=28]
    full.sort(key=lambda r:(not r['active_on_2026_10_14'],abs(int(r['first_departure'].split(':')[0])-8)))
    print(line,'Beispielumlauf-Kandidaten:',json.dumps(full[:4],ensure_ascii=False))
