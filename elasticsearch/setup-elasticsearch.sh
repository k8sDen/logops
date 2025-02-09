#!/bin/bash

# Проверяем, установлен ли пароль для суперпользователя elastic
if [ -z "${ELASTIC_PASSWORD}" ]; then
  echo "Пожалуйста, установите переменную окружения ELASTIC_PASSWORD в .env файле"
  exit 1
fi

# Создание корневого сертификата (CA), если его ещё нет
if [ ! -f config/certs/ca.zip ]; then
  echo "Создаём корневой сертификат (CA)..."
  bin/elasticsearch-certutil ca --silent --pem -out config/certs/ca.zip
  unzip config/certs/ca.zip -d config/certs
fi

# Создание сертификатов для узлов Elasticsearch, если их ещё нет
if [ ! -f config/certs/certs.zip ]; then
  echo "Создаём сертификаты для узлов..."

  # Генерация файла конфигурации для сертификатов
  cat << EOF > config/certs/instances.yml
instances:
  - name: es-master
    dns:
      - es-master
      - localhost
    ip:
      - 127.0.0.1

  - name: es-hot
    dns:
      - es-hot
      - localhost
    ip:
      - 127.0.0.1

  - name: es-content
    dns:
      - es-content
      - localhost
    ip:
      - 127.0.0.1

  - name: es-ingest
    dns:
      - es-ingest
      - localhost
    ip:
      - 127.0.0.1
EOF

  # Генерация сертификатов на основе созданной конфигурации
  bin/elasticsearch-certutil cert --silent --pem -out config/certs/certs.zip --in config/certs/instances.yml --ca-cert config/certs/ca/ca.crt --ca-key config/certs/ca/ca.key
  unzip config/certs/certs.zip -d config/certs
fi

# Настройка прав доступа к сертификатам
echo "Настройка прав доступа к файлам..."
chown -R root:root config/certs
find config/certs -type d -exec chmod 750 {} \;
find config/certs -type f -exec chmod 640 {} \;

# Ожидание запуска Elasticsearch
echo "Ожидание доступности Elasticsearch..."
until curl -s --cacert config/certs/ca/ca.crt https://es-master:9200 | grep -q "missing authentication credentials"; do
  sleep 30
done

# Установка пароля для kibana_system
echo "Устанавливаем пароль для пользователя kibana_system..."
until curl -s -X POST --cacert config/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
  https://es-master:9200/_security/user/kibana_system/_password -d "{\"password\":\"kibana123\"}" | grep -q "^{}"; do
  sleep 10
done


# Создание пользователя nginx-user с правами суперпользователя
echo "Создаём пользователя nginx-user с правами superuser..."
curl -X POST "https://es-master:9200/_security/user/nginx-user" -H "Content-Type: application/json" -u "elastic:${ELASTIC_PASSWORD}" --cacert /usr/share/elasticsearch/config/certs/ca/ca.crt -d '
{
  "password": "nginxpassword",
  "roles": ["superuser"],
  "full_name": "Nginx User",
  "email": "nginxuser@example.com"
}'

# Создание ILM-политики hot-3
echo "Создаём ILM-политику hot-3..."
curl -X PUT "https://es-master:9200/_ilm/policy/hot-3" -H "Content-Type: application/json" -u "elastic:${ELASTIC_PASSWORD}" --cacert /usr/share/elasticsearch/config/certs/ca/ca.crt -d '
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age": "3d",
            "max_size": "50gb"
          }
        }
      }
    }
  }
}'

# Создание ILM-политики hot-7
echo "Создаём ILM-политику hot-7..."
curl -X PUT "https://es-master:9200/_ilm/policy/hot-7" -H "Content-Type: application/json" -u "elastic:${ELASTIC_PASSWORD}" --cacert /usr/share/elasticsearch/config/certs/ca/ca.crt -d '
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age": "7d",
            "max_size": "50gb"
          }
        }
      }
    }
  }
}'

# Создание index_template для ILM hot-3 с приоритетом 0
echo "Создаём шаблон индекса hot-3..."
curl -X PUT "https://es-master:9200/_index_template/hot-3" -H "Content-Type: application/json" -u "elastic:${ELASTIC_PASSWORD}" --cacert /usr/share/elasticsearch/config/certs/ca/ca.crt -d '
{
  "index_patterns": ["nginx-logs-*"],
  "priority": 0,
  "template": {
    "settings": {
      "index.lifecycle.name": "hot-3",
      "index.lifecycle.rollover_alias": "nginx-logs-hot-3"
    },
    "mappings": {
      "properties": {
        "timestamp": {
          "type": "date"
        },
        "message": {
          "type": "text"
        },
        "status": {
          "type": "keyword"
        }
      }
    }
  }
}'

# Создание index_template для ILM hot-7 с приоритетом 1
echo "Создаём шаблон индекса hot-7..."
curl -X PUT "https://es-master:9200/_index_template/hot-7" -H "Content-Type: application/json" -u "elastic:${ELASTIC_PASSWORD}" --cacert /usr/share/elasticsearch/config/certs/ca/ca.crt -d '
{
  "index_patterns": ["nginx-logs-*"],
  "priority": 1,
  "template": {
    "settings": {
      "index.lifecycle.name": "hot-7",
      "index.lifecycle.rollover_alias": "nginx-logs-hot-7"
    },
    "mappings": {
      "properties": {
        "timestamp": {
          "type": "date"
        },
        "message": {
          "type": "text"
        },
        "status": {
          "type": "keyword"
        }
      }
    }
  }
}'

echo "Все настройки успешно выполнены!"