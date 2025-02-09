# Сбор и обработка логов Nginx с использованием Rsyslog, Kafka, Vector и ELK

## Описание проекта

Данный проект предназначен для автоматизации сбора, парсинга и анализа логов Nginx с использованием Rsyslog, Kafka и Vector с последующим сохранением в кластер Elasticsearch для анализа через Kibana.  
**Схема архитектуры:** Nginx + Rsyslog → Kafka → Vector → ELK (Elasticsearch + Kibana).

---

## Схема работы

1. **Nginx** генерирует access-логи.
2. Логи передаются с помощью **Rsyslog** в **Kafka**.
3. **Kafka** накапливает сообщения и передает их в **Vector**.
4. **Vector** парсит логи с помощью **grok patterns** и отправляет их в **Elasticsearch**.
5. **Kibana** предоставляет интерфейс для визуализации логов.

---
1. sudo chmod +x elasticsearch/setup-elasticsearch.sh
2. docker compose up -d --force-recreate

---
пароли:
kibana: elastic test123
