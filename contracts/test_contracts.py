import copy
import json
from pathlib import Path

from jsonschema import Draft202012Validator, RefResolver

ROOT = Path(__file__).parent / "v1"


def load(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def validator(name):
    schema = load(name)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, resolver=RefResolver(ROOT.as_uri() + "/", schema))


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


def test_unknown_key_is_rejected():
    value = load("fixtures/cycle_request.valid.json")
    value["unexpected"] = True
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
