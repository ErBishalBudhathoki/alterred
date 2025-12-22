"""
ADK Model Wrapper
=================
Wrapper for ADK models with robust error handling, logging, and monitoring.
"""

import time
import logging
from typing import Dict, Any, Optional, AsyncIterator
from dataclasses import dataclass

from services.vertex_ai_client import VertexAIClient
from services.metrics_service import record_model_usage

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class ModelInput:
    prompt: str
    model_name: str = "gemini-2.0-flash-exp"
    parameters: Optional[Dict[str, Any]] = None
    user_id: Optional[str] = None

@dataclass
class ModelOutput:
    text: str
    model_name: str
    latency_ms: int
    mode: str
    tokens_input: int = 0
    tokens_output: int = 0
    error: Optional[str] = None

class ADKModelWrapper:
    """
    Robust wrapper for ADK models (via VertexAIClient).
    Standardizes I/O and adds monitoring.
    """

    def __init__(self, user_id: Optional[str] = None):
        self.client = VertexAIClient(user_id=user_id)
        self.user_id = user_id

    async def generate(self, input_data: ModelInput) -> ModelOutput:
        """
        Generate content with comprehensive monitoring.
        """
        start_time = time.time()
        mode_str = "unknown"
        text_parts = []
        error_msg = None
        
        try:
            # Determine mode first to log it correctly
            mode_enum = self.client.determine_mode()
            mode_str = mode_enum.value
            
            logger.info(f"Generating content for user {self.user_id} using mode {mode_str}")

            # Use the underlying client's async generator
            async for chunk in self.client.generate_content_async(
                prompt=input_data.prompt,
                model_name=input_data.model_name,
                **(input_data.parameters or {})
            ):
                text_parts.append(chunk)
            
        except Exception as e:
            error_msg = str(e)
            logger.error(f"Model generation failed: {e}")
        
        end_time = time.time()
        latency_ms = int((end_time - start_time) * 1000)
        full_text = "".join(text_parts)
        
        # Log metrics
        record_model_usage(
            model_name=input_data.model_name,
            latency_ms=latency_ms,
            status="error" if error_msg else "success",
            error=error_msg
        )
        
        return ModelOutput(
            text=full_text,
            model_name=input_data.model_name,
            latency_ms=latency_ms,
            mode=mode_str,
            error=error_msg
        )

    async def generate_stream(self, input_data: ModelInput) -> AsyncIterator[str]:
        """
        Stream content with monitoring (metrics logged at end of stream).
        """
        start_time = time.time()
        # No need to track mode string in streaming path
        error_msg = None
        
        try:
            self.client.determine_mode()
            
            async for chunk in self.client.generate_content_async(
                prompt=input_data.prompt,
                model_name=input_data.model_name,
                **(input_data.parameters or {})
            ):
                yield chunk
                
        except Exception as e:
            error_msg = str(e)
            logger.error(f"Model streaming failed: {e}")
            raise e
        finally:
            end_time = time.time()
            latency_ms = int((end_time - start_time) * 1000)
            
            record_model_usage(
                model_name=input_data.model_name,
                latency_ms=latency_ms,
                status="error" if error_msg else "success",
                error=error_msg
            )
