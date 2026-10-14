#!/usr/bin/env python3
"""用 Python 标准库按随 skill 提供的 JSON Schema 校验影响面报告。"""

import json
import sys
from pathlib import Path


SCHEMA_PATH = Path(__file__).resolve().parents[1] / "assets" / "impact-report.schema.json"

def reject_constant(value):
    raise ValueError(f"JSON 不允许常量：{value}")


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"JSON 字段重复：{key}")
        result[key] = value
    return result



def validate(report, schema):
    errors = []
    if not isinstance(report, dict):
        return ["根节点必须是 JSON 对象"]

    required = set(schema["required"])
    actual = set(report)
    for key in sorted(required - actual):
        errors.append(f"缺少必需字段：{key}")
    if schema.get("additionalProperties") is False:
        for key in sorted(actual - set(schema["properties"])):
            errors.append(f"不允许额外字段：{key}")

    for key, rule in schema["properties"].items():
        if key not in report:
            continue
        value = report[key]
        expected = rule["type"]
        if expected == "string" and not isinstance(value, str):
            errors.append(f"{key} 必须是字符串")
            continue
        if expected == "array" and not isinstance(value, list):
            errors.append(f"{key} 必须是数组")
            continue
        if expected == "string" and len(value) < rule.get("minLength", 0):
            errors.append(f"{key} 不能为空")
        if "enum" in rule and value not in rule["enum"]:
            errors.append(f"{key} 必须是：{', '.join(rule['enum'])}")
    return errors


def main():
    if len(sys.argv) != 2:
        print("用法：python validate-impact-json.py <impact-report.json 或 ->", file=sys.stderr)
        return 2
    try:
        data = sys.stdin.buffer.read() if sys.argv[1] == "-" else Path(sys.argv[1]).read_bytes()
        report = json.loads(data.decode("utf-8-sig"), parse_constant=reject_constant, object_pairs_hook=unique_pairs)
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"无法解析 JSON：{exc}", file=sys.stderr)
        return 2

    errors = validate(report, schema)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("影响面 JSON 格式校验通过")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
