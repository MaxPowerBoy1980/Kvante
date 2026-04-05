"""Robust JSON extraction from LLM responses.

Handles common issues with local models (Ollama/DeepSeek):
- <think>...</think> reasoning tags
- Markdown code fences
- Prose before/after JSON
- Trailing commas
"""

import json
import logging
import re

logger = logging.getLogger(__name__)


def extract_json(raw: str) -> dict:
    """Extract a JSON object from an LLM response, handling common formatting issues."""
    cleaned = raw.strip()

    # Remove <think>...</think> blocks (DeepSeek R1)
    cleaned = re.sub(r"<think>.*?</think>", "", cleaned, flags=re.DOTALL).strip()

    # Remove markdown code fences
    if "```" in cleaned:
        # Find content between first ``` and last ```
        match = re.search(r"```(?:json)?\s*\n?(.*?)```", cleaned, re.DOTALL)
        if match:
            cleaned = match.group(1).strip()

    # Try direct parse first
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass

    # Try to find JSON object in the text
    match = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if match:
        json_str = match.group(0)
        # Remove trailing commas before } or ]
        json_str = re.sub(r",\s*([}\]])", r"\1", json_str)
        try:
            return json.loads(json_str)
        except json.JSONDecodeError as e:
            logger.warning("Found JSON-like content but failed to parse: %s", e)
            raise

    raise json.JSONDecodeError("No JSON object found in response", cleaned, 0)
