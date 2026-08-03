#!/bin/bash
# Фикс конфигурации OnlyOffice при запуске
sleep 5

# Фиксим logger.json
cat > /etc/onlyoffice/documentserver/logger.json << 'LOGEOF'
{
  "level": "warn",
  "replaceConsole": true,
  "appenders": {
    "console": {
      "type": "console"
    }
  },
  "categories": {
    "default": {
      "appenders": ["console"],
      "level": "warn"
    }
  }
}
LOGEOF

# Фиксим production.json
cat > /etc/onlyoffice/documentserver/log4js/production.json << 'PRODEOF'
{
  "appenders": {
    "console": {
      "type": "console",
      "layout": {
        "type": "patternWithTokens",
        "pattern": "[%d] [%p] [%X{TENANT}] [%X{DOCID}] [%X{USERID}]%x{usid} %c - %.10000m"
      }
    }
  },
  "categories": {
    "default": {
      "appenders": ["console"],
      "level": "warn"
    }
  }
}
PRODEOF

# Фиксим JWT_IN_BODY
docker exec onlyoffice python3 -c "
import json
f = '/etc/onlyoffice/documentserver/local.json'
d = json.load(open(f))
d['services']['CoAuthoring']['token']['inbox']['inBody'] = True
d['services']['CoAuthoring']['token']['outbox']['inBody'] = True
with open(f, 'w') as f2:
    json.dump(d, f2, indent=2)
"

echo "OnlyOffice config fixed"
