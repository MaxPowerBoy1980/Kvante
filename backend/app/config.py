from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    ai_provider: str = "ollama"  # "gemini", "claude", or "ollama"
    anthropic_api_key: str = ""
    google_api_key: str = ""
    db_path: str = "kvante.db"
    host: str = "0.0.0.0"
    port: int = 8000
    confidence_threshold: float = 0.6
    claude_model: str = "claude-sonnet-4-20250514"
    gemini_model: str = "gemini-2.0-flash"
    ollama_url: str = "http://localhost:11434"
    ollama_text_model: str = "llama3.2-vision:11b"
    ollama_vision_model: str = "llama3.2-vision:11b"
    upload_dir: str = "uploads"
    max_upload_size: int = 10 * 1024 * 1024  # 10 MB
    prompts_dir: Path = Path(__file__).parent / "prompts"
    log_level: str = "INFO"  # INFO or DEBUG
    log_dir: str = "/Users/oleserver/Library/Logs/Kvante"  # absolute path; ~ not expanded

    model_config = {"env_prefix": "KVANTE_", "env_file": ".env"}


settings = Settings()
