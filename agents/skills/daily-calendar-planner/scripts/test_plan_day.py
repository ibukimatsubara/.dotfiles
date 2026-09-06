#!/usr/bin/env python3

from __future__ import annotations

import unittest
from datetime import date
from pathlib import Path

from plan_day import (
    PlannerConfig,
    build_plan,
    build_parser,
    build_rhythm_plan,
    load_busy_events,
    load_inline_events,
    parse_hhmm,
)


FIXTURE = Path(__file__).parent / "fixtures" / "scattered-meetings.json"


class DailyPlannerTests(unittest.TestCase):
    def make_plan(self, wake: str) -> dict[str, object]:
        target = date(2026, 9, 7)
        config = PlannerConfig(
            target_date=target,
            wake=parse_hhmm(wake),
            bedtime=parse_hhmm("23:00"),
            work_target=480,
            focus_title="YouTube企画・制作",
            focus_minutes=90,
            shadowing_minutes=30,
            gym_minutes=60,
        )
        return build_plan(config, load_busy_events(FIXTURE, target))

    def test_wake_scenarios_are_complete_and_write_free(self) -> None:
        for wake in ("08:00", "09:00"):
            with self.subTest(wake=wake):
                plan = self.make_plan(wake)
                self.assertTrue(plan["dry_run"])
                self.assertEqual(plan["summary"]["company_minutes"], 480)
                self.assertEqual(plan["summary"]["gym_minutes"], 60)
                self.assertEqual(plan["summary"]["shadowing_minutes"], 30)
                self.assertEqual(plan["summary"]["personal_focus_minutes"], 90)
                titles = [event["title"] for event in plan["events"]]
                self.assertIn("会社ミーティング（朝）", titles)
                self.assertIn("会社ミーティング（夜）", titles)

    def test_timeline_has_no_overlap_for_fixture(self) -> None:
        for wake in ("08:00", "09:00"):
            events = self.make_plan(wake)["events"]
            for left, right in zip(events, events[1:]):
                self.assertLessEqual(
                    parse_hhmm(left["end"]),
                    parse_hhmm(right["start"]),
                    f"overlap in {wake}: {left} and {right}",
                )

    def test_generated_blocks_use_30_minute_units_without_generic_routines(self) -> None:
        for wake in ("08:00", "09:00"):
            plan = self.make_plan(wake)
            generated = [event for event in plan["events"] if event["source"] == "generated"]
            self.assertTrue(all(event["duration_minutes"] % 30 == 0 for event in generated))
            titles = {event["title"] for event in generated}
            self.assertNotIn("起床・身支度", titles)
            self.assertNotIn("入浴・就寝準備", titles)

    def test_mhi_commute_is_mandatory_on_thursday_and_friday(self) -> None:
        for target in (date(2026, 9, 10), date(2026, 9, 11)):
            with self.subTest(target=target):
                config = PlannerConfig(
                    target_date=target,
                    wake=parse_hhmm("08:00"),
                    bedtime=parse_hhmm("23:00"),
                    work_target=0,
                    focus_title="YouTube企画・制作",
                    focus_minutes=90,
                    shadowing_minutes=30,
                    gym_minutes=60,
                    mhi_office_day=True,
                )
                plan = build_plan(config, [])
                by_title = {event["title"]: event for event in plan["events"]}
                self.assertEqual(by_title["MHI出勤準備・移動"]["start"], "08:00")
                self.assertEqual(by_title["MHI出勤準備・移動"]["end"], "09:00")
                self.assertEqual(by_title["MHIから帰宅・移動"]["start"], "17:00")
                self.assertEqual(by_title["MHIから帰宅・移動"]["end"], "18:00")

    def test_inline_events_support_transient_computer_use_input(self) -> None:
        events = load_inline_events(
            ["09:00,10:00,company,会社予定 1", "14:00,14:30,personal,私用予定 1"],
            date(2026, 9, 7),
        )
        self.assertEqual(len(events), 2)
        self.assertTrue(events[0].counts_as_work)
        self.assertFalse(events[1].counts_as_work)

    def test_zero_focus_minutes_supports_a_deliberate_rest_day(self) -> None:
        config = PlannerConfig(
            target_date=date(2026, 9, 13),
            wake=parse_hhmm("08:00"),
            bedtime=parse_hhmm("23:00"),
            work_target=0,
            focus_title="YouTube企画・制作",
            focus_minutes=0,
            shadowing_minutes=30,
            gym_minutes=60,
            mhi_office_day=False,
        )
        plan = build_plan(config, [])
        self.assertEqual(plan["summary"]["personal_focus_minutes"], 0)
        self.assertNotIn(
            "YouTube企画・制作", {event["title"] for event in plan["events"]}
        )

    def test_first_pass_contains_only_exact_work_and_rest_blocks(self) -> None:
        plan = build_rhythm_plan(date(2026, 9, 7), parse_hhmm("08:00"))
        self.assertEqual(
            [
                (event["start"], event["end"], event["category"])
                for event in plan["events"]
            ],
            [
                ("08:00", "12:00", "work"),
                ("12:00", "14:00", "rest"),
                ("14:00", "18:00", "work"),
                ("18:00", "20:00", "rest"),
                ("20:00", "24:00", "work"),
            ],
        )
        self.assertEqual({event["duration_minutes"] for event in plan["events"]}, {120, 240})
        self.assertEqual(plan["end"], "24:00")

    def test_detailed_mode_defaults_to_90_minute_all_inclusive_gym_block(self) -> None:
        args = build_parser().parse_args(
            ["--mode", "detailed", "--date", "2026-09-07", "--wake", "08:00"]
        )
        self.assertEqual(args.gym_minutes, 90)


if __name__ == "__main__":
    unittest.main()
