#!/usr/bin/env python3
"""Build a deterministic, write-free daily rhythm or detailed schedule."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from datetime import date as Date
from datetime import datetime
from pathlib import Path
from typing import Iterable, Sequence


GRID_MINUTES = 30


@dataclass(frozen=True)
class Interval:
    start: int
    end: int
    title: str
    category: str
    source: str = "generated"
    counts_as_work: bool = False

    @property
    def duration(self) -> int:
        return self.end - self.start

    def to_dict(self) -> dict[str, object]:
        result = asdict(self)
        result["start"] = format_hhmm(self.start)
        result["end"] = format_hhmm(self.end)
        result["duration_minutes"] = self.duration
        return result


@dataclass(frozen=True)
class PlannerConfig:
    target_date: Date
    wake: int
    bedtime: int
    work_target: int
    focus_title: str
    focus_minutes: int
    shadowing_minutes: int
    gym_minutes: int
    mhi_office_day: bool = False


def build_rhythm_plan(target_date: Date, wake: int) -> dict[str, object]:
    """Create the owner's first-pass 4h/2h rhythm without assigning tasks."""
    pattern = (
        ("仕事 1", "work", 240),
        ("休憩 1", "rest", 120),
        ("仕事 2", "work", 240),
        ("休憩 2", "rest", 120),
        ("仕事 3", "work", 240),
    )
    cursor = wake
    events: list[Interval] = []
    for title, category, duration in pattern:
        events.append(Interval(cursor, cursor + duration, title, category))
        cursor += duration
    return {
        "dry_run": True,
        "mode": "rhythm",
        "date": target_date.isoformat(),
        "wake": format_hhmm(wake),
        "end": format_hhmm(cursor),
        "events": [item.to_dict() for item in events],
        "assumptions": [
            "第一段階では仕事と休憩の骨格だけを作り、個別タスクを割り当てない。",
            "食事、ジム、移動などは2時間の休憩の中身であり、30分後に仕事へ戻す意味ではない。",
            "会社、自分の仕事、会議などの詳細は、骨格を確認した後の第二段階で決める。",
        ],
    }


def parse_hhmm(value: str) -> int:
    try:
        hour_text, minute_text = value.split(":", 1)
        hour = int(hour_text)
        minute = int(minute_text)
    except (ValueError, AttributeError) as exc:
        raise ValueError(f"Invalid time {value!r}; expected HH:MM") from exc
    if not 0 <= hour <= 23 or not 0 <= minute <= 59:
        raise ValueError(f"Invalid time {value!r}; expected HH:MM")
    return hour * 60 + minute


def format_hhmm(value: int) -> str:
    return f"{value // 60:02d}:{value % 60:02d}"


def parse_event_time(value: str, target_date: Date) -> int | None:
    if "T" not in value:
        return parse_hhmm(value)
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.date() != target_date:
        return None
    return parsed.hour * 60 + parsed.minute


def overlaps(left: Interval, right: Interval) -> bool:
    return left.start < right.end and right.start < left.end


def slot_is_free(start: int, end: int, intervals: Sequence[Interval]) -> bool:
    candidate = Interval(start, end, "candidate", "candidate")
    return all(not overlaps(candidate, item) for item in intervals)


def aligned_range(start: int, end: int, duration: int) -> list[int]:
    first = ((start + GRID_MINUTES - 1) // GRID_MINUTES) * GRID_MINUTES
    return list(range(first, end - duration + 1, GRID_MINUTES))


def find_near_slot(
    intervals: Sequence[Interval],
    *,
    window_start: int,
    window_end: int,
    preferred: int,
    duration: int,
) -> tuple[int, int] | None:
    candidates = aligned_range(window_start, window_end, duration)
    candidates.sort(key=lambda value: (abs(value - preferred), value))
    for start in candidates:
        end = start + duration
        if slot_is_free(start, end, intervals):
            return start, end
    return None


def merged_ranges(intervals: Iterable[Interval]) -> list[tuple[int, int]]:
    ranges = sorted((item.start, item.end) for item in intervals if item.end > item.start)
    merged: list[tuple[int, int]] = []
    for start, end in ranges:
        if not merged or start > merged[-1][1]:
            merged.append((start, end))
        else:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
    return merged


def union_minutes(intervals: Iterable[Interval]) -> int:
    return sum(end - start for start, end in merged_ranges(intervals))


def free_gaps(
    intervals: Sequence[Interval], window_start: int, window_end: int
) -> list[tuple[int, int]]:
    clipped = [
        Interval(
            max(window_start, item.start),
            min(window_end, item.end),
            item.title,
            item.category,
        )
        for item in intervals
        if item.end > window_start and item.start < window_end
    ]
    ranges = merged_ranges(clipped)
    gaps: list[tuple[int, int]] = []
    cursor = window_start
    for start, end in ranges:
        if cursor < start:
            gaps.append((cursor, start))
        cursor = max(cursor, end)
    if cursor < window_end:
        gaps.append((cursor, window_end))
    return gaps


def parse_busy_events(raw_events: Sequence[dict[str, object]], target_date: Date) -> list[Interval]:
    events: list[Interval] = []
    for index, raw in enumerate(raw_events, start=1):
        start = parse_event_time(str(raw["start"]), target_date)
        end = parse_event_time(str(raw["end"]), target_date)
        if start is None or end is None:
            continue
        if end <= start:
            raise ValueError(f"Busy event {index} must end after it starts")
        category = str(raw.get("category", "fixed"))
        events.append(
            Interval(
                start=start,
                end=end,
                title=str(raw.get("title", f"固定予定 {index}")),
                category=category,
                source="fixed",
                counts_as_work=category in {"company", "company_meeting"},
            )
        )
    return events


def load_busy_events(path: Path | None, target_date: Date) -> list[Interval]:
    if path is None:
        return []
    payload = json.loads(path.read_text(encoding="utf-8"))
    raw_events = payload.get("events", []) if isinstance(payload, dict) else payload
    return parse_busy_events(raw_events, target_date)


def load_inline_events(specs: Sequence[str], target_date: Date) -> list[Interval]:
    raw_events: list[dict[str, object]] = []
    for index, spec in enumerate(specs, start=1):
        parts = spec.split(",", 3)
        if len(parts) != 4:
            raise ValueError(
                f"Inline event {index} must be START,END,CATEGORY,TITLE; got {spec!r}"
            )
        start, end, category, title = (part.strip() for part in parts)
        raw_events.append(
            {"start": start, "end": end, "category": category, "title": title}
        )
    return parse_busy_events(raw_events, target_date)


def gym_title(target_date: Date) -> str:
    names = {
        0: "ジム: Push A（胸メイン）",
        1: "ジム: Pull A（背中・腕）",
        2: "ジム: Legs A（脚・カーフ）",
        3: "ジム: Push B（胸・肩）",
        4: "ジム: Pull B（背中・腕）",
        5: "ジム: Legs B＋弱点",
        6: "ジム: 回復・最小デー",
    }
    return names[target_date.weekday()]


def add_preferred(
    events: list[Interval],
    warnings: list[str],
    *,
    title: str,
    category: str,
    window_start: int,
    window_end: int,
    preferred: int,
    duration: int,
    counts_as_work: bool = False,
    fallback_duration: int | None = None,
) -> Interval | None:
    slot = find_near_slot(
        events,
        window_start=window_start,
        window_end=window_end,
        preferred=preferred,
        duration=duration,
    )
    actual_duration = duration
    if slot is None and fallback_duration is not None:
        slot = find_near_slot(
            events,
            window_start=window_start,
            window_end=window_end,
            preferred=preferred,
            duration=fallback_duration,
        )
        actual_duration = fallback_duration
    if slot is None:
        warnings.append(f"{title}を配置できませんでした。")
        return None
    if actual_duration != duration:
        warnings.append(
            f"{title}は{duration}分を確保できず、{actual_duration}分へ短縮しました。"
        )
    result = Interval(
        start=slot[0],
        end=slot[1],
        title=title if actual_duration == duration else f"{title}（短縮版）",
        category=category,
        counts_as_work=counts_as_work,
    )
    events.append(result)
    return result


def add_company_transitions(
    events: list[Interval], config: PlannerConfig, warnings: list[str]
) -> None:
    company_fixed = [item for item in events if item.source == "fixed" and item.counts_as_work]
    for index, fixed in enumerate(company_fixed, start=1):
        if fixed.start <= config.wake + GRID_MINUTES:
            warnings.append(
                f"{fixed.title}が起床直後に始まるため、事前準備時間を確保できません。"
            )
        for start, end, label in (
            (fixed.start - GRID_MINUTES, fixed.start, "準備"),
            (fixed.end, fixed.end + GRID_MINUTES, "切り替え"),
        ):
            if start < config.wake or end > config.bedtime:
                continue
            if slot_is_free(start, end, events):
                events.append(
                    Interval(
                        start,
                        end,
                        f"会社予定 {index}: {label}",
                        "company_transition",
                        counts_as_work=True,
                    )
                )


def add_mhi_commute(
    events: list[Interval], config: PlannerConfig, warnings: list[str]
) -> None:
    if not config.mhi_office_day:
        return
    commute_blocks = (
        Interval(
            parse_hhmm("08:00"),
            parse_hhmm("09:00"),
            "MHI出勤準備・移動",
            "commute",
        ),
        Interval(
            parse_hhmm("17:00"),
            parse_hhmm("18:00"),
            "MHIから帰宅・移動",
            "commute",
        ),
    )
    if config.wake > commute_blocks[0].start:
        warnings.append("MHI出勤日は8:00に準備・移動を始める必要があります。")
    for commute in commute_blocks:
        conflicts = [item.title for item in events if overlaps(commute, item)]
        if conflicts:
            warnings.append(
                f"{commute.title}が固定予定（{', '.join(conflicts)}）と重なっています。"
            )
        events.append(commute)


def add_company_work(
    events: list[Interval], config: PlannerConfig, warnings: list[str]
) -> None:
    current = union_minutes(item for item in events if item.counts_as_work)
    remaining = max(0, config.work_target - current)
    block_index = 1
    for gap_start, gap_end in free_gaps(events, config.wake, config.bedtime):
        if remaining < GRID_MINUTES:
            break
        available = ((gap_end - gap_start) // GRID_MINUTES) * GRID_MINUTES
        schedulable_remaining = (remaining // GRID_MINUTES) * GRID_MINUTES
        duration = min(240, available, schedulable_remaining)
        if duration < GRID_MINUTES:
            continue
        events.append(
            Interval(
                gap_start,
                gap_start + duration,
                f"会社: 集中作業 {block_index}",
                "company_work",
                counts_as_work=True,
            )
        )
        remaining -= duration
        block_index += 1

    if remaining:
        warnings.append(
            f"会社時間は目安より{remaining}分不足しています。固定予定と生活時間を優先しました。"
        )


def build_plan(config: PlannerConfig, busy_events: Sequence[Interval]) -> dict[str, object]:
    if config.bedtime <= config.wake:
        raise ValueError("Bedtime must be later than wake time in this daily dry run")
    if config.focus_minutes < 0 or config.focus_minutes % GRID_MINUTES:
        raise ValueError("focus duration must be zero or a positive 30-minute unit")
    for label, duration in (
        ("shadowing", config.shadowing_minutes),
        ("gym", config.gym_minutes),
    ):
        if duration < GRID_MINUTES or duration % GRID_MINUTES:
            raise ValueError(f"{label} duration must be a positive 30-minute unit")
    if config.work_target < 0:
        raise ValueError("Work target cannot be negative")

    warnings: list[str] = []
    events = [
        Interval(
            max(config.wake, item.start),
            min(config.bedtime, item.end),
            item.title,
            item.category,
            item.source,
            item.counts_as_work,
        )
        for item in busy_events
        if item.end > config.wake and item.start < config.bedtime
    ]

    add_mhi_commute(events, config, warnings)
    add_company_transitions(events, config, warnings)

    gym_duration = 30 if config.target_date.weekday() == 6 else config.gym_minutes
    add_preferred(
        events,
        warnings,
        title=gym_title(config.target_date),
        category="gym",
        window_start=max(config.wake, parse_hhmm("11:00")),
        window_end=min(config.bedtime, parse_hhmm("18:00")),
        preferred=parse_hhmm("11:00"),
        duration=gym_duration,
        fallback_duration=30 if gym_duration > 30 else None,
    )

    add_preferred(
        events,
        warnings,
        title="昼食",
        category="meal",
        window_start=max(config.wake, parse_hhmm("12:00")),
        window_end=min(config.bedtime, parse_hhmm("15:00")),
        preferred=parse_hhmm("12:00"),
        duration=30,
    )
    add_preferred(
        events,
        warnings,
        title="夕食",
        category="meal",
        window_start=max(config.wake, parse_hhmm("16:30")),
        window_end=min(config.bedtime, parse_hhmm("18:00")),
        preferred=parse_hhmm("17:15"),
        duration=30,
    )
    add_preferred(
        events,
        warnings,
        title="英語・中国語シャドーイング",
        category="learning",
        window_start=max(config.wake, parse_hhmm("12:00")),
        window_end=min(config.bedtime, parse_hhmm("21:00")),
        preferred=parse_hhmm("16:45"),
        duration=config.shadowing_minutes,
    )
    add_company_work(events, config, warnings)

    focus = None
    if config.focus_minutes:
        focus = add_preferred(
            events,
            warnings,
            title=config.focus_title,
            category="personal_focus",
            window_start=config.wake,
            window_end=min(config.bedtime, parse_hhmm("22:30")),
            preferred=parse_hhmm("19:00"),
            duration=config.focus_minutes,
            fallback_duration=60,
        )

    occupied = list(events)
    for start, end in free_gaps(occupied, config.wake, config.bedtime):
        duration = ((end - start) // GRID_MINUTES) * GRID_MINUTES
        if duration >= GRID_MINUTES:
            events.append(Interval(start, start + duration, "余白・休憩", "free"))

    events.sort(key=lambda item: (item.start, item.end, item.source != "fixed"))
    company_minutes = union_minutes(item for item in events if item.counts_as_work)
    free_minutes = sum(item.duration for item in events if item.category == "free")
    return {
        "dry_run": True,
        "date": config.target_date.isoformat(),
        "wake": format_hhmm(config.wake),
        "bedtime": format_hhmm(config.bedtime),
        "events": [item.to_dict() for item in events],
        "summary": {
            "company_minutes": company_minutes,
            "company_target_minutes": config.work_target,
            "shadowing_minutes": sum(
                item.duration for item in events if item.category == "learning"
            ),
            "gym_minutes": sum(item.duration for item in events if item.category == "gym"),
            "personal_focus_minutes": focus.duration if focus else 0,
            "free_minutes": free_minutes,
        },
        "assumptions": [
            "生成予定は30分単位とし、固定予定の実時刻は変更しない。",
            "固定された会社予定と前後30分の準備・切り替えを会社時間へ含める。",
            "平日の会社時間は8時間を仮置きし、CLIで変更できる。",
            f"ジム{config.gym_minutes}分は往復移動、着替え、トレーニング、シャワーを含む。",
            "シャドーイング30分は英語と中国語の合計で、配分は未決定である。",
            f"個人集中枠は{config.focus_title}を優先する仮置きである。",
            "起床後の身支度、入浴、就寝準備は通常日の予定として生成しない。",
            "木曜・金曜のMHI出勤日は8:00–9:00と17:00–18:00の移動を必須にする。",
            "空き時間をすべて成果枠で埋めず、30分単位の残りを余白として表示する。",
        ],
        "warnings": warnings,
    }


def minutes_label(value: int) -> str:
    hours, minutes = divmod(value, 60)
    if hours and minutes:
        return f"{hours}時間{minutes}分"
    if hours:
        return f"{hours}時間"
    return f"{minutes}分"


def render_markdown(plan: dict[str, object], input_label: str) -> str:
    summary = plan["summary"]
    lines = [
        f"# {plan['date']} daily plan dry run（起床 {plan['wake']}）",
        "",
        "実カレンダーへの書き込み: **なし**",
        f"固定予定の入力: {input_label}",
        "",
        "| 時間 | 予定 | 種類 |",
        "| --- | --- | --- |",
    ]
    for event in plan["events"]:
        fixed = "・固定" if event["source"] == "fixed" else ""
        lines.append(
            f"| {event['start']}–{event['end']} | {event['title']} | "
            f"{event['category']}{fixed} |"
        )
    lines.extend(
        [
            "",
            "## 集計",
            "",
            f"- 会社: {minutes_label(summary['company_minutes'])} / "
            f"目安 {minutes_label(summary['company_target_minutes'])}",
            f"- ジム: {minutes_label(summary['gym_minutes'])}",
            f"- シャドーイング: {minutes_label(summary['shadowing_minutes'])}",
            f"- 個人集中: {minutes_label(summary['personal_focus_minutes'])}",
            f"- 余白: {minutes_label(summary['free_minutes'])}",
            "",
            "## 仮定",
            "",
        ]
    )
    lines.extend(f"- {item}" for item in plan["assumptions"])
    if plan["warnings"]:
        lines.extend(["", "## 警告", ""])
        lines.extend(f"- {item}" for item in plan["warnings"])
    return "\n".join(lines)


def render_rhythm_markdown(plan: dict[str, object]) -> str:
    lines = [
        f"# {plan['date']} work/rest rhythm dry run（開始 {plan['wake']}）",
        "",
        "実カレンダーへの書き込み: **なし**",
        "個別タスクの割り当て: **なし**",
        "",
        "| 時間 | 区分 | 長さ |",
        "| --- | --- | ---: |",
    ]
    for event in plan["events"]:
        lines.append(
            f"| {event['start']}–{event['end']} | {event['title']} | "
            f"{minutes_label(event['duration_minutes'])} |"
        )
    lines.extend(["", "## 仮定", ""])
    lines.extend(f"- {item}" for item in plan["assumptions"])
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mode",
        choices=("rhythm", "detailed"),
        default="rhythm",
        help="rhythm creates only 4h work/2h rest blocks; detailed assigns tasks",
    )
    parser.add_argument("--date", required=True, help="Target date in YYYY-MM-DD")
    parser.add_argument("--wake", required=True, help="Wake time in HH:MM")
    parser.add_argument("--bedtime", default="23:00", help="Bedtime in HH:MM")
    parser.add_argument("--busy-json", type=Path, help="Read-only fixed-event fixture")
    parser.add_argument(
        "--event",
        action="append",
        default=[],
        help="Repeatable START,END,CATEGORY,TITLE fixed interval",
    )
    parser.add_argument("--work-target-minutes", type=int, default=None)
    parser.add_argument("--focus-title", default="YouTube企画・制作")
    parser.add_argument("--focus-minutes", type=int, default=90)
    parser.add_argument("--shadowing-minutes", type=int, default=30)
    parser.add_argument("--gym-minutes", type=int, default=90)
    parser.add_argument(
        "--mhi-office-day",
        choices=("auto", "yes", "no"),
        default="auto",
        help="Add mandatory MHI commute blocks; auto enables Thursday and Friday",
    )
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    target_date = Date.fromisoformat(args.date)
    if args.mode == "rhythm":
        if args.busy_json or args.event:
            raise ValueError("Fixed events require --mode detailed")
        plan = build_rhythm_plan(target_date, parse_hhmm(args.wake))
        if args.format == "json":
            print(json.dumps(plan, ensure_ascii=False, indent=2))
        else:
            print(render_rhythm_markdown(plan))
        return 0

    work_target = args.work_target_minutes
    if work_target is None:
        work_target = 480 if target_date.weekday() < 5 else 0
    mhi_office_day = args.mhi_office_day == "yes" or (
        args.mhi_office_day == "auto" and target_date.weekday() in {3, 4}
    )
    config = PlannerConfig(
        target_date=target_date,
        wake=parse_hhmm(args.wake),
        bedtime=parse_hhmm(args.bedtime),
        work_target=work_target,
        focus_title=args.focus_title,
        focus_minutes=args.focus_minutes,
        shadowing_minutes=args.shadowing_minutes,
        gym_minutes=args.gym_minutes,
        mhi_office_day=mhi_office_day,
    )
    busy_events = load_busy_events(args.busy_json, target_date)
    busy_events.extend(load_inline_events(args.event, target_date))
    plan = build_plan(config, busy_events)
    if args.format == "json":
        print(json.dumps(plan, ensure_ascii=False, indent=2))
    else:
        inputs = []
        if args.busy_json:
            inputs.append(str(args.busy_json))
        if args.event:
            inputs.append(f"inline events × {len(args.event)}")
        input_label = " / ".join(inputs) if inputs else "なし"
        print(render_markdown(plan, input_label))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
