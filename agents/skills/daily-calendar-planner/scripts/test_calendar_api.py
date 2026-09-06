import copy
import unittest
from unittest.mock import patch
from datetime import date
from adaptive_day import build
from calendar_api import make_events,matches,apply,ACCOUNT,MARKER

class CalendarWriteTests(unittest.TestCase):
    def plan(self):
        return build(dict(source='notion-calendar',date='2099-09-07',observed_at='2099-09-06T15:00:00+09:00',accounts_checked=['test'],coverage_complete=True,coverage_start='2099-09-07T00:00:00+09:00',coverage_end='2099-09-08T00:00:00+09:00',events=[]),date(2099,9,7),'08:00')
    def test_payload_is_private_and_deterministic(self):
        p=self.plan();es=make_events(p)
        self.assertEqual(es,make_events(p))
        self.assertTrue(all('attendees' not in e and e['reminders']=={'useDefault':False} for e in es))
        self.assertTrue(all(e['visibility']=='private' for e in es))
        self.assertEqual(es[-1]['end']['dateTime'],'2099-09-08T00:00:00+09:00')
    def test_rejects_conflict_and_warning(self):
        p=self.plan();p['warnings']=['conflict']
        with self.assertRaises(ValueError):make_events(p)
        p=self.plan();p['fixed']=[{'start':500,'end':550}]
        with self.assertRaises(ValueError):make_events(p)
    def test_wrong_account_cannot_write(self):
        with patch('calendar_api.api') as mock:
            with self.assertRaises(ValueError):apply(None,self.plan(),{'account':'wrong'})
            mock.assert_not_called()
    def test_retry_reads_back_without_duplicates_and_refuses_edits(self):
        p=self.plan();storage={};posts=[]
        def fake(s,method,path,body=None,params=None):
            if path.endswith('/events'):
                if method=='GET':return {'items':list(storage.values())}
                storage[body['id']]=copy.deepcopy(body);posts.append(body);return body
            if '/events/' in path:return storage[path.rsplit('/',1)[-1]]
            return {'summary':'AI Daily Plan','description':MARKER}
        cfg={'account':ACCOUNT,'created_by':MARKER,'calendar_id':'test@group.calendar.google.com'}
        with patch('calendar_api.api',side_effect=fake):
            first=apply(None,p,cfg);second=apply(None,p,cfg)
            self.assertEqual(first['inserted'],len(make_events(p)))
            self.assertEqual(second['inserted'],0)
            storage[next(iter(storage))]['summary']='manual edit'
            with self.assertRaises(ValueError):apply(None,p,cfg)
    def test_omitted_opaque_default_matches(self):
        e=make_events(self.plan())[0];actual=copy.deepcopy(e)
        actual.pop('transparency')
        self.assertTrue(matches(actual,e))
        actual['transparency']='transparent'
        self.assertFalse(matches(actual,e))
    def test_matching_normalizes_timezone(self):
        e=make_events(self.plan())[0];actual=copy.deepcopy(e)
        actual['start']['dateTime']='2099-09-06T23:00:00Z'
        self.assertTrue(matches(actual,e))

class CalendarUpdateTests(unittest.TestCase):
    def setUp(self):
        self.plan=CalendarWriteTests().plan()
        self.old=make_events(self.plan)
        self.new=copy.deepcopy(self.plan)
        self.new['generated'][0]['title']='会社の仕事（更新）'
        self.storage={e['id']:dict(copy.deepcopy(e),etag='"v1"') for e in self.old}
        self.writes=[]
        self.cfg={'account':ACCOUNT,'created_by':MARKER,'calendar_id':'test@group.calendar.google.com'}

    def fake(self,s,method,path,body=None,params=None,headers=None):
        if path.endswith('/events'):
            self.assertEqual(method,'GET')
            return {'items':list(self.storage.values())}
        if '/events/' not in path:return {'summary':'AI Daily Plan','description':MARKER}
        uid=path.rsplit('/',1)[-1]
        if method=='PATCH':
            self.assertEqual(headers,{'If-Match':self.storage[uid]['etag']})
            self.assertEqual(params,{'sendUpdates':'none'})
            self.writes.append(uid)
            self.storage[uid].update(copy.deepcopy(body),etag='"v2"')
        return copy.deepcopy(self.storage[uid])

    def test_update_and_identical_retry(self):
        with patch('calendar_api.api',side_effect=self.fake):
            first=apply(None,self.new,self.cfg,self.old)
            retry=apply(None,self.new,self.cfg,self.old)
        self.assertEqual(first['updated'],1)
        self.assertEqual(first['inserted'],0)
        self.assertEqual(retry['updated'],0)
        self.assertEqual(len(self.writes),1)

    def test_manual_edit_preflight_prevents_all_writes(self):
        last=self.old[-1]['id']
        for field,value in [('summary','manual'),('location','manually added')]:
            with self.subTest(field=field):
                saved=copy.deepcopy(self.storage[last])
                self.storage[last][field]=value
                with patch('calendar_api.api',side_effect=self.fake):
                    with self.assertRaises(ValueError):apply(None,self.new,self.cfg,self.old)
                self.assertFalse(self.writes)
                self.storage[last]=saved

    def test_missing_event_is_not_recreated(self):
        self.storage.pop(self.old[-1]['id'])
        with patch('calendar_api.api',side_effect=self.fake):
            with self.assertRaises(ValueError):apply(None,self.new,self.cfg,self.old)
        self.assertFalse(self.writes)

    def test_changed_id_set_rejected(self):
        with patch('calendar_api.api',side_effect=self.fake):
            with self.assertRaises(ValueError):apply(None,self.new,self.cfg,self.old[:-1])
        self.assertFalse(self.writes)

    def test_concurrent_edit_stops_without_retrying_patch(self):
        def concurrent(*args,**kwargs):
            if args[1]=='PATCH':raise RuntimeError('Calendar API HTTP 412')
            return self.fake(*args,**kwargs)
        with patch('calendar_api.api',side_effect=concurrent):
            with self.assertRaisesRegex(RuntimeError,'412'):apply(None,self.new,self.cfg,self.old)
        self.assertFalse(self.writes)

    def test_partial_update_can_resume(self):
        self.new['generated'][1]['title']='休憩 1（更新）'
        count=0
        def interrupted(*args,**kwargs):
            nonlocal count
            if args[1]=='PATCH':
                count+=1
                if count==2:raise RuntimeError('Connection interrupted')
            return self.fake(*args,**kwargs)
        with patch('calendar_api.api',side_effect=interrupted):
            with self.assertRaises(RuntimeError):apply(None,self.new,self.cfg,self.old)
        with patch('calendar_api.api',side_effect=self.fake):
            result=apply(None,self.new,self.cfg,self.old)
        self.assertEqual(result['updated'],1)
        self.assertEqual(result['inserted'],0)
        self.assertEqual(len(self.writes),2)

if __name__=='__main__':unittest.main()
