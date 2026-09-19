import logging
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

logger = logging.getLogger("mentra.db")

DATABASE_URL = settings.DATABASE_URL

if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
    )
else:
    try:
        test_engine = create_engine(
            DATABASE_URL,
            pool_pre_ping=True,
            connect_args={"connect_timeout": 2},
        )
        with test_engine.connect() as conn:
            pass
        engine = test_engine
    except Exception as e:
        logger.warning(
            "PostgreSQL database not available on %s (%s). Falling back to local SQLite database (mentra.db).",
            DATABASE_URL,
            e,
        )
        from pathlib import Path
        db_path = Path(__file__).resolve().parent.parent.parent / 'mentra.db'
        engine = create_engine(
            f'sqlite:///{db_path}',
            connect_args={'check_same_thread': False},
        )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
