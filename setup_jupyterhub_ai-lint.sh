#!/usr/bin/env bash
set -euo pipefail

echo "=== Установка AI‑линтера для JupyterLab ==="

# === 0. Установка Node.js 20 (обязательно для JupyterLab 4) ===
echo "=== Установка Node.js 20 LTS ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
echo "Node version: $(node -v)"
echo "NPM version: $(npm -v)"

# === 1. Сбор параметров ===
read -p "Введите IP llama.cpp сервера (например 192.168.2.75): " LLM_HOST
read -p "Введите порт llama.cpp сервера (например 8080): " LLM_PORT

LLM_URL="http://${LLM_HOST}:${LLM_PORT}/completion"
echo "Используем URL модели: ${LLM_URL}"

# === 2. Каталог расширения ===
EXT_DIR="/opt/jupyterhub/jupyterlab-ai-lint"
mkdir -p "$EXT_DIR"
cd "$EXT_DIR"

echo "=== Создание структуры расширения ==="

cat > package.json <<EOF
{
  "name": "jupyterlab-ai-lint",
  "version": "1.0.0",
  "description": "AI Linter Button for JupyterLab",
  "keywords": ["jupyterlab"],
  "jupyterlab": {
    "extension": "lib/index.js"
  },
  "scripts": {
    "build": "tsc"
  },
  "dependencies": {
    "@jupyterlab/application": "^4.0.0",
    "@jupyterlab/notebook": "^4.0.0",
    "@jupyterlab/apputils": "^4.0.0",
    "@lumino/widgets": "^2.0.0",
    "@codemirror/view": "^6.25.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF

cat > tsconfig.json <<EOF
{
  "compilerOptions": {
    "target": "ES2018",
    "module": "commonjs",
    "outDir": "lib",
    "strict": false,
    "esModuleInterop": true
  },
  "include": ["src/**/*"]
}
EOF

mkdir -p src

echo "=== Создание CSS для подсветки ошибок ==="
cat > src/style.css <<EOF
.ai-lint-error {
  background-color: rgba(255, 0, 0, 0.25) !important;
}
EOF

echo "=== Создание кода расширения ==="

cat > src/index.ts <<EOF
import {
  JupyterFrontEnd, JupyterFrontEndPlugin
} from '@jupyterlab/application';
import { INotebookTracker } from '@jupyterlab/notebook';
import { ToolbarButton } from '@jupyterlab/apputils';
import { Widget } from '@lumino/widgets';
import { Decoration, EditorView } from "@codemirror/view";
import './style.css';

const LLM_URL = "${LLM_URL}";

// === Панель справа ===
class LintPanel extends Widget {
  constructor() {
    super();
    this.id = 'ai-lint-panel';
    this.title.label = 'AI Lint Report';
    this.title.closable = true;
    this.addClass('ai-lint-panel');
  }

  setContent(html: string) {
    this.node.innerHTML = \`<div style="padding:10px;font-family:monospace;white-space:pre-wrap">\${html}</div>\`;
  }
}

const plugin: JupyterFrontEndPlugin<void> = {
  id: 'jupyterlab-ai-lint',
  autoStart: true,
  requires: [INotebookTracker],
  activate: (app: JupyterFrontEnd, tracker: INotebookTracker) => {

    const panel = new LintPanel();
    app.shell.add(panel, 'right');

    // === Подсветка ошибок через CodeMirror 6 ===
    function highlightErrors(errors: any[]) {
      const current = tracker.currentWidget;
      if (!current) return;

      const notebook = current.content;

      errors.forEach(err => {
        const cellIndex = err.cell - 1;
        const line = err.line - 1;

        const cell = notebook.widgets[cellIndex];
        if (!cell) return;

        const editor = cell.editor;
        const view = editor.editorView;
        if (!view) return;

        const lineStart = view.state.doc.line(line + 1).from;
        const deco = Decoration.line({ class: "ai-lint-error" }).range(lineStart);

        view.dispatch({
          effects: EditorView.decorations.of(deco)
        });
      });
    }

    // === Проверка импортов данных ===
    function extractFilePaths(nb: any): string[] {
      const paths = [];
      const regex = /(read_csv|open|np\.load)\(['"]([^'"]+)['"]/g;

      nb.cells.forEach((c: any) => {
        if (c.cell_type === "code") {
          let m;
          while ((m = regex.exec(c.source)) !== null) {
            paths.push(m[2]);
          }
        }
      });

      return paths;
    }

    const runLint = async () => {
      const current = tracker.currentWidget;
      if (!current) return;

      const nb = current.context.model.toJSON();
      const missingFiles = extractFilePaths(nb).filter(p => !p.startsWith("/home/jupyter/work/data"));

      const resp = await fetch(LLM_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          prompt: \`
Проанализируй Jupyter Notebook.
Найди ошибки, потенциальные проблемы, неправильные импорты, ошибки выполнения.
Отдельно оцени корректность путей к данным.
Отсутствующие файлы: \${missingFiles.join(", ")}

Notebook JSON:
\${JSON.stringify(nb)}
\`
        })
      });

      const result = await resp.json();
      const text = result.content || JSON.stringify(result);

      // === Вывод в панель ===
      panel.setContent(text);
      app.shell.activateById(panel.id);

      // === Извлечение ошибок для подсветки ===
      const errorRegex = /cell\s+(\\d+)[^\\d]+line\s+(\\d+)/gi;
      const errors = [];
      let m;
      while ((m = errorRegex.exec(text)) !== null) {
        errors.push({ cell: parseInt(m[1]), line: parseInt(m[2]) });
      }

      highlightErrors(errors);
    };

    const button = new ToolbarButton({
      label: 'Lint',
      onClick: runLint,
      tooltip: 'Проверить ноутбук AI‑линтером'
    });

    app.docRegistry.addWidgetExtension('Notebook', {
      createNew: () => button
    });
  }
};

export default plugin;
EOF

echo "=== Установка зависимостей ==="
npm install

echo "=== Сборка расширения ==="
npm run build

echo "=== Регистрация расширения в JupyterLab ==="
/opt/jupyterhub/jupyterhub-venv/bin/jupyter labextension develop . --overwrite
/opt/jupyterhub/jupyterhub-venv/bin/jupyter lab build

echo "=== Перезапуск JupyterHub ==="
systemctl restart jupyterhub

echo "=== Готово! В JupyterLab появилась кнопка Lint, панель отчётов и подсветка ошибок ==="
