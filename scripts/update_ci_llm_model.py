#!/usr/bin/env python3
"""Обновляет LLM_CI_MODEL (и timeout) в .gitlab-ci.yml всех проектов GitLab.

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
JOB_TIMEOUT_LINE = "timeout: 90m"


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

    if "timeout:" not in new_content:
        anchor = "stages:\n  - grade\n"
        if anchor in new_content:
            new_content = new_content.replace(anchor, f"{anchor}\n{JOB_TIMEOUT_LINE}\n", 1)
            changed = True

    return new_content, changed


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
        try:
            content = get_ci_file(proj["id"])
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
        payload = {
            "branch": "main",
            "content": new_content,
            "encoding": "text",
            "commit_message": f"CI: LLM_CI_MODEL -> {model}, timeout 90m",
        }
        resp = api("PUT", f"/projects/{proj['id']}/repository/files/.gitlab-ci.yml", json=payload)
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
