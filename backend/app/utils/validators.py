"""Shared validation for person names and Iraqi mobile numbers."""

from __future__ import annotations

import re

_NAME_RE = re.compile(r"^[\sA-Za-z\u0600-\u06FF]+$")
_ARABIC_DIGITS_RE = re.compile(r"[\u0660-\u0669\u06F0-\u06F9]")
_PHONE_RE = re.compile(r"^07\d{9}$")


def validate_person_name(value: str) -> str:
    cleaned = value.strip()
    if len(cleaned) < 2:
        raise ValueError("الاسم يجب أن يكون حرفين على الأقل")
    if any(ch.isdigit() for ch in cleaned) or _ARABIC_DIGITS_RE.search(cleaned):
        raise ValueError("الاسم يجب أن يحتوي على حروف فقط")
    if not _NAME_RE.fullmatch(cleaned):
        raise ValueError("الاسم يجب أن يحتوي على حروف فقط")
    return cleaned


def validate_optional_person_name(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    if not cleaned:
        return None
    return validate_person_name(cleaned)


def validate_iraq_phone(value: str) -> str:
    cleaned = re.sub(r"[\s\-]", "", value.strip())
    if not _PHONE_RE.fullmatch(cleaned):
        raise ValueError("رقم الهاتف يجب أن يكون 11 رقماً ويبدأ بـ 07")
    return cleaned


def validate_optional_iraq_phone(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    if not cleaned:
        return None
    return validate_iraq_phone(cleaned)
