#!/usr/bin/env bash
set -euo pipefail

echo "=== Установка AI‑линтера для JupyterLab (без сборки) ==="

read -p "Введите IP llama.cpp сервера: " LLM_HOST
read -p "Введите порт llama.cpp сервера: " LLM_PORT

LLM_URL="http://${LLM_HOST}:${LLM_PORT}/v1/chat/completions"
echo "Используем URL модели: ${LLM_URL}"

EXT_DIR="/opt/jupyterhub/ai-lint-extension"
SETTINGS_DIR="/usr/local/share/jupyter/lab/settings"
mkdir -p "$EXT_DIR"
mkdir -p "$SETTINGS_DIR"

echo "=== Создание JS‑расширения ==="

cat > "${EXT_DIR}/ai-lint.js" <<EOF
console.log("AI‑Lint extension loaded");

define([
  "@jupyterlab/application",
  "@jupyterlab/notebook",
  "@jupyterlab/apputils",
  "@lumino/widgets",
  "@codemirror/view"
], function(app, notebook, apputils, widgets, cmview) {

  const LLM_URL = "${LLM_URL}";

  class LintPanel extends widgets.Widget {
    constructor() {
      super();
      this.id = 'ai-lint-panel';
      this.title.label = 'AI Lint Report';
      this.title.closable = true;
      this.addClass('ai-lint-panel');
      this.node.style.padding = "10px";
      this.node.style.whiteSpace = "pre-wrap";
      this.node.style.fontFamily = "monospace";
    }
    setContent(text) {
      this.node.textContent = text;
    }
  }

  const plugin = {
    id: "ai-lint-lite",
    autoStart: true,
    requires: [notebook.INotebookTracker],
    activate: function(app, tracker) {

      const panel = new LintPanel();
      app.shell.add(panel, 'right');

      function highlightErrors(errors) {
        const current = tracker.currentWidget;
        if (!current) return;

        const nb = current.content;

        errors.forEach(err => {
          const cellIndex = err.cell - 1;
          const line = err.line - 1;

          const cell = nb.widgets[cellIndex];
          if (!cell) return;

          const editor = cell.editor;
          const view = editor._editor; // CodeMirror 6 view

          if (!view) return;

          const lineStart = view.state.doc.line(line + 1).from;
          const deco = cmview.Decoration.line({ class: "ai-lint-error" }).range(lineStart);

          view.dispatch({
            effects: cmview.EditorView.decorations.of(deco)
          });
        });
      }

      function extractFilePaths(nb) {
        const paths = [];
        const regex = /(read_csv|open|np\\.load)\\(['"]([^'"]+)['"]/g;

        nb.cells.forEach(c => {
          if (c.cell_type === "code") {
            let m;
            while ((m = regex.exec(c.source)) !== null) {
              paths.push(m[2]);
            }
          }
        });

        return paths;
      }

      async function runLint() {
        const current = tracker.currentWidget;
        if (!current) return;

        const nb = current.context.model.toJSON();
        const missing = extractFilePaths(nb).filter(p => !p.startsWith("/home/jupyter/work/data"));

        const resp = await fetch(LLM_URL, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            prompt: "Проанализируй Jupyter Notebook. Ошибки, импорты, данные. Отсутствующие файлы: " +
                    missing.join(", ") + "\\nNotebook JSON:\\n" + JSON.stringify(nb)
          })
        });

        const result = await resp.json();
        const text = result.content || JSON.stringify(result);

        panel.setContent(text);
        app.shell.activateById(panel.id);

        const errorRegex = /cell\\s+(\\d+)[^\\d]+line\\s+(\\d+)/gi;
        const errors = [];
        let m;
        while ((m = errorRegex.exec(text)) !== null) {
          errors.push({ cell: parseInt(m[1]), line: parseInt(m[2]) });
        }

        highlightErrors(errors);
      }

      const button = new apputils.ToolbarButton({
        label: "Lint",
        onClick: runLint,
        tooltip: "Проверить ноутбук AI‑линтером"
      });

      app.docRegistry.addWidgetExtension("Notebook", {
        createNew: () => button
      });

      const style = document.createElement("style");
      style.textContent = ".ai-lint-error { background: rgba(255,0,0,0.25) !important; }";
      document.head.appendChild(style);

      console.log("AI‑Lint loaded");
    }
  };

  return plugin;
});
EOF

echo "=== Подключение расширения через overrides.json ==="

cat > "${SETTINGS_DIR}/overrides.json" <<EOF
{
  "disabledExtensions": [],
  "overrides": {
    "@jupyterlab/apputils-extension:themes": {
      "load": [
        "${EXT_DIR}/ai-lint.js"
      ]
    }
  }
}
EOF

echo "=== Перезапуск JupyterHub ==="
systemctl restart jupyterhub

echo "=== Готово! Кнопка Lint и панель AI‑Lint Report добавлены ==="
