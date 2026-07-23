import copy
import json
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker, RefResolver

ROOT = Path(__file__).parent / "v1"


def load(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def validator(name):
    schema = load(name)
    Draft202012Validator.check_schema(schema)
    documents = {
        path.name: json.loads(path.read_text(encoding="utf-8"))
        for path in ROOT.glob("*.schema.json")
    }
    store = {}
    for file_name, document in documents.items():
        store[(ROOT / file_name).as_uri()] = document
        if "$id" in document:
            store[document["$id"]] = document
    return Draft202012Validator(
        schema,
        resolver=RefResolver.from_schema(schema, store=store),
        format_checker=FormatChecker(),
    )


def assert_valid(schema_name, fixture_name):
    errors = list(validator(schema_name).iter_errors(load(f"fixtures/{fixture_name}")))
    assert not errors, "\n".join(error.message for error in errors)


def test_all_schemas_are_draft_2020_12():
    for path in ROOT.glob("*.schema.json"):
        Draft202012Validator.check_schema(json.loads(path.read_text(encoding="utf-8")))


def test_valid_fixtures():
    assert_valid("engine_info.schema.json", "engine_info.valid.json")
    assert_valid("cycle_request.schema.json", "cycle_request.valid.json")
    assert_valid("forever_request.schema.json", "forever_request.valid.json")
    assert_valid("cycle_configuration.schema.json", "cycle_configuration.valid.json")


def test_cycle_configuration_rejects_unknown_keys():
    value = load("fixtures/cycle_configuration.valid.json")
    value["unexpected"] = True
    assert list(validator("cycle_configuration.schema.json").iter_errors(value))
    value = load("fixtures/cycle_configuration.valid.json")
    value["template"]["unexpected"] = True
    assert list(validator("cycle_configuration.schema.json").iter_errors(value))


def test_cycle_configuration_max_mode_is_conditional():
    value = load("fixtures/cycle_configuration.valid.json")
    del value["maxes"]["values"]["squat"]["repetitions"]
    assert list(validator("cycle_configuration.schema.json").iter_errors(value))
    value["maxes"]["mode"] = "oneRepMax"
    value["maxes"]["values"] = {
        "squat": {
            "weight": {"centiUnits": 14000, "unit": "kg"},
            "repetitions": 3,
        }
    }
    assert list(validator("cycle_configuration.schema.json").iter_errors(value))


def test_cycle_configuration_equipment_requires_exactly_one_bar_source():
    value = load("fixtures/cycle_configuration.valid.json")
    value["equipment"]["bar"] = {
        "weight": {"centiUnits": 2000, "unit": "kg"},
        "platesPerSide": [
            {"centiUnits": 2000, "unit": "kg"},
            {"centiUnits": 1500, "unit": "kg"},
        ],
    }
    assert list(validator("cycle_configuration.schema.json").iter_errors(value))
    del value["equipment"]["barProfileId"]
    assert not list(validator("cycle_configuration.schema.json").iter_errors(value))


def test_cycle_configuration_rejects_invalid_start_date():
    value = load("fixtures/cycle_configuration.valid.json")
    value["schedule"]["startDate"] = "next Monday"
    assert list(validator("cycle_configuration.schema.json").iter_errors(value))


def test_unknown_key_is_rejected():
    value = load("fixtures/cycle_request.valid.json")
    value["unexpected"] = True
    assert list(validator("cycle_request.schema.json").iter_errors(value))


def test_unknown_nested_option_key_is_rejected():
    value = load("fixtures/cycle_request.valid.json")
    value["options"]["joker"]["unexpected"] = True
    assert list(validator("cycle_request.schema.json").iter_errors(value))


def test_inactive_option_children_are_rejected():
    value = load("fixtures/cycle_request.valid.json")
    value["options"]["joker"] = {"enabled": False, "ceilingBasisPoints": 1000}
    assert list(validator("cycle_request.schema.json").iter_errors(value))


def test_high_intensity_deload_rejects_skip_warm_up():
    value = load("fixtures/cycle_request.valid.json")
    value["options"]["deload"] = {
        "enabled": True,
        "type": "highIntensity",
        "skipWarmUp": True,
    }
    assert list(validator("cycle_request.schema.json").iter_errors(value))


def test_full_body_profiles_are_conditional():
    value = load("fixtures/cycle_request.valid.json")
    value["options"]["fullBody"] = {
        "profile": "full_boring",
        "liftProfiles": {
            "bench": "65x5_75x5_85x5",
            "squat": "70x3_80x3_90x3",
            "deadlift": "75x5_85x3_95x1",
        },
    }
    assert not list(validator("cycle_request.schema.json").iter_errors(value))
    del value["options"]["fullBody"]["liftProfiles"]["deadlift"]
    assert list(validator("cycle_request.schema.json").iter_errors(value))


def test_unknown_enum_is_rejected():
    value = load("fixtures/cycle_request.valid.json")
    value["unit"] = "stone"
    assert list(validator("cycle_request.schema.json").iter_errors(value))


def test_unknown_version_is_rejected():
    value = load("fixtures/engine_info.valid.json")
    value["apiVersion"] = "v2"
    assert list(validator("engine_info.schema.json").iter_errors(value))


def test_canonical_round_trip():
    value = load("fixtures/cycle_request.valid.json")
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"))
    assert json.loads(encoded) == value
