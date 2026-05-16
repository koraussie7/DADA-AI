import httpx
import os

async def call_hermes_for_review(code_or_content: str):
    """OpenCode에서 온 코드를 Hermes가 검토"""
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                "http://localhost:3000/ai/code-assist",
                json={
                    "prompt": f"""
                    다음 코드를 검토하고 개선점을 알려줘.
                    코드:
                    {code_or_content}
                    """,
                    "mode": "review",
                    "use_verification": True
                }
            )
            if response.status_code == 200:
                data = response.json()
                return data.get("result", "검토 완료")
            else:
                return "Hermes 검토 실패"
    except Exception as e:
        return f"Error: {str(e)}"
