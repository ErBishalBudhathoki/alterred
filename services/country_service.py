from typing import Dict, Any, Optional
from functools import lru_cache

# Mock data for demonstration. In a real app, this might come from a DB or external API.
COUNTRY_DATA = {
    "US": {
        "name": "United States",
        "currency": "USD",
        "tax_info": "Federal income tax + State taxes. Tax year is calendar year. Filing deadline usually April 15.",
        "regulations": "GDPR does not apply, but CCPA/CPRA may apply in California.",
        "work_culture": "Standard 40-hour work week. At-will employment common."
    },
    "GB": {
        "name": "United Kingdom",
        "currency": "GBP",
        "tax_info": "Tax year runs from April 6 to April 5. HMRC is the tax authority. VAT is 20%.",
        "regulations": "GDPR applies (UK GDPR).",
        "work_culture": "Standard 37.5-40 hour work week. Statutory leave minimum 28 days."
    },
    "CA": {
        "name": "Canada",
        "currency": "CAD",
        "tax_info": "Federal + Provincial taxes. Tax year is calendar year. Filing deadline April 30.",
        "regulations": "PIPEDA applies for privacy.",
        "work_culture": "Standard 40-hour work week."
    },
    "IN": {
        "name": "India",
        "currency": "INR",
        "tax_info": "Financial year April 1 to March 31. GST applies. Income tax slabs vary by age/income.",
        "regulations": "DPDP Act applies.",
        "work_culture": "Standard 48-hour work week (max)."
    },
    "AU": {
        "name": "Australia",
        "currency": "AUD",
        "tax_info": "Financial year July 1 to June 30. ATO is tax authority. GST is 10%.",
        "regulations": "Privacy Act 1988.",
        "work_culture": "Standard 38-hour work week."
    },
    "DE": {
        "name": "Germany",
        "currency": "EUR",
        "tax_info": "Tax year is calendar year. Progressive tax rate. VAT (Mehrwertsteuer) is 19%.",
        "regulations": "GDPR applies.",
        "work_culture": "Standard 40-hour work week, often less. Strong worker protection."
    },
    "FR": {
        "name": "France",
        "currency": "EUR",
        "tax_info": "Tax year is calendar year. Withholding tax implemented. VAT (TVA) is 20%.",
        "regulations": "GDPR applies.",
        "work_culture": "Legal 35-hour work week. Right to disconnect."
    },
    "JP": {
        "name": "Japan",
        "currency": "JPY",
        "tax_info": "Tax year is calendar year. Consumption tax is 10%.",
        "regulations": "APPI applies.",
        "work_culture": "Standard 40-hour work week. Overtime culture varies."
    },
    "BR": {
        "name": "Brazil",
        "currency": "BRL",
        "tax_info": "Tax year is calendar year. Complex tax system (ICMS, ISS, IPI).",
        "regulations": "LGPD applies.",
        "work_culture": "Standard 44-hour work week."
    },
    "CN": {
        "name": "China",
        "currency": "CNY",
        "tax_info": "Tax year is calendar year. VAT varies. Individual Income Tax (IIT).",
        "regulations": "PIPL applies.",
        "work_culture": "Standard 40-hour work week. 996 in some tech sectors."
    },
    # Add generic fallback or more countries as needed
}

import re

@lru_cache(maxsize=32)
def get_country_info(country_code: str) -> Dict[str, Any]:
    """
    Retrieve information for a specific country.
    Uses LRU cache to minimize overhead for frequent lookups.
    
    Args:
        country_code (str): ISO 3166-1 alpha-2 country code (e.g., 'US', 'GB').
        
    Returns:
        Dict[str, Any]: Country data or empty dict if not found.
    """
    if not country_code:
        return {}
    
    code = country_code.upper()
    return COUNTRY_DATA.get(code, {
        "name": "Unknown",
        "note": f"No specific data for country code {code}"
    })

def is_tax_relevant(text: str) -> bool:
    """
    Determine if a query is likely related to tax or country-specific regulations.
    
    Args:
        text (str): The user query.
        
    Returns:
        bool: True if relevant, False otherwise.
    """
    keywords = [
        r"\btax\b", r"\btaxes\b", r"\bvat\b", r"\bgst\b", r"\bsalary\b", r"\bincome\b", 
        r"\bdeduction\b", r"\bfiling\b", r"\bdeadline\b", r"\baudit\b", r"\binvoice\b", 
        r"\blegal\b", r"\bcompliance\b", r"\bholiday\b", r"\bleave\b", r"\bvacation\b", 
        r"work hour"
    ]
    text_lower = text.lower()
    
    for pattern in keywords:
        if re.search(pattern, text_lower):
            return True
    return False
