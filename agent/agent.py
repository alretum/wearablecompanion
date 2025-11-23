import logging
import json
import os
import aiohttp
from functools import partial
from dotenv import load_dotenv
from livekit.agents import (
    Agent,
    AgentSession,
    AgentServer,
    JobContext,
    JobProcess,
    cli,
    inference,
    room_io,
)
from livekit import rtc
from livekit.plugins import noise_cancellation, silero
from livekit.plugins.turn_detector.multilingual import MultilingualModel

logger = logging.getLogger("agent-EmergencyHelper")
load_dotenv(".env.local")

# Supabase Edge Function Base URL
EDGE_FUNCTION_BASE = "https://smmwnlhdcrauwnstfasu.supabase.co/functions/v1"
API_KEY = os.getenv("API_KEY", "ParkinsonAtHackatum")


class EmergencyAgent(Agent):
    def __init__(self, incident_metadata: dict) -> None:
        self.incident_id = incident_metadata.get("incident_id")
        self.user_id = incident_metadata.get("user_id")
        self.phone_number = incident_metadata.get("phone_number")
        self.location = incident_metadata.get("location", {})
        self.severity = incident_metadata.get("severity", 0.0)
        self.confidence = incident_metadata.get("confidence", 0.0)

        super().__init__(
            instructions=f"""You are a medical emergency assistant for Parkinson's patients.

# Your Task
The user's smartwatch has detected a possible freeze episode (Severity: {self.severity:.0%}, Confidence: {self.confidence:.0%}).
You are calling the user to verify if they are okay or if there is a real emergency.

# Conversation Flow
1. Greet the user politely and professionally
2. Briefly explain that the smartwatch has detected an anomaly
3. Ask directly: "Is everything alright? Do you need help?"
4. Listen carefully and evaluate the response

# Decision Logic
- **EMERGENCY**: If the user says they fell, need help, are in pain, or respond uncertainly/confused
  → Immediately call the tool `verify_emergency`
  → Say: "I understand. I will immediately notify your emergency contact. Please stay on the phone."

- **FALSE ALARM**: If the user clearly states that everything is fine
  → Call the tool `mark_false_alarm`
  → Say: "I'm glad to hear that! Have a nice day."

# Important Rules
- Be friendly but professional
- Speak clearly in English
- Keep it brief - maximum 2-3 sentences per response
- Don't ask irrelevant questions
- When in doubt → treat it as an EMERGENCY (better safe than sorry)
- Don't use technical jargon or technical details
- Don't mention incident IDs or internal information""",
        )

    async def on_enter(self):
        await self.session.generate_reply(
            instructions="""Greet the user and ask about their wellbeing.
Example: "Good day, this is your automatic emergency assistant. Our smartwatch has detected a possible movement anomaly. Is everything alright with you?"
Keep it short and direct.""",
            allow_interruptions=True,
        )


# Tool: Verify Emergency
async def verify_emergency(
    call_summary: str,
    incident_id: str,
    user_id: str,
    phone_number: str,
) -> str:
    """
    Confirms a real emergency and notifies the emergency contact.
    Call this function when the patient needs help or reports a fall/emergency.

    Args:
        call_summary: Brief summary of the conversation with the patient (1-2 sentences)
        incident_id: The incident ID
        user_id: The user ID
        phone_number: The patient's phone number
    """
    logger.info(f"🚨 EMERGENCY VERIFIED for incident {incident_id}")

    async with aiohttp.ClientSession() as session:
        try:
            async with session.post(
                f"{EDGE_FUNCTION_BASE}/agent-verify-emergency",
                headers={
                    "x-api-key": API_KEY,
                    "Content-Type": "application/json",
                },
                json={
                    "userId": user_id,
                    "incidentId": incident_id,
                    "callSummary": call_summary,
                },
            ) as resp:
                result = await resp.json()
                logger.info(f"Emergency verified response: {result}")

                # Trigger emergency contact call
                async with session.post(
                    f"{EDGE_FUNCTION_BASE}/agent-call-emergency-contact",
                    headers={
                        "x-api-key": API_KEY,
                        "Content-Type": "application/json",
                    },
                    json={
                        "userId": user_id,
                        "incidentId": incident_id,
                        "patientPhone": phone_number,
                    },
                ) as contact_resp:
                    contact_result = await contact_resp.json()
                    logger.info(f"Emergency contact notified: {contact_result}")

                return "Emergency has been confirmed. Emergency contact is being notified."
        except Exception as e:
            logger.error(f"Error verifying emergency: {e}")
            return f"Error confirming emergency: {str(e)}"


# Tool: Mark False Alarm
async def mark_false_alarm(
    call_summary: str,
    incident_id: str,
    user_id: str,
) -> str:
    """
    Marks the incident as a false alarm when the patient confirms everything is fine.
    Only call this function when the patient clearly states they don't need help.

    Args:
        call_summary: Brief summary of why it was a false alarm
        incident_id: The incident ID
        user_id: The user ID
    """
    logger.info(f"✅ FALSE ALARM marked for incident {incident_id}")

    async with aiohttp.ClientSession() as session:
        try:
            async with session.post(
                f"{EDGE_FUNCTION_BASE}/agent-falsify-emergency",
                headers={
                    "x-api-key": API_KEY,
                    "Content-Type": "application/json",
                },
                json={
                    "userId": user_id,
                    "incidentId": incident_id,
                    "callSummary": call_summary,
                },
            ) as resp:
                result = await resp.json()
                logger.info(f"False alarm marked: {result}")
                return "False alarm has been documented. Have a nice day!"
        except Exception as e:
            logger.error(f"Error marking false alarm: {e}")
            return f"Error marking false alarm: {str(e)}"


# Initialize the agent server
server = AgentServer()


def prewarm(proc: JobProcess):
    """Prewarm function to load VAD model before jobs start"""
    proc.userdata["vad"] = silero.VAD.load()


# Set prewarm function
server.setup_fnc = prewarm


# Main entrypoint for the agent
@server.rtc_session(agent_name="emergency-helper-agent")
async def entrypoint(ctx: JobContext):
    """
    Main entrypoint function called when the agent is dispatched to a room.
    This is called for explicit dispatches via AgentDispatchService.
    """
    logger.info(f"🚑 Agent dispatched to room: {ctx.room.name}")
    logger.info(f"📋 Job metadata: {ctx.job.metadata}")

    # Connect to the room
    await ctx.connect()
    logger.info("✅ Agent connected to room")

    # Parse metadata from dispatch
    incident_metadata = {}
    try:
        if ctx.job.metadata:
            incident_metadata = json.loads(ctx.job.metadata)
            logger.info(f"Incident metadata: {incident_metadata}")
    except Exception as e:
        logger.error(f"Failed to parse metadata: {e}")
        incident_metadata = {
            "incident_id": "UNKNOWN",
            "user_id": "UNKNOWN",
            "phone_number": "UNKNOWN",
            "severity": 0.0,
            "confidence": 0.0,
        }

    # Create agent with incident context
    agent = EmergencyAgent(incident_metadata)

    # Create agent session
    session = AgentSession(
        stt=inference.STT(model="assemblyai/universal-streaming", language="en"),
        llm=inference.LLM(model="openai/gpt-4o-mini"),
        tts=inference.TTS(
            model="cartesia/sonic-3",
            voice="9626c31c-bec5-4cca-baa8-f8ba9e84c8bc",
            language="en",
        ),
        turn_detection=MultilingualModel(),
        vad=ctx.proc.userdata["vad"],
        preemptive_generation=True,
    )

    # Register tools with incident context using functools.partial
    session.register_function(
        partial(
            verify_emergency,
            incident_id=incident_metadata.get("incident_id", "UNKNOWN"),
            user_id=incident_metadata.get("user_id", "UNKNOWN"),
            phone_number=incident_metadata.get("phone_number", "UNKNOWN"),
        )
    )

    session.register_function(
        partial(
            mark_false_alarm,
            incident_id=incident_metadata.get("incident_id", "UNKNOWN"),
            user_id=incident_metadata.get("user_id", "UNKNOWN"),
        )
    )

    # Start the session
    await session.start(
        agent=agent,
        room=ctx.room,
        room_options=room_io.RoomOptions(
            audio_input=room_io.AudioInputOptions(
                noise_cancellation=lambda params: noise_cancellation.BVCTelephony()
                    if params.participant.kind == rtc.ParticipantKind.PARTICIPANT_KIND_SIP
                    else noise_cancellation.BVC(),
            ),
        ),
    )


if __name__ == "__main__":
    cli.run_app(server)