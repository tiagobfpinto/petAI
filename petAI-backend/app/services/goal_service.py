from __future__ import annotations

import json
import os
from typing import Any, Sequence
from urllib import error, request
import logging


logger = logging.getLogger(__name__)


class GoalService:
    """Generate cardio goals with LLM plus deterministic fallback."""

    _API_KEY = os.getenv("OPENAI_API_KEY")
    _MODEL = os.getenv("GOAL_SUGGESTION_MODEL", "gpt-4o-mini")
    _ENDPOINT = "https://api.openai.com/v1/chat/completions"

    _BASE_MINUTES = 150
    _RUNNING_SPEED_KMH = 8.0
    _MIN_AGE_FACTOR = 0.7
    _BASE_SCORE = 100
    _SAMPLE_CARDIO_ACTIVITIES = (
        "10 min brisk walk",
        "15 min easy jog",
        "Jump rope: 5 x 1 min rounds",
        "Low-impact HIIT (4 rounds)",
        "Bike ride 20 minutes",
        "Rowing machine 10 minutes steady",
    )

    _ACTIVITY_FACTORS = {
        "never": 0.3,
        "sedentary": 0.3,
        "rarely": 0.5,
        "sometimes": 0.7,
        "often": 0.9,
        "usually": 0.9,
        "always": 1.1,
        "athlete": 1.1,
    }

    @staticmethod
    def _age_factor(age: int | None) -> float:
        if age is None or age <= 0:
            return 1.0
        factor = 1 - (age - 20) * 0.005
        return round(max(GoalService._MIN_AGE_FACTOR, factor), 3)

    @staticmethod
    def _gender_factor(gender: str | None) -> float:
        if not gender:
            return 1.0
        normalized = gender.strip().lower()
        if normalized.startswith("m"):
            return 1.0
        if normalized.startswith("f"):
            return 0.85
        return 0.95

    @classmethod
    def _activity_factor(cls, level: str | None) -> float:
        if not level:
            return cls._ACTIVITY_FACTORS["sometimes"]
        normalized = level.strip().lower()
        return cls._ACTIVITY_FACTORS.get(normalized, cls._ACTIVITY_FACTORS["sometimes"])

    @staticmethod
    def _sessions_for(minutes: float) -> int:
        if minutes <= 120:
            return 3
        if minutes <= 210:
            return 4
        return 5

    @staticmethod
    def _format_km(value: float) -> str:
        if value >= 10:
            return str(int(round(value)))
        return f"{value:.1f}".rstrip("0").rstrip(".")

    @staticmethod
    def _normalize_list(values: Sequence[str] | None) -> list[str]:
        normalized: list[str] = []
        for value in values or []:
            cleaned = (value or "").strip()
            if cleaned:
                normalized.append(cleaned)
        return normalized

    @classmethod
    def _llm_activity_prompt(
        cls,
        *,
        age: int | None,
        gender: str | None,
        activity_level: str | None,
        last_activities: list[str],
        refused_activities: list[str],
    ) -> str:
        last_text = ", ".join(last_activities) if last_activities else "None"
        refused_text = ", ".join(refused_activities) if refused_activities else "None"
        return (
            "Suggest a cardio activity for me. "
            "Don't repeat the last activities and dont suggest refused activities. "
            "Answer simply with the activity, no explaining, no anything. "
            "Try to increase the difficulty according to the last activities. "
            "Without any huge increases. "
            f"Age: {age or 'Unknown'} "
            f"Gender: {gender or 'Unknown'} "
            f"Level: {activity_level or 'Unknown'} "
            f"Last activities: {last_text} "
            f"Refused activities: {refused_text}"
        )

    @classmethod
    def _weekly_goal_prompt(
        cls,
        *,
        chosen_activity: str,
        age: int | None,
        gender: str | None,
        last_goal_value: float | None,
        last_goal_unit: str | None,
    ) -> str:
        last_goal = (
            f"{last_goal_value} {last_goal_unit}" if last_goal_value is not None else "None"
        )
        return (
            "Suggest a weekly goal for the chosen activity. "
            "Make it slightly more challenging than the last weekly goal (5-20% increase), "
            "but keep it safe for the person's profile. "
            "Always answer ONLY with a compact JSON object like "
            '{"activity":"jump rope","amount":12,"unit":"km"} '
            "or with minutes if distance is not ideal. "
            "Do not include any extra text or comments.\n"
            f"Activity: {chosen_activity or 'running'}\n"
            f"Age: {age or 'Unknown'}\n"
            f"Gender: {gender or 'Unknown'}\n"
            #f"Last weekly goal: {last_goal}\n"
            "Rules: keep amount > 0, avoid massive jumps, keep unit consistent when possible."
            "Possible units: km, minutes, hours..."
            
        )

    @classmethod
    def _call_llm(cls, prompt: str, *, max_tokens: int = 48, first_line_only: bool = True) -> str | None:
        api_key = cls._API_KEY or os.getenv("OPENAI_API_KEY")
        if not api_key:
            return None
        payload = {
            "model": cls._MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": 0.7,
        }
        data = json.dumps(payload).encode("utf-8")
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        req = request.Request(cls._ENDPOINT, data=data, headers=headers, method="POST")
        try:
            with request.urlopen(req, timeout=20) as resp:
                body = resp.read()
        except (error.HTTPError, error.URLError, TimeoutError):
            return None

        try:
            parsed = json.loads(body.decode("utf-8"))
        except json.JSONDecodeError:
            return None

        choice = (parsed.get("choices") or [{}])[0]
        message = choice.get("message") or {}
        content = (message.get("content") or "").strip()
        if not content:
            return None
        return content.splitlines()[0].strip() if first_line_only else content

    @classmethod
    def _call_llm_json(cls, prompt: str) -> dict[str, Any] | None:
        content = cls._call_llm(prompt, max_tokens=120, first_line_only=False)
        if not content:
            return None
        text = content.strip()
        if "```" in text:
            # remove code fences to keep JSON parsing simple
            parts = []
            for line in text.splitlines():
                if line.startswith("```"):
                    continue
                parts.append(line)
            text = "\n".join(parts).strip()
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            return None
        if not isinstance(parsed, dict):
            return None
        return parsed

    @classmethod
    def _fallback_goal(
        cls,
        *,
        age: int | None,
        gender: str | None,
        activity_level: str | None,
        running_speed_kmh: float | None = None,
    ) -> dict[str, Any]:
        age_factor = cls._age_factor(age)
        gender_factor = cls._gender_factor(gender)
        activity_factor = cls._activity_factor(activity_level)
        speed = running_speed_kmh or cls._RUNNING_SPEED_KMH

        weekly_minutes = round(cls._BASE_MINUTES * age_factor * gender_factor * activity_factor)
        weekly_km = round((weekly_minutes / 60.0) * speed, 1)
        cardio_score = round(cls._BASE_SCORE * age_factor * gender_factor * activity_factor)

        sessions = cls._sessions_for(weekly_minutes)
        per_session = max(15, int(round(weekly_minutes / sessions)))
        text = (
            f"Corre cerca de {cls._format_km(weekly_km)} km esta semana "
            f"({sessions} sessoes de {per_session}-{per_session + 10} min)."
        )

        return {
            "weekly_goal_km": weekly_km,
            "weekly_goal_minutes": int(weekly_minutes),
            "suggested_text": text,
            "cardio_score": int(cardio_score),
            "factors": {
                "age_factor": age_factor,
                "gender_factor": gender_factor,
                "activity_factor": activity_factor,
                "running_speed_kmh": float(speed),
            },
        }

    @classmethod
    def suggest_cardio_activity(
        cls,
        *,
        age: int | None,
        gender: str | None,
        activity_level: str | None,
        last_activities: Sequence[str] | None = None,
        refused_activities: Sequence[str] | None = None,
    ) -> dict[str, Any]:
        last_normalized = cls._normalize_list(last_activities)
        refused_normalized = cls._normalize_list(refused_activities)
        prompt = cls._llm_activity_prompt(
            age=age,
            gender=gender,
            activity_level=activity_level,
            last_activities=last_normalized,
            refused_activities=refused_normalized,
        )

        llm_activity = cls._call_llm(prompt)

        if llm_activity:
            return {
                "suggested_activity": llm_activity,
                "prompt": prompt,
                "model": cls._MODEL,
                "source": "gpt",
                "inputs": {
                    "age": age,
                    "gender": gender,
                    "activity_level": activity_level,
                    "last_activities": last_normalized,
                    "refused_activities": refused_normalized,
                },
            }

        # Deterministic, simple fallback that avoids recent or refused picks.
        for idea in cls._SAMPLE_CARDIO_ACTIVITIES:
            idea_lower = idea.lower()
            if idea_lower in (activity.lower() for activity in last_normalized):
                continue
            if idea_lower in (activity.lower() for activity in refused_normalized):
                continue
            return {
                "suggested_activity": idea,
                "prompt": prompt,
                "model": None,
                "source": "fallback",
                "inputs": {
                    "age": age,
                    "gender": gender,
                    "activity_level": activity_level,
                    "last_activities": last_normalized,
                    "refused_activities": refused_normalized,
                },
                "fallback": {"suggested_text": idea},
            }

        fallback = cls._fallback_goal(
            age=age,
            gender=gender,
            activity_level=activity_level,
        )
        return {
            "suggested_activity": fallback["suggested_text"],
            "prompt": prompt,
            "model": None,
            "source": "fallback",
            "inputs": {
                "age": age,
                "gender": gender,
                "activity_level": activity_level,
                "last_activities": last_normalized,
                "refused_activities": refused_normalized,
            },
            "fallback": fallback,
        }

    @classmethod
    def suggest_weekly_goal(
        cls,
        *,
        age: int | None,
        gender: str | None,
        chosen_activity: str,
        last_goal_value: float | None = None,
        last_goal_unit: str | None = None,
    ) -> dict[str, Any]:
        prompt = cls._weekly_goal_prompt(
            chosen_activity=chosen_activity,
            age=age,
            gender=gender,
            last_goal_value=last_goal_value,
            last_goal_unit=last_goal_unit,
        )
        logger.info("Weekly goal prompt: %s", prompt)
        print(f"[weekly_goal_prompt] {prompt}")

        structured = cls._call_llm_json(prompt)
        if structured:
            amount_raw = structured.get("amount") or structured.get("value")
            unit = (structured.get("unit") or last_goal_unit or "km").strip() or "km"
            try:
                amount = float(amount_raw)
            except (TypeError, ValueError):
                amount = None
            if amount is not None and amount > 0:
                return {
                    "activity": (structured.get("activity") or chosen_activity).strip()
                    or chosen_activity,
                    "amount": amount,
                    "unit": unit,
                    "prompt": prompt,
                    "model": cls._MODEL,
                    "source": "gpt",
                    "inputs": {
                        "age": age,
                        "gender": gender,
                        "last_goal_value": last_goal_value,
                        "last_goal_unit": last_goal_unit,
                        "activity": chosen_activity,
                    },
                }

        # Fallback progression: gently nudge the target upward.
        unit = last_goal_unit or "km"
        if last_goal_value and last_goal_value > 0:
            increment = max(1.0, last_goal_value * 0.08)
            amount = round(last_goal_value + increment, 1)
        else:
            base = cls._fallback_goal(age=age, gender=gender, activity_level=None)
            amount = float(base.get("weekly_goal_km", 6.0))
            unit = "km"

        return {
            "activity": chosen_activity,
            "amount": amount,
            "unit": unit,
            "prompt": prompt,
            "model": None,
            "source": "fallback",
            "inputs": {
                "age": age,
                "gender": gender,
                "last_goal_value": last_goal_value,
                "last_goal_unit": last_goal_unit,
                "activity": chosen_activity,
            },
            "fallback": {
                "amount": amount,
                "unit": unit,
            },
        }
