// ====================================================================
// Скрипт инициализации графа знаний в СУБД Neo4j (идемпотентный)
// Дисциплина: «Интеллектуальные системы и технологии»
// Практическая работа №32: GraphRAG и Text-to-Cypher в Langflow
// Запуск: cypher-shell -a bolt://neo4j:7687 -u neo4j -p <password> -f init_neo4j_graph.cypher
// Повторное выполнение безопасно (MERGE). Для полного сброса выполните:
//   MATCH (n) DETACH DELETE n;
// ====================================================================

// 1. Узел кафедры
MERGE (c:Department {name: "Интеллектуальные системы"})
SET c.code = "IS-DEPT",
    c.building = "Главный корпус, ауд. 405";

// 2. Преподаватели
MERGE (p1:Teacher {name: "Профессор Соколов"})
SET p1.degree = "д.т.н.", p1.position = "Заведующий кафедрой", p1.email = "sokolov@univ.edu";

MERGE (p2:Teacher {name: "Доцент Морозов"})
SET p2.degree = "к.т.н.", p2.position = "Доцент", p2.email = "morozov@univ.edu";

MERGE (p3:Teacher {name: "Старший преподаватель Васильев"})
SET p3.degree = "б/степени", p3.position = "Ст. преподаватель", p3.email = "vasiliev@univ.edu";

// 3. Курсы
MERGE (crs1:Course {title: "Интеллектуальные системы и технологии"})
SET crs1.code = "IST-101", crs1.hours = 144;

MERGE (crs2:Course {title: "Графовые базы данных"})
SET crs2.code = "GDB-202", crs2.hours = 108;

MERGE (crs3:Course {title: "Машинное обучение и анализ данных"})
SET crs3.code = "ML-303", crs3.hours = 180;

// 4. Студенты
MERGE (s1:Student {name: "Алексей Смирнов"})
SET s1.record_book = "200101", s1.group_num = "ИВТ-401";

MERGE (s2:Student {name: "Елена Кузнецова"})
SET s2.record_book = "200102", s2.group_num = "ИВТ-401";

MERGE (s3:Student {name: "Игорь Попов"})
SET s3.record_book = "200103", s3.group_num = "ИВТ-402";

// 5. Связи принадлежности к кафедре (BELONGS_TO)
MATCH (p1:Teacher {name: "Профессор Соколов"}), (c:Department {name: "Интеллектуальные системы"}) MERGE (p1)-[:BELONGS_TO]->(c);
MATCH (p2:Teacher {name: "Доцент Морозов"}), (c:Department {name: "Интеллектуальные системы"}) MERGE (p2)-[:BELONGS_TO]->(c);
MATCH (p3:Teacher {name: "Старший преподаватель Васильев"}), (c:Department {name: "Интеллектуальные системы"}) MERGE (p3)-[:BELONGS_TO]->(c);

// 6. Связи преподавания курсов (TEACHES)
MATCH (p1:Teacher {name: "Профессор Соколов"}), (crs1:Course {title: "Интеллектуальные системы и технологии"}) MERGE (p1)-[:TEACHES]->(crs1);
MATCH (p2:Teacher {name: "Доцент Морозов"}), (crs2:Course {title: "Графовые базы данных"}) MERGE (p2)-[:TEACHES]->(crs2);
MATCH (p3:Teacher {name: "Старший преподаватель Васильев"}), (crs3:Course {title: "Машинное обучение и анализ данных"}) MERGE (p3)-[:TEACHES]->(crs3);

// 7. Связи записи студентов на курсы (ENROLLED_IN)
MATCH (s1:Student {name: "Алексей Смирнов"}), (crs1:Course {title: "Интеллектуальные системы и технологии"}) MERGE (s1)-[:ENROLLED_IN]->(crs1);
MATCH (s1:Student {name: "Алексей Смирнов"}), (crs2:Course {title: "Графовые базы данных"}) MERGE (s1)-[:ENROLLED_IN]->(crs2);
MATCH (s2:Student {name: "Елена Кузнецова"}), (crs1:Course {title: "Интеллектуальные системы и технологии"}) MERGE (s2)-[:ENROLLED_IN]->(crs1);
MATCH (s3:Student {name: "Игорь Попов"}), (crs2:Course {title: "Графовые базы данных"}) MERGE (s3)-[:ENROLLED_IN]->(crs2);
MATCH (s3:Student {name: "Игорь Попов"}), (crs3:Course {title: "Машинное обучение и анализ данных"}) MERGE (s3)-[:ENROLLED_IN]->(crs3);

// 8. Связи научного руководства (MENTORED_BY)
MATCH (s1:Student {name: "Алексей Смирнов"}), (p1:Teacher {name: "Профессор Соколов"}) MERGE (s1)-[:MENTORED_BY]->(p1);
MATCH (s2:Student {name: "Елена Кузнецова"}), (p2:Teacher {name: "Доцент Морозов"}) MERGE (s2)-[:MENTORED_BY]->(p2);
MATCH (s3:Student {name: "Игорь Попов"}), (p3:Teacher {name: "Старший преподаватель Васильев"}) MERGE (s3)-[:MENTORED_BY]->(p3);
