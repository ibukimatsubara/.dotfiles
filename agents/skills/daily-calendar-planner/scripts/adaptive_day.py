#!/usr/bin/env python3
"""Read-only allocation engine; calendar acquisition belongs to the Codex skill."""
import argparse
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from html import escape
import json
from pathlib import Path
import sys

TZ = ZoneInfo('Asia/Tokyo')
LABELS = {'company': '会社の仕事', 'personal': '自分の活動', 'rest1': '休憩 1', 'rest2': '休憩 2'}


def minute(value, day):
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('Event timestamps require a timezone')
    return int((parsed.astimezone(TZ) - datetime.combine(day, datetime.min.time(), TZ)).total_seconds() // 60)


def clock(value):
    offset, value = divmod(value, 1440)
    return ('翌日 ' if offset == 1 else f'{offset:+}日 ' if offset else '') + f'{value//60:02}:{value%60:02}'


def union(ranges):
    result = []
    for a, b in sorted(ranges):
        if result and a <= result[-1][1]:
            result[-1] = (result[-1][0], max(b, result[-1][1]))
        else:
            result.append((a, b))
    return result


def build(payload, day, wake, gym=False):
    if payload.get('source') != 'notion-calendar' or payload.get('coverage_complete') is not True:
        raise ValueError('Actual Notion Calendar acquisition with complete coverage is required')
    if payload.get('date') != day.isoformat():
        raise ValueError('Calendar acquisition date differs from target date')
    if not payload.get('observed_at') or not payload.get('accounts_checked'):
        raise ValueError('Acquisition timestamp and account coverage are required')
    start = int(wake[:2])*60 + int(wake[3:])
    if len(wake) != 5 or wake[2] != ':' or not 0 <= start < 1440 or not 0 <= int(wake[3:]) < 60:
        raise ValueError('Wake time must be HH:MM')
    end = start + 960
    if minute(payload['coverage_start'], day) > start or minute(payload['coverage_end'], day) < end:
        raise ValueError('Calendar coverage must include the entire 16-hour horizon, including the next day')
    fixed, reminders, warnings = [], [], []
    for index, raw in enumerate(payload.get('events', []), 1):
        category = raw.get('category', 'fixed')
        if category not in ('company', 'personal', 'rest', 'fixed', 'commute'):
            raise ValueError('Unknown event category')
        title = f'会社予定 {index}' if category == 'company' else f'固定予定 {index}'
        if raw.get('all_day') and raw.get('availability') == 'free':
            reminders.append('終日リマインダー（空き扱い・時間拘束なし）')
            continue
        a, b = minute(raw['start'], day), minute(raw['end'], day)
        if b <= a:
            raise ValueError('Event end must be after start')
        fixed.append(dict(start=a, end=b, category=category, title=title, source='fixed'))
    for i, left in enumerate(fixed):
        for right in fixed[i+1:]:
            if max(left['start'], right['start']) < min(left['end'], right['end']):
                warnings.append(f"固定予定の重複: {left['title']} / {right['title']}。元の時刻を保持。")
    def fixed_minutes(category):
        return sum(b-a for a,b in union([(max(start,e['start']),min(end,e['end'])) for e in fixed if e['category']==category and e['end']>start and e['start']<end]))
    company = fixed_minutes('company')
    personal = fixed_minutes('personal')
    targets = {'company': max(0,480-company), 'personal': max(0,240-personal), 'rest1':120, 'rest2':120}
    if company > 480:
        warnings.append(f'固定会社予定だけで8時間を{company-480}分超過。')
    # Only complete 30-minute intervals in free gaps are eligible. Never round fixed events.
    busy = union([(max(start,e['start']),min(end,e['end'])) for e in fixed if e['end']>start and e['start']<end])
    slots, cursor = [], start
    for a,b in busy + [(end,end)]:
        while cursor+30 <= a:
            slots.append(cursor)
            cursor += 30
        cursor = b
    quotas = tuple(targets[k]//30 for k in LABELS)
    keys = tuple(LABELS)
    # Each rest action occupies >=60 consecutive minutes. The cooldown tracks
    # elapsed time since the last break, capped at the preferred two-hour gap.
    # Keep idle transitions so isolated 30-minute gaps never force short breaks.
    layers = [{} for _ in range(len(slots)+1)]
    layers[0][(0,0,0,0,-1,120)] = (0, ())
    for n,t in enumerate(slots):
        for state,(cost,path) in layers[n].items():
            for k in range(-1,len(keys)):
                key = keys[k] if k >= 0 else None
                lengths = (2,3,4) if k >= 2 else (1,)
                for length in lengths:
                    if n+length > len(slots) or slots[n+length-1] != t+30*(length-1):
                        continue
                    if k >= 0 and state[k]+length > quotas[k]:
                        continue
                    if key == 'rest2' and state[2] < quotas[2]:
                        continue
                    gap = state[5]
                    continuing_rest = k >= 2 and state[4] == k and gap == 0
                    if k >= 2 and gap == 0 and not continuing_rest:
                        continue
                    counts = list(state[:4])
                    if k >= 0:
                        counts[k] += length
                    penalty = 2 if state[4] not in (-1,k) else 0
                    if k >= 2 and not continuing_rest:
                        penalty += 40 * max(0,120-gap)/30
                    for offset in range(length):
                        at = t+30*offset
                        preferred = 'company' if at < start+240 or start+360 <= at < start+600 else 'rest1' if at < start+360 else 'rest2' if at < start+720 else 'personal'
                        penalty += 0 if key == preferred else 3
                        if k >= 2:
                            ideal = start + (240 if key == 'rest1' else 600)
                            penalty += abs(at-ideal)/240
                    next_time = slots[n+length] if n+length < len(slots) else end
                    cooldown = min(120, next_time-(t+30*length) if k >= 2 else gap+next_time-t)
                    new = (*counts,k,cooldown)
                    val = (cost+penalty,path+(k,)*length)
                    nxt = layers[n+length]
                    if new not in nxt or val[0] < nxt[new][0]:
                        nxt[new] = val
        layers[n].clear()
    # Preserve recovery first, then company, then personal time when capacity is
    # insufficient. Spacing is a preference; the one-hour break minimum is hard.
    state,(cost,path) = min(layers[-1].items(),key=lambda item:(
        quotas[2]-item[0][2]+quotas[3]-item[0][3],
        quotas[0]-item[0][0], quotas[1]-item[0][1], item[1][0]))
    generated = []
    for t,k in zip(slots,path):
        if k < 0:
            continue
        category = keys[k]
        if generated and generated[-1]['end']==t and generated[-1]['category']==category:
            generated[-1]['end'] = t+30
        else:
            generated.append(dict(start=t,end=t+30,category=category,title=LABELS[category],source='generated'))
    breaks = [e for e in generated if e['category'].startswith('rest')]
    for previous, current in zip(breaks, breaks[1:]):
        if current['start']-previous['end'] < 120:
            warnings.append('休憩間の間隔が2時間未満です。固定予定と時間目標を維持した配置のため、見直し候補。')
    summary = {}
    for k,key in enumerate(keys):
        actual = state[k]*30 + (company if key=='company' else personal if key=='personal' else 0)
        target = 480 if key=='company' else 240 if key=='personal' else 120
        summary[key] = dict(actual=actual,target=target)
        if actual < target:
            warnings.append(f'{LABELS[key]}が{target-actual}分不足。固定予定を維持し、短縮は未承認。')
    for e in generated:
        if e['category']=='personal' and e['end']-e['start']>=30:
            e['detail']='最初の30分: 英語・中国語シャドーイング。残り: YouTube / Mibuki（配分案）。'
            break
    if gym:
        candidates=[e for e in generated if e['category'].startswith('rest') and e['end']-e['start']>=90 and e['start']<1020]
        if candidates:
            e=candidates[0];e['detail']='最初の90分: ジム（往復・着替え・シャワー込み）。残りも休憩。'
        else:
            warnings.append('ジム90分の連続休憩枠を確保できません。短縮せず、配置の見直し候補。')
    if fixed_minutes('rest'):
        warnings.append('固定の休息予定は自由な休憩枠へ自動算入していません。重複する休息目標の確認が必要。')
    occupied = union([(max(start,e['start']),min(end,e['end'])) for e in fixed+generated if e['end']>start and e['start']<end])
    unallocated=960-sum(b-a for a,b in occupied)
    if unallocated:
        warnings.append(f'未配分{unallocated}分（固定予定の端数または目標超過）。休憩や仕事へ勝手に算入しません。')
    return dict(date=day.isoformat(),wake=wake,start=start,end=end,fixed=fixed,generated=generated,
                reminders=reminders,summary=summary,warnings=warnings,observed_at=payload['observed_at'],
                status='needs_review' if warnings else 'proposal',dry_run=True)


def render(plan):
    cards=''.join(f'<div class="metric {k}"><span>{LABELS[k]}</span><strong>{v["actual"]/60:g}<small> / {v["target"]/60:g} 時間</small></strong></div>' for k,v in plan['summary'].items())
    rows=''
    for e in sorted(plan['fixed']+plan['generated'],key=lambda e:(e['start'],e['end'])):
        fixed=e['source']=='fixed'
        rows+=f'<tr class="{escape(e["category"])}"><td>{clock(e["start"])}–{clock(e["end"])}</td><td><span class="badge">{"固定・実カレンダー" if fixed else "自動生成案"}</span> {escape(e["title"])}<p>{escape(e.get("detail",""))}</p></td><td>{(e["end"]-e["start"])/60:g} 時間</td></tr>'
    warnings=''.join(f'<li>{escape(w)}</li>' for w in plan['warnings']) or '<li>時間不足・固定予定との衝突なし。</li>'
    reminders=''.join(f'<li>{escape(r)}</li>' for r in plan['reminders']) or '<li>なし</li>'
    return f'''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{plan['date']} 一日の計画</title><style>
    *{{box-sizing:border-box}}body{{margin:0;background:#f4f5f0;color:#202b2a;font:16px/1.65 -apple-system,BlinkMacSystemFont,sans-serif}}main{{max-width:1080px;margin:auto;padding:48px 24px}}.eyebrow{{letter-spacing:.13em;color:#52716a;font-size:12px}}h1{{font-size:40px;line-height:1.2;margin:12px 0}}.intro{{color:#576760}}.metrics{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:28px 0}}.metric{{background:white;border-top:4px solid #3874b7;padding:16px;border-radius:10px}}.metric span,.metric strong{{display:block}}strong{{font-size:32px}}small{{font-size:14px;font-weight:400}}.personal{{--color:#8465bc}}.company{{--color:#3874b7}}.rest1,.rest2,.rest{{--color:#2e9274}}.metric{{border-color:var(--color)}}table{{width:100%;border-collapse:collapse;background:white;border-radius:12px;overflow:hidden}}th,td{{text-align:left;padding:15px 18px;border-bottom:1px solid #e8ece8}}th{{background:#e8ede7;font-size:13px}}td:first-child{{white-space:nowrap;border-left:5px solid var(--color,#8a8e92);width:200px;font-variant-numeric:tabular-nums}}td:last-child{{white-space:nowrap}}td p{{margin:4px 0 0;font-size:13px;color:#65716e}}.badge{{font-size:11px;border:1px solid #bcc8c2;border-radius:4px;padding:3px 5px;margin-right:6px}}section{{background:#fff;padding:20px 24px;border-radius:12px;margin-top:18px}}h2{{font-size:18px;margin:0 0 8px}}footer{{font-size:12px;color:#65716e;margin:24px 0}}@media(max-width:700px){{.metrics{{grid-template-columns:1fr 1fr}}main{{padding:24px 12px}}h1{{font-size:30px}}th,td{{padding:10px 8px}}td:first-child{{width:auto}}}}
    </style><main><div class="eyebrow">一日の計画 · レビュー用</div><h1>{plan['date']}<br>{plan['wake']} からの一日</h1><p class="intro">終了目安 {clock(plan['end'])} · 実カレンダーを読み取り済み · 予定の書き込みなし</p><div class="metrics">{cards}</div><table><thead><tr><th>時間</th><th>仕事と休憩</th><th>長さ</th></tr></thead><tbody>{rows}</tbody></table><section><h2>制約と確認事項</h2><ul>{warnings}</ul><p>会社予定を会社8時間に含めています。休憩1・2はそれぞれ合計2時間が基準。各休憩は最低1時間、休憩間はなるべく2時間以上空けます。青は会社、紫は自分の活動、緑は休憩です。</p></section><section><h2>終日予定</h2><ul>{reminders}</ul></section><footer>取得: {escape(plan['observed_at'])} · Asia/Tokyo<br>固定予定は名称を匿名化。HTMLは確認用のローカル成果物です。</footer></main></html>'''


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--date',default='today')
    parser.add_argument('--wake')
    parser.add_argument('--gym',action='store_true')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    now=datetime.now(TZ)
    day=now.date()+timedelta(days=1) if args.date=='tomorrow' else now.date() if args.date=='today' else datetime.fromisoformat(args.date).date()
    if not args.wake and day!=now.date():
        parser.error('Future dates require an explicit wake time')
    payload=json.load(sys.stdin)
    plan=build(payload,day,args.wake or now.strftime('%H:%M'),args.gym)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(render(plan),encoding='utf-8')
    print(json.dumps({'output':str(args.output.resolve()),'status':plan['status'],'summary':plan['summary'],'warnings':plan['warnings']},ensure_ascii=False))

if __name__=='__main__':
    main()
