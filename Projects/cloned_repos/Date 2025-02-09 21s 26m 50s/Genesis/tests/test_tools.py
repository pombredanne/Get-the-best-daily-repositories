import unittest

from genesis_agentic.tools import VectaraTool, VectaraToolFactory, ToolsFactory, ToolType
from genesis_agentic.agent import Agent
from pydantic import Field, BaseModel
from llama_index.core.tools import FunctionTool


class TestToolsPackage(unittest.TestCase):
    def test_genesis_tool_factory(self):
        genesis_customer_id = "4584783"
        genesis_corpus_id = "4"
        genesis_api_key = "api_key"
        vec_factory = VectaraToolFactory(
            genesis_customer_id, genesis_corpus_id, genesis_api_key
        )

        self.assertEqual(genesis_customer_id, vec_factory.genesis_customer_id)
        self.assertEqual(genesis_corpus_id, vec_factory.genesis_corpus_id)
        self.assertEqual(genesis_api_key, vec_factory.genesis_api_key)

        class QueryToolArgs(BaseModel):
            query: str = Field(description="The user query")

        query_tool = vec_factory.create_rag_tool(
            tool_name="rag_tool",
            tool_description="""
            Returns a response (str) to the user query based on the data in this corpus.
            """,
            tool_args_schema=QueryToolArgs,
        )

        self.assertIsInstance(query_tool, VectaraTool)
        self.assertIsInstance(query_tool, FunctionTool)
        self.assertEqual(query_tool.metadata.tool_type, ToolType.QUERY)

    def test_tool_factory(self):
        def mult(x, y):
            return x * y

        tools_factory = ToolsFactory()
        other_tool = tools_factory.create_tool(mult)
        self.assertIsInstance(other_tool, VectaraTool)
        self.assertIsInstance(other_tool, FunctionTool)
        self.assertEqual(other_tool.metadata.tool_type, ToolType.QUERY)

    def test_llama_index_tools(self):
        tools_factory = ToolsFactory()

        llama_tools = tools_factory.get_llama_index_tools(
            tool_package_name="arxiv",
            tool_spec_name="ArxivToolSpec"
        )

        arxiv_tool = llama_tools[0]

        self.assertIsInstance(arxiv_tool, VectaraTool)
        self.assertIsInstance(arxiv_tool, FunctionTool)
        self.assertEqual(arxiv_tool.metadata.tool_type, ToolType.QUERY)

    def test_public_repo(self):
        genesis_customer_id = "1366999410"
        genesis_corpus_id = "1"
        genesis_api_key = "zqt_UXrBcnI2UXINZkrv4g1tQPhzj02vfdtqYJIDiA"

        class QueryToolArgs(BaseModel):
            query: str = Field(description="The user query")

        agent = Agent.from_corpus(
            genesis_customer_id=genesis_customer_id,
            genesis_corpus_id=genesis_corpus_id,
            genesis_api_key=genesis_api_key,
            tool_name="ask_genesis",
            data_description="data from Vectara website",
            assistant_specialty="RAG as a service",
            genesis_summarizer="mockingbird-1.0-2024-07-16"
        )

        self.assertIn("Vectara is an end-to-end platform", agent.chat("What is Vectara?"))


if __name__ == "__main__":
    unittest.main()
