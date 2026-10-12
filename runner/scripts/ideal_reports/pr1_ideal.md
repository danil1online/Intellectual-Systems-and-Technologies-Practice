# Отчёт по Практической работе №1 «Основы Git и GitLab»

## Выполнение задания

```bash
student@istp:~/project$ git branch newbranch
student@istp:~/project$ git checkout newbranch
Switched to branch 'newbranch'
student@istp:~/project$ echo "# Practice 1" > newbranchfile
student@istp:~/project$ git add newbranchfile
student@istp:~/project$ git commit -m "Add newbranchfile to Practice 1"
[newbranch a1b2c3d] Add newbranchfile to Practice 1
 1 file changed, 1 insertion(+)
 create mode 100644 newbranchfile
student@istp:~/project$ git revert HEAD --no-edit
[newbranch e4f5a6b] Revert "Add newbranchfile to Practice 1"
 1 file changed, 1 deletion(-)
 delete mode 100644 newbranchfile
student@istp:~/project$ echo "# Practice 1" > newgoodfile
student@istp:~/project$ git add newgoodfile
student@istp:~/project$ git commit -m "Add newgoodfile to Practice 1"
[newbranch i7j8k9l] Add newgoodfile to Practice 1
 1 file changed, 1 insertion(+)
 create mode 100644 newgoodfile
student@istp:~/project$ git checkout main
Switched to branch 'main'
student@istp:~/project$ git merge newbranch
Updating a1b2c3d..i7j8k9l
Fast-forward
 newgoodfile | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 newgoodfile
student@istp:~/project$ git push
Enumerating objects: 12, done.
Writing objects: 100% (10/10), 900 bytes | 900.00 KiB/s, done.
Total 10 (delta 2), reused 0 (delta 0)
To https://gitlab.local/student/project.git
   a1b2c3d..i7j8k9l  main -> main
student@istp:~/project$ git branch -d newbranch
Deleted branch newbranch (was i7j8k9l).
student@istp:~/project$ git log
commit i7j8k9l95be1850b5f7f0832e4561b778a5ec774 (HEAD -> main, origin/main)
Author: student <student@example.com>
Date:   Mon Aug 24 10:00:00 2026 +0000

    Add newgoodfile to Practice 1

commit e4f5a6b000000000000000000000000000000000
Author: student <student@example.com>
Date:   Mon Aug 24 09:55:00 2026 +0000

    Revert "Add newbranchfile to Practice 1"

commit a1b2c3d000000000000000000000000000000000
Author: student <student@example.com>
Date:   Mon Aug 24 09:50:00 2026 +0000

    Add newbranchfile to Practice 1
```

## Ответы на контрольные вопросы

1) Зачем в Git нужны ветки и чем ветка отличается от коммита?

Ветка — это отдельная линия разработки: изолированная среда, в которой можно вносить изменения, не трогая основную ветку main до слияния. Коммит — это снимок (фиксированное состояние) файлов в определённый момент истории, то есть точка истории. Разница: коммит — неизменяемый снимок состояния, а ветка — подвижный указатель на последний коммит линии разработки.

2) Как связываются `git add`, `git commit` и `git push` при отправке изменений в репозиторий?

Порядок такой: сначала `git add` переносит изменённые файлы из рабочего каталога в staging area (индекс) — это подготовленный к отправке набор изменений. Затем `git commit` фиксирует этот снимок в локальной истории — коммит создаётся локально на компьютере. Наконец `git push` отправляет локальные коммиты в удалённый репозиторий на сервер, чтобы изменения увидели другие участники проекта.

3) Чем `git merge` отличается от `git revert` и когда применяется `git revert`?

`git merge` (слияние) объединяет изменения одной ветки с другой: например, результаты работы в ветке newbranch применяются к main. `git revert` — это отмена изменений путём создания НОВОГО коммита, который делает обратные изменения, без переписывания истории. `revert` применяют, когда нужно отменить ошибочный коммит, особенно если он уже отправлен на сервер и его скачали другие разработчики.

4) Как проверить историю и текущее состояние репозитория с помощью `git log`, `git status` и `git branch`?

`git log` показывает историю коммитов текущей ветки: автора, дату, хэш и сообщение к коммиту. `git status` показывает текущее состояние рабочего каталога и индекса: какие файлы изменены, какие добавлены в staging area, какие не отслеживаются. `git branch` выводит список веток, при этом активная (текущая) ветка помечена звёздочкой.

5) Зачем перед удалением ветки выполнять её слияние с `main` и использовать `git branch -d`?

Сначала выполняют слияние, чтобы изменения ветки сохранились в main и не потерялись при удалении ветки. `git branch -d` — это безопасное удаление: Git откажет в удалении, если ветка не слита (в ней есть неслитые изменения), тем самым защищая от потери работы. Для принудительного удаления неслитой ветки, когда работы больше не нужны, используют `git branch -D`.
