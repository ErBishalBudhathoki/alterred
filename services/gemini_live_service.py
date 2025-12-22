"""
Gemini Live API Service
========================

Real-time bidirectional voice conversation using Gemini's Live API.

This service provides:
- WebSocket-based real-time audio streaming
- Built-in voice activity detection (no self-listening)
- Native audio input/output (no separate STT/TTS)
- Low-latency conversational AI

Architecture:
- Uses Gemini 2.0 Flash with Live API for real-time multimodal interaction
- Audio is streamed bidirectionally over WebSocket
- Server handles audio encoding/decoding
- Built-in echo cancellation via activity detection

Usage:
- Frontend connects via WebSocket to /ws/voice
- Sends raw audio chunks (PCM 16-bit, 16kHz mono)
- Receives audio response chunks + text transcripts
"""

import asyncio
import base64
import logging
import os
from typing import Optional, Callable
from dataclasses import dataclass, field
from enum import Enum

logger = logging.getLogger(__name__)


class VoiceSessionState(Enum):
    """State of a voice session."""
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    LISTENING = "listening"
    PROCESSING = "processing"
    SPEAKING = "speaking"
    ERROR = "error"


@dataclass
class VoiceSessionConfig:
    """Configuration for a voice session."""
    model: str = "gemini-2.0-flash-live-001"
    system_instruction: str = ""
    voice: str = "Aoede"  # Gemini voice options: Puck, Charon, Kore, Fenrir, Aoede
    language: str = "en-US"
    sample_rate: int = 16000
    enable_transcription: bool = True
    tools: list = field(default_factory=list)


class GeminiLiveService:
    """
    Service for real-time voice conversations using Gemini Live API.
    
    This provides a WebSocket-based interface for bidirectional audio streaming
    with automatic voice activity detection and echo cancellation.
    """

    _client = None
    _initialized = False

    @classmethod
    def initialize(cls) -> bool:
        """Initialize the Gemini client."""
        if cls._initialized:
            return True

        try:
            from google import genai

            # Check for Vertex AI configuration
            project_id = os.getenv("VERTEX_AI_PROJECT_ID") or os.getenv("GCP_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT")
            location = os.getenv("VERTEX_AI_LOCATION", "us-central1")

            if project_id:
                # Use Vertex AI
                cls._client = genai.Client(
                    vertexai=True,
                    project=project_id,
                    location=location,
                )
                logger.info(f"Gemini Live Service initialized with Vertex AI (project={project_id}, location={location})")
            else:
                # Use API key
                api_key = os.getenv("GOOGLE_API_KEY")
                if not api_key:
                    logger.error("No GOOGLE_API_KEY or Vertex AI project configured")
                    return False
                cls._client = genai.Client(api_key=api_key)
                logger.info("Gemini Live Service initialized with API key")

            cls._initialized = True
            return True

        except ImportError as e:
            logger.error(f"Failed to import google-genai: {e}")
            return False
        except Exception as e:
            logger.error(f"Failed to initialize Gemini Live Service: {e}")
            return False

    @classmethod
    def get_client(cls):
        """Get the initialized Gemini client."""
        if not cls._initialized:
            cls.initialize()
        return cls._client

    @classmethod
    async def create_live_session(
        cls,
        config: VoiceSessionConfig,
        on_audio: Optional[Callable[[bytes], None]] = None,
        on_text: Optional[Callable[[str], None]] = None,
        on_transcript: Optional[Callable[[str, bool], None]] = None,
        on_state_change: Optional[Callable[[VoiceSessionState], None]] = None,
    ) -> Optional["LiveVoiceSession"]:
        """
        Create a new live voice session.
        
        Args:
            config: Session configuration
            on_audio: Callback for audio output chunks
            on_text: Callback for text responses
            on_transcript: Callback for transcripts (text, is_final)
            on_state_change: Callback for state changes
            
        Returns:
            LiveVoiceSession instance or None if failed
        """
        client = cls.get_client()
        if not client:
            logger.error("Gemini client not initialized")
            return None

        try:
            session = LiveVoiceSession(
                client=client,
                config=config,
                on_audio=on_audio,
                on_text=on_text,
                on_transcript=on_transcript,
                on_state_change=on_state_change,
            )
            return session
        except Exception as e:
            logger.error(f"Failed to create live session: {e}")
            return None


class LiveVoiceSession:
    """
    A live voice session with Gemini.
    
    Handles bidirectional audio streaming with automatic voice activity detection.
    """

    def __init__(
        self,
        client,
        config: VoiceSessionConfig,
        on_audio: Optional[Callable[[bytes], None]] = None,
        on_text: Optional[Callable[[str], None]] = None,
        on_transcript: Optional[Callable[[str, bool], None]] = None,
        on_state_change: Optional[Callable[[VoiceSessionState], None]] = None,
    ):
        self._client = client
        self._config = config
        self._on_audio = on_audio
        self._on_text = on_text
        self._on_transcript = on_transcript
        self._on_state_change = on_state_change

        self._session = None
        self._state = VoiceSessionState.DISCONNECTED
        self._receive_task: Optional[asyncio.Task] = None
        self._is_running = False

    @property
    def state(self) -> VoiceSessionState:
        return self._state

    def _set_state(self, state: VoiceSessionState):
        if self._state != state:
            self._state = state
            if self._on_state_change:
                try:
                    self._on_state_change(state)
                except Exception as e:
                    logger.error(f"State change callback error: {e}")

    async def connect(self) -> bool:
        """Connect to the Gemini Live API."""
        if self._state != VoiceSessionState.DISCONNECTED:
            logger.warning(f"Cannot connect: already in state {self._state}")
            return False

        self._set_state(VoiceSessionState.CONNECTING)

        try:
            from google.genai import types

            # Build configuration
            live_config = types.LiveConnectConfig(
                response_modalities=["AUDIO", "TEXT"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name=self._config.voice,
                        )
                    )
                ),
            )

            # Add system instruction if provided
            if self._config.system_instruction:
                live_config.system_instruction = types.Content(
                    parts=[types.Part(text=self._config.system_instruction)]
                )

            # Add tools if provided
            if self._config.tools:
                live_config.tools = self._config.tools

            # Connect to the Live API
            self._session = await self._client.aio.live.connect(
                model=self._config.model,
                config=live_config,
            )

            self._is_running = True
            self._set_state(VoiceSessionState.CONNECTED)

            # Start receive loop
            self._receive_task = asyncio.create_task(self._receive_loop())

            logger.info(f"Connected to Gemini Live API with model {self._config.model}")
            return True

        except Exception as e:
            logger.error(f"Failed to connect to Gemini Live API: {e}", exc_info=True)
            self._set_state(VoiceSessionState.ERROR)
            return False

    async def disconnect(self):
        """Disconnect from the Gemini Live API."""
        self._is_running = False

        if self._receive_task:
            self._receive_task.cancel()
            try:
                await self._receive_task
            except asyncio.CancelledError:
                pass
            self._receive_task = None

        if self._session:
            try:
                await self._session.close()
            except Exception as e:
                logger.warning(f"Error closing session: {e}")
            self._session = None

        self._set_state(VoiceSessionState.DISCONNECTED)
        logger.info("Disconnected from Gemini Live API")

    async def send_audio(self, audio_data: bytes):
        """
        Send audio data to the model.
        
        Args:
            audio_data: Raw PCM audio (16-bit, 16kHz, mono)
        """
        if not self._session or self._state == VoiceSessionState.DISCONNECTED:
            logger.warning("Cannot send audio: not connected")
            return

        try:
            from google.genai import types

            # Send audio as realtime input
            await self._session.send(
                input=types.LiveClientRealtimeInput(
                    media_chunks=[
                        types.Blob(
                            data=audio_data,
                            mime_type="audio/pcm;rate=16000",
                        )
                    ]
                )
            )

            if self._state == VoiceSessionState.CONNECTED:
                self._set_state(VoiceSessionState.LISTENING)

        except Exception as e:
            logger.error(f"Failed to send audio: {e}")

    async def send_text(self, text: str, end_of_turn: bool = True):
        """
        Send text input to the model.
        
        Args:
            text: Text message
            end_of_turn: Whether this ends the user's turn
        """
        if not self._session or self._state == VoiceSessionState.DISCONNECTED:
            logger.warning("Cannot send text: not connected")
            return

        try:
            await self._session.send(input=text, end_of_turn=end_of_turn)
            self._set_state(VoiceSessionState.PROCESSING)
        except Exception as e:
            logger.error(f"Failed to send text: {e}")

    async def _receive_loop(self):
        """Background task to receive messages from the model."""
        try:
            async for message in self._session.receive():
                if not self._is_running:
                    break

                await self._handle_message(message)

        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"Receive loop error: {e}", exc_info=True)
            self._set_state(VoiceSessionState.ERROR)

    async def _handle_message(self, message):
        """Handle a message from the model."""
        try:
            # Check for server content (audio/text responses)
            if hasattr(message, 'server_content') and message.server_content:
                content = message.server_content

                # Handle audio chunks
                if hasattr(content, 'model_turn') and content.model_turn:
                    self._set_state(VoiceSessionState.SPEAKING)

                    for part in content.model_turn.parts:
                        # Audio data
                        if hasattr(part, 'inline_data') and part.inline_data:
                            if self._on_audio:
                                self._on_audio(part.inline_data.data)

                        # Text data
                        if hasattr(part, 'text') and part.text:
                            if self._on_text:
                                self._on_text(part.text)

                # Handle turn completion
                if hasattr(content, 'turn_complete') and content.turn_complete:
                    self._set_state(VoiceSessionState.CONNECTED)

                # Handle input transcription
                if hasattr(content, 'input_transcription') and content.input_transcription:
                    if self._on_transcript:
                        is_final = getattr(content.input_transcription, 'is_final', True)
                        text = getattr(content.input_transcription, 'text', '')
                        self._on_transcript(text, is_final)

                # Handle output transcription
                if hasattr(content, 'output_transcription') and content.output_transcription:
                    if self._on_transcript:
                        text = getattr(content.output_transcription, 'text', '')
                        self._on_transcript(f"[Assistant] {text}", True)

            # Check for tool calls
            if hasattr(message, 'tool_call') and message.tool_call:
                logger.info(f"Tool call received: {message.tool_call}")
                # Tool calls can be handled here if needed

        except Exception as e:
            logger.error(f"Error handling message: {e}", exc_info=True)


# WebSocket handler for FastAPI
async def handle_voice_websocket(
    websocket,
    user_id: str,
    system_prompt: str = "",
    voice: str = "Aoede",
):
    """
    Handle a WebSocket connection for real-time voice.
    
    Protocol:
    - Client sends: {"type": "audio", "data": "<base64 PCM audio>"}
    - Client sends: {"type": "text", "data": "<text message>"}
    - Client sends: {"type": "config", "voice": "...", "system_prompt": "..."}
    - Server sends: {"type": "audio", "data": "<base64 PCM audio>"}
    - Server sends: {"type": "text", "data": "<text>"}
    - Server sends: {"type": "transcript", "data": "<transcript>", "is_final": bool}
    - Server sends: {"type": "state", "state": "<state>"}
    - Server sends: {"type": "error", "message": "<error>"}
    """
    from fastapi import WebSocketDisconnect

    logger.info(f"Voice WebSocket connected for user {user_id}")

    config = VoiceSessionConfig(
        system_instruction=system_prompt,
        voice=voice,
    )

    async def on_audio(data: bytes):
        try:
            await websocket.send_json({
                "type": "audio",
                "data": base64.b64encode(data).decode('utf-8'),
            })
        except Exception as e:
            logger.error(f"Failed to send audio: {e}")

    async def on_text(text: str):
        try:
            await websocket.send_json({
                "type": "text",
                "data": text,
            })
        except Exception as e:
            logger.error(f"Failed to send text: {e}")

    async def on_transcript(text: str, is_final: bool):
        try:
            await websocket.send_json({
                "type": "transcript",
                "data": text,
                "is_final": is_final,
            })
        except Exception as e:
            logger.error(f"Failed to send transcript: {e}")

    def on_state_change(state: VoiceSessionState):
        try:
            asyncio.create_task(websocket.send_json({
                "type": "state",
                "state": state.value,
            }))
        except Exception as e:
            logger.error(f"Failed to send state: {e}")

    session = await GeminiLiveService.create_live_session(
        config=config,
        on_audio=on_audio,
        on_text=on_text,
        on_transcript=on_transcript,
        on_state_change=on_state_change,
    )

    if not session:
        await websocket.send_json({
            "type": "error",
            "message": "Failed to create voice session",
        })
        await websocket.close()
        return

    try:
        if not await session.connect():
            await websocket.send_json({
                "type": "error",
                "message": "Failed to connect to Gemini Live API",
            })
            await websocket.close()
            return

        # Main message loop
        while True:
            try:
                message = await websocket.receive_json()
                msg_type = message.get("type")

                if msg_type == "audio":
                    # Decode base64 audio and send to model
                    audio_data = base64.b64decode(message.get("data", ""))
                    await session.send_audio(audio_data)

                elif msg_type == "text":
                    # Send text message
                    text = message.get("data", "")
                    await session.send_text(text)

                elif msg_type == "config":
                    # Update configuration (would need to reconnect)
                    logger.info(f"Config update requested: {message}")

                elif msg_type == "ping":
                    await websocket.send_json({"type": "pong"})

            except WebSocketDisconnect:
                logger.info(f"Voice WebSocket disconnected for user {user_id}")
                break
            except Exception as e:
                logger.error(f"Error processing message: {e}")
                await websocket.send_json({
                    "type": "error",
                    "message": str(e),
                })

    finally:
        await session.disconnect()
        logger.info(f"Voice session ended for user {user_id}")
