#!/usr/bin/env python3
"""grade_flow.py — детерминированная проверка экспортированного Langflow-flow.

Используется для графических практик Pr_29–Pr_31: задача оценивается НЕ LLM,
а структурным анализом JSON-экспорта flow (компоненты, параметры, связность).

Формат экспорта Langflow 1.x:
    {
      "name": "...", "id": "...",
      "data": {
        "nodes": [
          {"id": "ChatInput-abc", "type": "custom_component",
           "data": {"id": "ChatInput-abc",
                    "node": {"display_name": "Chat Input",
                             "metadata": {"module": "lfx.components...ChatInputComponent"},
                             "template": {<field>: {"value": ..., ...}, ...}}}}
        ],
        "edges": [{"source": "A-abc", "target": "B-def", ...}]
      }
    }

Проверяемые типы (spec['flow_tasks'][i]['check']):
    component      — есть хотя бы один узел, совпадающий с any_of (класс/название)
    components_all — для каждой группы required найден хотя бы один узел
    count          — узлов из any_of не меньше min
    param          — у какого-то узла из any_of поле field совпадает с regex
    params_all     — у одного узла из any_of все поля fields заполнены
    path           — упорядоченная достижимость: для каждого шага steps найден
                     узел, из которого (через произвольные промежуточные узлы)
                     достижим узел следующего шага

Совпадение узла с алиасом: нормализованный алиас (нижний регистр, только
[a-z0-9]) является подстрокой нормализованного имени класса компонента или
display_name. Пример: алиас "openaimodel" ловит класс OpenAIModelComponent,
но не EmbeddingModelComponent; алиас "sqlitedatabase" — и класс
SQLiteDatabaseComponent, и display "SQL Database".

CLI:
    grade_flow.py <flow.json> <practice_number>   → JSON-результат в stdout
"""

import json
import re
import sys

NON_ALNUM_RE = re.compile(r"[^a-z0-9]+")


def norm_name(name):
    """Нормализация имени компонента/алиаса: нижний регистр, только [a-z0-9]."""
    return NON_ALNUM_RE.sub("", (name or "").lower())


def _node_class(node_data_node):
    module = ((node_data_node.get("metadata") or {}).get("module")) or ""
    if isinstance(module, str) and module:
        return module.rsplit(".", 1)[-1]
    return ""


def _node_display(node_data_node):
    value = node_data_node.get("display_name")
    return value if isinstance(value, str) else ""


def _node_props(node_data_node):
    """Поля компонента {name: value} из template (и плоских полей)."""
    props = {}
    template = node_data_node.get("template")
    if isinstance(template, dict):
        for key, field in template.items():
            if key.startswith("_"):
                continue
            if isinstance(field, dict) and "value" in field:
                props[key] = field.get("value")
            elif not isinstance(field, (dict, list)):
                props[key] = field
    for key in ("uri", "query", "database_url", "model_name"):
        if key in node_data_node and key not in props:
            props[key] = node_data_node.get(key)
    return props


def load_flow(path):
    """Читает flow JSON → {"name", "nodes": [...], "edges": [(src, dst)]}."""
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)

    if isinstance(raw, dict) and isinstance(raw.get("data"), dict):
        body = raw["data"]
    else:
        body = raw if isinstance(raw, dict) else {}

    nodes = []
    for node in body.get("nodes") or []:
        if not isinstance(node, dict):
            continue
        data = node.get("data") or {}
        node_data_node = data.get("node") or {}
        instance_id = node.get("id") or data.get("id") or ""
        nodes.append({
            "id": str(instance_id),
            "class": _node_class(node_data_node),
            "display": _node_display(node_data_node),
            "props": _node_props(node_data_node),
        })

    edges = []
    for edge in body.get("edges") or []:
        if not isinstance(edge, dict):
            continue
        src, dst = edge.get("source"), edge.get("target")
        if src and dst:
            edges.append((str(src), str(dst)))

    return {
        "name": (raw.get("name") if isinstance(raw, dict) else "") or "",
        "nodes": nodes,
        "edges": edges,
    }


def node_matches(node, aliases):
    """Узел совпадает с любым алиасом (подстрока в классе или display_name)."""
    class_norm = norm_name(node["class"])
    display_norm = norm_name(node["display"])
    for alias in aliases:
        a = norm_name(alias)
        if not a:
            continue
        if a in class_norm or a in display_norm:
            return True
    return False


def _matching_nodes(flow, aliases):
    return [n for n in flow["nodes"] if node_matches(n, aliases)]


def _reachable_map(flow):
    """{node_id: set(node_id)} — транзитивная достижимость по рёбрам."""
    ids = {n["id"] for n in flow["nodes"]}
    adj = {}
    for src, dst in flow["edges"]:
        if src in ids and dst in ids:
            adj.setdefault(src, set()).add(dst)
    # нулевой путь: узел достижим сам с себя
    closure = {src: set(dsts) | {src} for src, dsts in adj.items()}
    for node_id in ids:
        closure.setdefault(node_id, {node_id})
    changed = True
    while changed:
        changed = False
        for src in list(closure):
            before = len(closure[src])
            for mid in list(closure[src]):
                if mid in closure:
                    closure[src] |= closure[mid]
            if len(closure[src]) > before:
                changed = True
    return closure


def _path_exists(flow, steps, closure):
    """Упорядоченная достижимость по шагам (промежуточные узлы разрешены)."""
    frontier = [n["id"] for n in flow["nodes"]]
    for aliases in steps:
        matches = {n["id"] for n in _matching_nodes(flow, aliases)}
        if not matches:
            return False
        next_frontier = set()
        for node_id in frontier:
            reach = closure.get(node_id, set())
            if reach & matches:
                next_frontier |= (reach & matches)
        frontier = list(next_frontier)
        if not frontier:
            return False
    return True


def _value_text(value):
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    try:
        return json.dumps(value, ensure_ascii=False)
    except (TypeError, ValueError):
        return str(value)


def check_component(flow, task):
    found = _matching_nodes(flow, task.get("any_of") or [])
    return bool(found), f"найдено узлов: {len(found)}" if found else "узлов не найдено"


def check_components_all(flow, task):
    details = []
    for group in task.get("required") or []:
        found = _matching_nodes(flow, group)
        details.append(f"{len(found)}")
        if not found:
            return False, "не хватает группы " + json.dumps(group, ensure_ascii=False)
    return True, "все группы найдены"


def check_count(flow, task):
    found = _matching_nodes(flow, task.get("any_of") or [])
    minimum = int(task.get("min", 1))
    ok = len(found) >= minimum
    return ok, f"узлов: {len(found)}, нужно >= {minimum}"


def check_param(flow, task):
    field = task.get("field") or ""
    pattern = task.get("regex") or r".+"
    try:
        regex = re.compile(pattern, re.IGNORECASE)
    except re.error:
        regex = re.compile(re.escape(pattern), re.IGNORECASE)
    for node in _matching_nodes(flow, task.get("any_of") or []):
        value = node["props"].get(field)
        if value is None:
            continue
        if regex.search(_value_text(value)):
            return True, f"узел {node['class'] or node['display']}: {field}={_value_text(value)[:60]}"
    return False, f"поле {field} с значением по {pattern!r} не найдено"


def check_params_all(flow, task):
    fields = task.get("fields") or []
    for node in _matching_nodes(flow, task.get("any_of") or []):
        missing = [f for f in fields if _value_text(node["props"].get(f)).strip() == ""]
        if not missing:
            return True, f"узел {node['class'] or node['display']}: все поля заполнены"
    return False, "не найден узел со всеми полями: " + ", ".join(fields)


def check_path(flow, task, closure):
    steps = task.get("steps") or []
    ok = _path_exists(flow, steps, closure)
    label = " → ".join(
        (task.get("step_labels") or [s[0] if isinstance(s, list) and s else str(s) for s in steps])
    )
    return ok, f"путь {label}: {'найден' if ok else 'не найден'}"


CHECKS = {
    "component": lambda flow, task, closure: check_component(flow, task),
    "components_all": lambda flow, task, closure: check_components_all(flow, task),
    "count": lambda flow, task, closure: check_count(flow, task),
    "param": lambda flow, task, closure: check_param(flow, task),
    "params_all": lambda flow, task, closure: check_params_all(flow, task),
    "path": lambda flow, task, closure: check_path(flow, task, closure),
}


def grade_flow_file(path, spec):
    """Оценка flow-файла по spec['flow_tasks'] → dict результата."""
    flow_tasks = spec.get("flow_tasks") or []
    total = len(flow_tasks)
    if total == 0:
        return {
            "task_score": 0.0, "tasks": [], "done_count": 0, "total_tasks": 0,
            "feedback": "В spec нет flow_tasks",
        }

    try:
        flow = load_flow(path)
    except Exception as exc:
        return {
            "task_score": 0.0, "tasks": [False] * total, "done_count": 0,
            "total_tasks": total,
            "feedback": f"Не удалось прочитать flow JSON: {exc}",
        }

    closure = _reachable_map(flow)
    tasks, details = [], []
    for task in flow_tasks:
        check_type = task.get("check", "component")
        checker = CHECKS.get(check_type)
        if checker is None:
            done, detail = False, f"неизвестный тип проверки {check_type!r}"
        else:
            try:
                done, detail = checker(flow, task, closure)
            except Exception as exc:
                done, detail = False, f"ошибка проверки: {exc}"
        tasks.append(bool(done))
        details.append({"name": task.get("text", ""), "done": bool(done), "detail": detail})

    done_count = sum(1 for t in tasks if t)
    task_score = round(3.0 * done_count / total, 6)
    done_idx = [str(i + 1) for i, t in enumerate(tasks) if t]
    not_done_idx = [str(i + 1) for i, t in enumerate(tasks) if not t]
    feedback = (
        f"Flow «{flow['name']}»: узлов {len(flow['nodes'])}, рёбер {len(flow['edges'])}. "
        f"Выполнено шагов: {', '.join(done_idx) if done_idx else '—'} из {total} "
        f"({task_score:.2f}/3)."
    )
    if not_done_idx:
        feedback += " Не выполнены: " + ", ".join(not_done_idx) + "."

    return {
        "task_score": task_score,
        "tasks": tasks,
        "task_details": details,
        "done_count": done_count,
        "total_tasks": total,
        "flow_name": flow["name"],
        "flow_nodes": len(flow["nodes"]),
        "flow_edges": len(flow["edges"]),
        "feedback": feedback,
    }


def main():
    if len(sys.argv) < 3:
        print("Usage: grade_flow.py <flow.json> <practice_number>")
        sys.exit(1)
    from practice_specs import PRACTICE_SPECS

    path = sys.argv[1]
    practice_num = int(sys.argv[2])
    spec = PRACTICE_SPECS.get(practice_num)
    if not spec:
        print(json.dumps({"error": f"spec для Pr_{practice_num} не найден"}, ensure_ascii=False))
        sys.exit(1)
    result = grade_flow_file(path, spec)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
