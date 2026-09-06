import unittest
from datetime import date
from adaptive_day import build, render

DAY=date(2026,9,7)
def envelope(events=()):
    return dict(source='notion-calendar',date=DAY.isoformat(),observed_at='2026-09-06T15:00:00+09:00',
                accounts_checked=['test-only'],coverage_complete=True,coverage_start='2026-09-07T00:00:00+09:00',
                coverage_end='2026-09-09T00:00:00+09:00',events=list(events))
def event(start,end,category='company'):
    return dict(start=f'2026-09-07T{start}:00+09:00',end=f'2026-09-07T{end}:00+09:00',category=category)

class AdaptiveTests(unittest.TestCase):
    def test_scattered_meetings_preserve_time_and_totals(self):
        raw=envelope([event('09:00','10:00'),event('20:00','21:00')])
        for wake in ('06:00','07:30','09:00','10:00'):
            p=build(raw,DAY,wake)
            self.assertEqual(p['summary']['company']['actual'],480)
            self.assertEqual(p['summary']['personal']['actual'],240)
            self.assertEqual(p['summary']['rest1']['actual'],120)
            self.assertEqual(p['summary']['rest2']['actual'],120)
            for a in p['generated']:
                self.assertEqual((a['end']-a['start'])%30,0)
                for b in p['fixed']:
                    self.assertFalse(a['start']<b['end'] and b['start']<a['end'])
            self.assertEqual(p['fixed'][0]['start'],540)
    def test_overlapping_meetings_count_union(self):
        p=build(envelope([event('09:00','11:00'),event('10:00','12:00')]),DAY,'07:30')
        self.assertEqual(p['summary']['company']['actual'],480)
        self.assertTrue(p['warnings'])
        self.assertEqual(sum(e['end']-e['start'] for e in p['generated'] if e['category']=='company'),300)
    def test_insufficient_capacity_is_visible(self):
        p=build(envelope([event('08:00','23:00','fixed')]),DAY,'07:30')
        self.assertEqual(p['status'],'needs_review')
        self.assertTrue(any('不足' in w for w in p['warnings']))
    def test_evening_meetings_do_not_cluster_breaks(self):
        raw=envelope([event('18:00','18:30'),event('18:30','19:30'),
                      event('19:30','20:30'),event('21:00','22:00')])
        p=build(raw,DAY,'08:00',gym=True)
        rests=[e for e in p['generated'] if e['category'].startswith('rest')]
        self.assertTrue(all(e['end']-e['start'] >= 60 for e in rests))
        self.assertTrue(all(b['start']-a['end'] >= 120 for a,b in zip(rests,rests[1:])))
        self.assertEqual(p['summary']['company']['actual'],480)
        self.assertEqual(p['summary']['personal']['actual'],240)
        self.assertEqual(sum(e['end']-e['start'] for e in rests),240)
        self.assertTrue(any('ジム' in e.get('detail','') for e in rests))
        self.assertFalse(p['warnings'])

    def test_isolated_half_hours_are_never_breaks(self):
        p=build(envelope([event('08:30','23:30','fixed')]),DAY,'08:00')
        self.assertFalse(any(e['category'].startswith('rest') for e in p['generated']))
        self.assertEqual(p['status'],'needs_review')

    def test_short_available_window_allows_one_hour_break(self):
        p=build(envelope([event('09:00','23:30','fixed')]),DAY,'08:00')
        rests=[e for e in p['generated'] if e['category'].startswith('rest')]
        self.assertEqual([e['end']-e['start'] for e in rests],[60])
        self.assertTrue(p['warnings'])

    def test_missing_acquisition_and_coverage_rejected(self):
        for field,value in [('coverage_complete',False),('source','synthetic'),('date','2026-09-08'),('coverage_end','2026-09-07T23:00:00+09:00')]:
            raw=envelope();raw[field]=value
            with self.assertRaises(ValueError):build(raw,DAY,'07:30')
    def test_exact_odd_times_and_overnight_preserved(self):
        raw=envelope([event('09:10','10:05')]);raw['events'].append(dict(start='2026-09-07T23:00:00+09:00',end='2026-09-08T01:00:00+09:00',category='company'))
        p=build(raw,DAY,'09:00')
        self.assertEqual(p['fixed'][0]['start'],550)
        self.assertEqual(p['fixed'][1]['end'],1500)
        self.assertTrue(p['warnings'])
    def test_free_all_day_and_html_escaping(self):
        raw=envelope([dict(all_day=True,availability='free')]);raw['observed_at']='<script>bad</script>'
        p=build(raw,DAY,'07:30',gym=True)
        self.assertFalse(p['fixed'])
        self.assertTrue(p['reminders'])
        self.assertNotIn('<script>',render(p))
        self.assertTrue(any('ジム' in e.get('detail','') for e in p['generated']))

if __name__=='__main__':unittest.main()
