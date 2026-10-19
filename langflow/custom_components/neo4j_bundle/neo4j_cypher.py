"""Компонент Neo4j Cypher для Langflow (кастомный бандл ISTP).

Выполняет Cypher-запрос к графовой БД Neo4j и возвращает результат текстом.
Устанавливается в образ через LANGFLOW_COMPONENTS_PATH.
"""

from lfx.custom.custom_component.component import Component
from lfx.io import MessageTextInput, MultilineInput, Output
from lfx.schema.message import Message


class Neo4jCypherComponent(Component):
    """Executes a Cypher query on a Neo4j graph database."""

    display_name = "Neo4j Cypher"
    description = (
        "Connects to a Neo4j graph database and executes a Cypher query. "
        "Returns the result records as text."
    )
    icon = "database"
    name = "Neo4jCypherComponent"
    metadata = {"keywords": ["neo4j", "cypher", "graph", "database", "rag"]}

    inputs = [
        MessageTextInput(
            name="uri",
            display_name="Neo4j URI",
            value="bolt://neo4j:7687",
            required=True,
            placeholder="bolt://neo4j:7687",
        ),
        MessageTextInput(
            name="username",
            display_name="Username",
            value="neo4j",
            required=True,
        ),
        MultilineInput(
            name="password",
            display_name="Password",
            required=True,
            password=True,
        ),
        MultilineInput(
            name="query",
            display_name="Cypher Query",
            required=True,
            placeholder='MATCH (n) RETURN n LIMIT 10',
        ),
    ]

    outputs = [
        Output(
            display_name="Result",
            name="run_cypher_query",
            method="run_cypher_query",
        ),
    ]

    def run_cypher_query(self) -> Message:
        try:
            import neo4j
        except ImportError as exc:  # pragma: no cover
            raise ValueError(
                "neo4j driver is not installed in the Langflow image"
            ) from exc

        lines = []
        try:
            with neo4j.GraphDatabase.driver(
                self.uri, auth=(self.username, self.password)
            ) as driver:
                with driver.session() as session:
                    result = session.run(self.query)
                    for record in result:
                        lines.append(str(dict(record)))
        except Exception as exc:
            raise ValueError(f"Neo4j query failed: {exc}") from exc

        text = "\n".join(lines) if lines else "Empty result"
        return Message(text=text)
