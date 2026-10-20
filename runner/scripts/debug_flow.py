#!/usr/bin/env python3
"""debug_flow.py — диагностика экспортированного Langflow-flow.

Показывает нормализованную структуру flow (узлы, имена классов, display_name,
ключевые параметры, рёбра) — для отладки соответствия flow критериям проверки
практик Pr_29–Pr_31 и подбора алиасов в practice_specs.py.

CLI:
    debug_flow.py <flow.json> [practice_number]
"""

import json
import sys

from grade_flow import load_flow, norm_name, _matching_nodes


def main():
    if len(sys.argv) < 2:
        print("Usage: debug_flow.py <flow.json> [practice_number]")
        sys.exit(1)

    path = sys.argv[1]
    flow = load_flow(path)

    print(f"Flow: {flow['name'] or '(без имени)'}")
    print(f"Узлов: {len(flow['nodes'])}, рёбер: {len(flow['edges'])}")
    print()
    print("=== УЗЛЫ ===")
    for i, node in enumerate(flow["nodes"]):
        label = node["class"] or node["display"] or "(неизвестный)"
        display = f' (display: "{node["display"]}")' if node["display"] and node["display"] != node["class"] else ""
        print(f"[{i}] {label}{display}  id={node['id']}")
        props = {k: v for k, v in node["props"].items() if v not in (None, "", [])}
        shown = 0
        for key, value in props.items():
            text = str(value).replace("\n", " ")
            if len(text) > 80:
                text = text[:77] + "..."
            print(f"      {key} = {text}")
            shown += 1
            if shown >= 12:
                break

    print()
    print("=== РЁБРА (A → B) ===")
    by_id = {n["id"]: (n["class"] or n["display"]) for n in flow["nodes"]}
    for src, dst in flow["edges"]:
        print(f"  {by_id.get(src, src)} → {by_id.get(dst, dst)}")

    if len(sys.argv) >= 3:
        from practice_specs import PRACTICE_SPECS

        spec = PRACTICE_SPECS.get(int(sys.argv[2]))
        if not spec:
            print(f"\nSpec для Pr_{sys.argv[2]} не найден")
            return
        print(f"\n=== ПРОВЕРКА ПО SPEC Pr_{sys.argv[2]} ===")
        from grade_flow import grade_flow_file

        result = grade_flow_file(path, spec)
        for i, detail in enumerate(result.get("task_details") or []):
            mark = "✓" if detail["done"] else "✗"
            print(f"  {mark} {i + 1}. {detail['name']}: {detail['detail']}")
        print(f"\n  task_score = {result['task_score']:.2f}/3, итого выполнено {result['done_count']}/{result['total_tasks']}")

        aliases_seen = set()
        for task in spec.get("flow_tasks") or []:
            for group in (task.get("any_of") or task.get("required") or []):
                if isinstance(group, list):
                    aliases_seen.update(group)
        unmatched = [a for a in sorted(aliases_seen) if not _matching_nodes(flow, [a])]
        if unmatched:
            print(f"\n  Алиасы из spec, не совпавшие ни с одним узлом: {unmatched}")


if __name__ == "__main__":
    main()
