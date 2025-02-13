import logging

import pytest

from eclipse_handlers.wikipedia import WikipediaHandler

logger = logging.getLogger(__name__)
"""
 Run Pytest:  

   1. pytest --log-cli-level=INFO tests/handlers/test_wikipedia.py::TestWikipedia::test_summary

"""


@pytest.fixture
def wikipedia_client_init() -> WikipediaHandler:
    search = WikipediaHandler()
    return search


class TestWikipedia:

    async def test_summary(self, wikipedia_client_init: WikipediaHandler):
        res = await wikipedia_client_init.get_summary(
            query="Sachin Tendulkar",
        )
        logger.info(f"Wikipedia Result {res}")
