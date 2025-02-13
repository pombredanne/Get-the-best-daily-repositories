import logging

from eclipse.agent import Agent
from eclipse.eclipsepipe import EclipsePipe
from eclipse.engine import Engine
from eclipse.handler.ai import AIHandler
from eclipse.llm import LLMClient
from eclipse.prompt import PromptTemplate

from eclipse_handlers.wikipedia import WikipediaHandler

logger = logging.getLogger(__name__)


class TestWikiAIPipe:

    async def test_wiki_ai_sequence_pipe(self):
        # llm_config = {'model': 'gpt-4o', 'llm_type': 'openai'}
        # llm_config = {'model': 'anthropic.claude-3-5-sonnet-20240620-v1:0', 'llm_type': 'bedrock', 'async_mode': True}
        # llm_config = {'model': 'anthropic.claude-3-5-sonnet-20240620-v1:0', 'llm_type': 'bedrock'}
        llm_config = {
            "model": "mistral.mistral-large-2402-v1:0",
            "llm_type": "bedrock",
            "async_mode": True,
        }
        llm_client: LLMClient = LLMClient(llm_config=llm_config)
        content_handler = AIHandler(llm=llm_client)
        prompt_template = PromptTemplate()

        wikipedia_handler = WikipediaHandler()

        wikipedia_engine = Engine(
            handler=wikipedia_handler, prompt_template=prompt_template, llm=llm_client
        )

        wiki_agent = Agent(
            name="Content Retriever Agent",
            goal="Get the summary from the wikipedia for the given query and validate",
            role="Content Retriever",
            llm=llm_client,
            prompt_template=prompt_template,
            engines=[wikipedia_engine],
            max_retry=1,
        )

        ai_agent_engine = Engine(
            handler=content_handler, prompt_template=prompt_template, llm=llm_client
        )

        goal = """ Write as biography story about the person from the given content. """
        biographer_agent = Agent(
            name="Biography Agent",
            goal=goal,
            role="Biographer",
            llm=llm_client,
            prompt_template=prompt_template,
            engines=[ai_agent_engine],
            max_retry=3,
        )

        pipe = EclipsePipe(agents=[wiki_agent, biographer_agent])

        result = await pipe.flow(query_instruction="Walt Disney")

        logger.info(f"Biographer result => \n{result}")
