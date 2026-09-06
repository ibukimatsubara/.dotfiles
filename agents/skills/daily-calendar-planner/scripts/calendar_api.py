# /// script
# requires-python = ">=3.11"
# dependencies = ["google-auth-oauthlib>=1.2,<2", "requests>=2.32,<3"]
# ///
"""Google Calendar API registration, restricted to the planner-created calendar."""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from urllib.parse import quote

ACCOUNT='ibuuun1224@gmail.com'
SCOPES=['openid','https://www.googleapis.com/auth/userinfo.email','https://www.googleapis.com/auth/calendar.app.created']
HOME=Path.home()/'.config/daily-calendar-planner'
MARKER='life-kb-daily-v1'
TZ=ZoneInfo('Asia/Tokyo')


def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    temp=path.with_suffix('.tmp')
    fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
    with os.fdopen(fd,'w') as f: json.dump(data,f,ensure_ascii=False,indent=2)
    os.replace(temp,path)


def identity(session):
    r=session.get('https://openidconnect.googleapis.com/v1/userinfo',timeout=30)
    r.raise_for_status()
    info=r.json()
    if info.get('email')!=ACCOUNT or info.get('email_verified') is not True:
        raise ValueError('Wrong Google account; no calendar operation performed')
    return info['email']


def session():
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import AuthorizedSession,Request
    p=HOME/'token.json'
    if not p.exists():raise ValueError('Calendar OAuth is not connected. Run auth with a Desktop OAuth client JSON.')
    creds=Credentials.from_authorized_user_file(p,SCOPES)
    if not creds.valid:
        creds.refresh(Request());save(p,json.loads(creds.to_json()))
    s=AuthorizedSession(creds)
    identity(s)
    return s


def api(s,method,path,body=None,params=None,headers=None):
    options = {'headers':headers} if headers else {}
    r=s.request(method,'https://www.googleapis.com/calendar/v3/'+path,json=body,params=params,timeout=30,**options)
    if not r.ok:raise RuntimeError(f'Calendar API HTTP {r.status_code}: '+r.json().get('error',{}).get('message','Request failed'))
    return r.json() if r.content else {}


def make_events(plan):
    if plan.get('status')!='proposal' or plan.get('warnings'):
        raise ValueError('Resolve plan warnings before registration')
    base=datetime.fromisoformat(plan['date']).replace(tzinfo=TZ)
    result=[]
    for i,e in enumerate(plan['generated']):
        if e.get('source')!='generated' or e['category'] not in ('company','personal','rest1','rest2'):
            raise ValueError('Only generated company, personal and rest blocks can be registered')
        if not plan['start']<=e['start']<e['end']<=plan['end']:
            raise ValueError('Invalid event interval')
        if any(e['start']<f['end'] and f['start']<e['end'] for f in plan['fixed']):
            raise ValueError('Generated event overlaps fixed appointment')
        for previous in plan['generated'][:i]:
            if e['start']<previous['end'] and previous['start']<e['end']:
                raise ValueError('Generated events overlap')
        uid=hashlib.sha256(f'{MARKER}:{plan["date"]}:{i}'.encode()).hexdigest()
        result.append({'id':uid,'summary':'[AI Plan] '+e['title'],
            'description':e.get('detail','')+'\n自動計画 / '+MARKER,
            'start':{'dateTime':(base+timedelta(minutes=e['start'])).isoformat(),'timeZone':'Asia/Tokyo'},
            'end':{'dateTime':(base+timedelta(minutes=e['end'])).isoformat(),'timeZone':'Asia/Tokyo'},
            'visibility':'private','transparency':'opaque','reminders':{'useDefault':False},
            'colorId':{'company':'9','personal':'3','rest1':'2','rest2':'2'}[e['category']],
            'extendedProperties':{'private':{'planner':MARKER,'date':plan['date']}}})
    if not result:raise ValueError('No generated events')
    return result


def matches(actual,desired):
    if any(actual.get(k) for k in ('location','attachments','recurrence','recurringEventId','conferenceData')):
        return False
    if actual.get('transparency','opaque') != desired.get('transparency','opaque'):return False
    for key in ('summary','description','visibility','reminders','extendedProperties','colorId'):
        if actual.get(key)!=desired.get(key):return False
    for key in ('start','end'):
        if datetime.fromisoformat(actual[key]['dateTime'].replace('Z','+00:00')) != datetime.fromisoformat(desired[key]['dateTime']):return False
    return not actual.get('attendees') and actual.get('status')!='cancelled'


def apply(s,plan,config,previous_events=None):
    if config.get('account')!=ACCOUNT or config.get('created_by')!=MARKER or not config.get('calendar_id','').endswith('@group.calendar.google.com'):
        raise ValueError('Destination is not the configured planner-created calendar')
    wanted=make_events(plan)
    if any(datetime.fromisoformat(e['start']['dateTime'])<=datetime.now(timezone.utc) for e in wanted):
        raise ValueError('Started events cannot be written')
    route='calendars/'+quote(config['calendar_id'],safe='')
    cal=api(s,'GET',route)
    if cal.get('summary')!='AI Daily Plan' or cal.get('description')!=MARKER:
        raise ValueError('Destination calendar marker mismatch')
    existing=[]; token=None
    while True:
        params={'timeMin':datetime.fromisoformat(plan['date']).replace(tzinfo=TZ).isoformat(),
                'timeMax':(datetime.fromisoformat(plan['date']).replace(tzinfo=TZ)+timedelta(minutes=plan['end'])).isoformat(),
                'singleEvents':True,'maxResults':2500}
        if token:params['pageToken']=token
        page=api(s,'GET',route+'/events',params=params);existing+=page.get('items',[])
        token=page.get('nextPageToken')
        if not token:break
    desired={e['id']:e for e in wanted}
    previous = None
    if previous_events is not None:
        previous = {e['id']:e for e in previous_events}
        if len(previous) != len(previous_events) or set(previous) != set(desired):
            raise ValueError('Updates require the same event IDs; count changes are unsupported')
        for e in previous.values():
            if e.get('extendedProperties',{}).get('private') != {'planner':MARKER,'date':plan['date']}:
                raise ValueError('Previous event is not owned by this planner and date')
            if datetime.fromisoformat(e['start']['dateTime']) <= datetime.now(timezone.utc):
                raise ValueError('Started events cannot be updated')
        if {e['id'] for e in existing} != set(previous):
            raise ValueError('Existing event set changed; no update performed')
    changes = {}
    for e in existing:
        uid = e['id']
        if uid not in desired:
            raise ValueError('Unrecognized existing event; no write performed')
        if matches(e,desired[uid]):
            continue
        if previous is None or not matches(e,previous[uid]):
            raise ValueError('Existing event differs from the previous plan; manual edits are protected')
        if not e.get('etag'):
            raise ValueError('Update requires an ETag')
        changes[uid] = e['etag']
    known={e['id'] for e in existing}
    inserted=updated=0
    for e in wanted:
        uid=e['id']
        if uid in changes:
            body={k:v for k,v in e.items() if k!='id'}
            api(s,'PATCH',route+'/events/'+uid,body=body,params={'sendUpdates':'none'},
                headers={'If-Match':changes[uid]})
            updated+=1
        elif uid not in known:
            api(s,'POST',route+'/events',body=e,params={'sendUpdates':'none'});inserted+=1
    # Read all entries after the complete write sequence, including unchanged ones.
    for e in wanted:
        actual=api(s,'GET',route+'/events/'+e['id'])
        if not matches(actual,e):raise ValueError('Event read-back verification failed')
    return {'verified':len(wanted),'inserted':inserted,'updated':updated,
            'already_present':len(known)-updated,'account':ACCOUNT,'calendar_id':config['calendar_id']}


def read_plan(path):
    if path is None:raise ValueError('--plan is required')
    return json.load(sys.stdin) if str(path)=='-' else json.loads(path.read_text())


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('command',choices=['auth','init-calendar','preview','apply','update','status'])
    p.add_argument('--client',type=Path)
    p.add_argument('--plan',type=Path)
    p.add_argument('--previous-events',type=Path,help='Verified generated-event preview before the update')
    a=p.parse_args()
    if a.command=='preview':
        print(json.dumps(make_events(read_plan(a.plan)),ensure_ascii=False,indent=2));return
    if a.command=='auth':
        from google_auth_oauthlib.flow import InstalledAppFlow
        from google.auth.transport.requests import AuthorizedSession
        if not a.client or not a.client.exists():raise ValueError('Desktop OAuth client JSON is required')
        flow=InstalledAppFlow.from_client_secrets_file(a.client,SCOPES)
        creds=flow.run_local_server(host='127.0.0.1',port=0,timeout_seconds=300,login_hint=ACCOUNT,prompt='consent',access_type='offline')
        identity(AuthorizedSession(creds))
        save(HOME/'token.json',json.loads(creds.to_json()))
        print('Authenticated expected personal account.');return
    s=session()
    if a.command=='status':print({'account':ACCOUNT,'calendar_configured':(HOME/'calendar.json').exists()});return
    if a.command=='init-calendar':
        if (HOME/'calendar.json').exists():print('Planner calendar already configured.');return
        pending=HOME/'creation-pending.json'
        if pending.exists():raise ValueError('An earlier creation is unresolved. Inspect it before retrying to prevent duplicates.')
        save(pending,{'requested_at':datetime.now(timezone.utc).isoformat()})
        cal=api(s,'POST','calendars',body={'summary':'AI Daily Plan','description':MARKER,'timeZone':'Asia/Tokyo'})
        save(HOME/'calendar.json',{'account':ACCOUNT,'calendar_id':cal['id'],'created_by':MARKER})
        print('Created and configured AI Daily Plan.');return
    if a.command=='update' and not a.previous_events:
        raise ValueError('update requires --previous-events; never use a fresh server copy as the baseline')
    plan=read_plan(a.plan)
    previous=json.loads(a.previous_events.read_text()) if a.command=='update' else None
    result=apply(s,plan,json.loads((HOME/'calendar.json').read_text()),previous)
    save(HOME/('verified-events-'+plan['date']+'.json'),make_events(plan))
    save(HOME/'last-registration.json',dict(result,date=plan['date'],verified_at=datetime.now(timezone.utc).isoformat()))
    print(json.dumps(result,ensure_ascii=False))

if __name__=='__main__':main()
