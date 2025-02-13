import logging
import os

import pytest
from eclipse.agent import Agent
from eclipse.engine import Engine
from eclipse.llm import LLMClient
from eclipse.prompt import PromptTemplate

from eclipse_handlers.ecommerce.walmart import WalmartHandler

logger = logging.getLogger(__name__)

"""
 Run Pytest:  

   1. pytest --log-cli-level=INFO tests/agent/test_walmart_agent.py::TestWalmartAgent::test_walmart_agent
"""


@pytest.fixture
def agent_client_init() -> dict:
    llm_config = {"model": "gpt-4o", "llm_type": "openai"}

    llm_client: LLMClient = LLMClient(llm_config=llm_config)
    response = {"llm": llm_client, "llm_type": "openai"}
    return response


class TestWalmartAgent:

    async def test_walmart_agent(self, agent_client_init: dict):
        llm_client: LLMClient = agent_client_init.get("llm")
        walmart_handler = WalmartHandler(api_key=os.getenv("RAPID_API_KEY"))
        prompt_template = PromptTemplate()
        walmart_engine = Engine(
            handler=walmart_handler, llm=llm_client, prompt_template=prompt_template
        )
        walmart_agent = Agent(
            goal="Get a proper answer for asking a question in Walmart.",
            role="You are the product searcher",
            llm=llm_client,
            prompt_template=prompt_template,
            engines=[walmart_engine],
        )
        result = await walmart_agent.execute(
            query_instruction="Get me the best product of Trimmer with 4.5 ratings"
        )
        logger.info(f"Result=>   {result}")
        assert result
