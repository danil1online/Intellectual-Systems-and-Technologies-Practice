#!/usr/bin/env bash
set -euo pipefail

JH_USER="jupyter"
JH_VENV="/opt/jupyterhub/jupyterhub-venv"
JH_CONFIG_DIR="/opt/jupyterhub"
JH_CONFIG_FILE="${JH_CONFIG_DIR}/jupyterhub_config.py"
JH_SERVICE_FILE="/etc/systemd/system/jupyterhub.service"
PYTHON_BIN="/usr/bin/python3.10"
GROUP="jupyterstudents"
STUDENT_PREFIX="student"
STUDENTS=29
PORT=8000

echo "=== Удаление конфликтующих Node.js пакетов ==="
apt remove -y nodejs libnode72 libnode-dev libnode72:amd64 || true
apt autoremove -y
apt clean
rm -f /var/cache/apt/archives/nodejs_*.deb || true

echo "=== Установка базовых пакетов ==="
apt update
apt install -y curl wget git build-essential ca-certificates gnupg lsb-release \
  python3.10 python3.10-venv python3-pip apt-transport-https software-properties-common

echo "=== Установка Node.js 18 LTS ==="
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
echo "Node: $(node -v) | NPM: $(npm -v)"

echo "=== Установка Docker CE ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io
systemctl enable --now docker

echo "=== Создание пользователя и группы ==="
useradd -m -s /bin/bash "${JH_USER}" || true
echo "${JH_USER}:novocherkassk" | chpasswd
groupadd "${GROUP}" || true
usermod -aG "${GROUP},docker" "${JH_USER}" || true

echo "=== Создание студентов с активными паролями ==="
for i in $(seq 1 ${STUDENTS}); do
  uname="${STUDENT_PREFIX}${i}"
  upass="_student_${i}_"
  useradd -m -s /bin/bash -G "${GROUP},docker" "${uname}" || true
  echo "${uname}:${upass}" | chpasswd
done

echo "=== Создание общего каталога /home/jupyter/work с доступом для студентов ==="
mkdir -p /home/jupyter/work
chown root:jupyterstudents /home/jupyter/work
chmod 2755 /home/jupyter
chmod 2775 /home/jupyter/work

# Установка ACL для чтения/записи всех текущих и будущих файлов
setfacl -R -m g:jupyterstudents:rwX /home/jupyter/work
setfacl -R -m d:g:jupyterstudents:rwX /home/jupyter/work

echo "=== Создание каталога /home/jupyter/work/data с доступом для студентов ==="
mkdir -p /home/jupyter/work/data
chown root:jupyterstudents /home/jupyter/work/data
chmod 2775 /home/jupyter/work/data

# Установка ACL для текущих и будущих файлов
setfacl -R -m g:jupyterstudents:rwX /home/jupyter/work/data
setfacl -R -m d:g:jupyterstudents:rwX /home/jupyter/work/data

# Логирование прав доступа
echo "--- ACL на /home/jupyter/work/data ---"
getfacl /home/jupyter/work/data | tee /var/log/jupyterhub_data_acl.log

echo "=== Создание виртуального окружения ==="
mkdir -p "$(dirname "${JH_VENV}")"
"${PYTHON_BIN}" -m venv "${JH_VENV}"
"${JH_VENV}/bin/pip" install --upgrade pip setuptools wheel

echo "=== Установка JupyterHub и JupyterLab ==="
"${JH_VENV}/bin/pip" install jupyterhub jupyterlab notebook ipywidgets

echo "=== Установка PyTorch CPU-only и ML-библиотек ==="
"${JH_VENV}/bin/pip" install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
"${JH_VENV}/bin/pip" install numpy scipy pandas scikit-learn matplotlib transformers datasets

echo "=== Установка configurable-http-proxy ==="
npm install -g configurable-http-proxy
ln -sf "$(npm bin -g)/configurable-http-proxy" /usr/local/bin/configurable-http-proxy

echo "=== Конфигурация JupyterHub ==="
mkdir -p "${JH_CONFIG_DIR}"
cat > "${JH_CONFIG_FILE}" <<EOF
c = get_config()
c.JupyterHub.bind_url = 'http://0.0.0.0:${PORT}'
c.JupyterHub.cookie_secret_file = '${JH_CONFIG_DIR}/jupyterhub_cookie_secret'
c.Authenticator.allow_all = True  # можно раскомментировать для теста
EOF

echo "=== Генерация корректного cookie_secret ==="
openssl rand -hex 32 | tee "${JH_CONFIG_DIR}/jupyterhub_cookie_secret" > /dev/null
#openssl rand -base64 32 | tee "${JH_CONFIG_DIR}/jupyterhub_cookie_secret" > /dev/null
chmod 600 "${JH_CONFIG_DIR}/jupyterhub_cookie_secret"
chown root:root "${JH_CONFIG_DIR}/jupyterhub_cookie_secret"

echo "=== Создание systemd unit ==="
cat > "${JH_SERVICE_FILE}" <<EOF
[Unit]
Description=JupyterHub
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${JH_CONFIG_DIR}
Environment="PATH=/opt/jupyterhub/jupyterhub-venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=${JH_VENV}/bin/jupyterhub -f ${JH_CONFIG_FILE}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "=== Запуск JupyterHub ==="
systemctl daemon-reload
systemctl enable --now jupyterhub.service
