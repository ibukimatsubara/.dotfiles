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

if __name__=='__main__':unittest.main()
