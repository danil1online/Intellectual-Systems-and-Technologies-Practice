#!/usr/bin/env python3
"""Обновляет LLM_CI_MODEL, job-level timeout и LLM_TIMEOUT_S в .gitlab-ci.yml всех проектов GitLab.

Студенческие проекты защищены (main: push=Maintainers), а root не участник —
поэтому перед коммитом защита main временно снимается и восстанавливается
после (try/finally).

Запуск с сервера стека:
    GITLAB_ADMIN_TOKEN=$(grep '^GITLAB_ADMIN_TOKEN=' /home/user1/ISTP/istp0808/.env | cut -d= -f2) \
        python3 scripts/update_ci_llm_model.py [новая_модель]

Модель по умолчанию: GigaChat3.1-10B-A1.8B-q4_K_M.gguf
"""
import base64
import os
import re
import sys

import requests

GITLAB_URL = os.environ.get("GITLAB_URL", "http://localhost")
TOKEN = os.environ.get("GITLAB_ADMIN_TOKEN", "")
DEFAULT_MODEL = "GigaChat3.1-10B-A1.8B-q4_K_M.gguf"
JOB_TIMEOUT_LINE = "  timeout: 90m"


def api(method, path, **kwargs):
    return requests.request(
        method, f"{GITLAB_URL}/api/v4{path}",
        headers={"PRIVATE-TOKEN": TOKEN}, timeout=60, **kwargs,
    )


def get_projects():
    projects, page = [], 1
    while True:
        resp = api("GET", "/projects", params={"per_page": 100, "page": page})
        resp.raise_for_status()
        batch = resp.json()
        if not batch:
            return projects
        projects.extend(batch)
        if len(batch) < 100:
            return projects
        page += 1


def get_ci_file(project_id):
    resp = api("GET", f"/projects/{project_id}/repository/files/.gitlab-ci.yml",
               params={"ref": "main"})
    if resp.status_code == 404:
        return None
    resp.raise_for_status()
    return base64.b64decode(resp.json()["content"]).decode("utf-8")


def transform(content, model):
    new_content, changed = content, False

    def _sub_model(match):
        nonlocal changed
        if match.group(0).split('"')[1] != model:
            changed = True
        return f'LLM_CI_MODEL: "{model}"'

    new_content = re.sub(r'LLM_CI_MODEL:\s*"[^"]*"', _sub_model, new_content)

    # Верхнеуровневый timeout невалиден (GitLab трактует его как job без script) —
    # удаляем неиндентированную строку и ставим timeout внутрь job grade.
    stripped = re.sub(r"^timeout:[^\n]*\n", "", new_content, flags=re.M)
    if stripped != new_content:
        new_content = stripped
        changed = True

    anchor = "grade:\n  stage: grade\n"
    if "  timeout:" not in new_content and anchor in new_content:
        new_content = new_content.replace(anchor, f"{anchor}{JOB_TIMEOUT_LINE}\n", 1)
        changed = True

    # Бюджет LLM-оценки одной практики (потолок subprocess'а = LLM_TIMEOUT_S + 60).
    if "LLM_TIMEOUT_S:" not in new_content:
        m = re.search(r'^([ \t]*)LLM_CI_MODEL:[^\n]*\n', new_content, flags=re.M)
        if m:
            new_content = new_content.replace(
                m.group(0), f'{m.group(0)}{m.group(1)}LLM_TIMEOUT_S: "900"\n', 1)
            changed = True

    return new_content, changed


def _levels(levels):
    out = []
    for lvl in levels or []:
        item = {"access_level": lvl["access_level"]}
        if lvl.get("user_id"):
            item["user_id"] = lvl["user_id"]
        if lvl.get("group_id"):
            item["group_id"] = lvl["group_id"]
        out.append(item)
    return out or [{"access_level": 40}]


def get_main_protection(project_id):
    resp = api("GET", f"/projects/{project_id}/protected_branches?search=main")
    if resp.status_code != 200:
        return None
    for branch in resp.json():
        if branch.get("name") == "main":
            return branch
    return None


def restore_main_protection(project_id, protection):
    payload = {
        "name": "main",
        "allow_force_push": bool(protection.get("allow_force_push", False)),
        "code_owner_approval_required": bool(protection.get("code_owner_approval_required", False)),
        "push_access_levels": _levels(protection.get("push_access_levels")),
        "merge_access_levels": _levels(protection.get("merge_access_levels")),
    }
    resp = api("POST", f"/projects/{project_id}/protected_branches", json=payload)
    if resp.status_code not in (200, 201):
        print(f"  ⚠️ не удалось восстановить защиту main: "
              f"HTTP {resp.status_code}: {resp.text[:200]}", file=sys.stderr)


def main():
    model = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_MODEL
    if not TOKEN:
        print("ОШИБКА: задайте GITLAB_ADMIN_TOKEN", file=sys.stderr)
        sys.exit(1)

    check = api("GET", "/version")
    if check.status_code != 200:
        print(f"ОШИБКА: GitLab недоступен ({check.status_code})", file=sys.stderr)
        sys.exit(1)

    projects = get_projects()
    updated, unchanged, skipped, failed = [], [], [], []
    for proj in projects:
        name = proj["path_with_namespace"]
        pid = proj["id"]
        try:
            content = get_ci_file(pid)
        except Exception as exc:
            failed.append((name, str(exc)))
            continue
        if content is None:
            skipped.append(name)
            continue
        new_content, changed = transform(content, model)
        if not changed:
            unchanged.append(name)
            continue

        protection = get_main_protection(pid)
        unprotect_ok = True
        if protection is not None:
            resp = api("DELETE", f"/projects/{pid}/protected_branches/main")
            unprotect_ok = resp.status_code in (200, 204)
            if not unprotect_ok:
                failed.append((name, f"не удалось снять защиту main: HTTP {resp.status_code}"))
                continue

        try:
            payload = {
                "branch": "main",
                "content": new_content,
                "encoding": "text",
                "commit_message": f"CI: LLM_CI_MODEL -> {model}, timeout 90m",
            }
            resp = api("PUT", f"/projects/{pid}/repository/files/.gitlab-ci.yml", json=payload)
        finally:
            if protection is not None and unprotect_ok:
                restore_main_protection(pid, protection)

        if resp.status_code in (200, 201):
            updated.append(name)
        else:
            failed.append((name, f"HTTP {resp.status_code}: {resp.text[:200]}"))

    print(f"Модель: {model}")
    print(f"Обновлено: {len(updated)}")
    for name in updated:
        print(f"  ✓ {name}")
    print(f"Без изменений: {len(unchanged)}")
    for name in unchanged:
        print(f"  = {name}")
    print(f"Нет .gitlab-ci.yml: {len(skipped)}")
    for name in skipped:
        print(f"  - {name}")
    if failed:
        print(f"Ошибки: {len(failed)}")
        for name, err in failed:
            print(f"  ✗ {name}: {err}")
        sys.exit(1)


if __name__ == "__main__":
    main()
