import os
import logging
from flask_appbuilder.security.manager import AUTH_DB

SUPERSET_HOME = os.environ.get("SUPERSET_HOME", "/root/tools/superset")

# Database Configuration
SQLALCHEMY_DATABASE_URI = 'postgresql://postgres:postgres@localhost/superset'

# Increase Row Limit to 1 Million
ROW_LIMIT = 1000000

# Redis Caching Configuration
REDIS_HOST = 'localhost'
REDIS_PORT = 6379
REDIS_CELERY_DB = 0
REDIS_RESULTS_DB = 1

CACHE_CONFIG = {
    'CACHE_TYPE': 'redis',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': REDIS_HOST,
    'CACHE_REDIS_PORT': REDIS_PORT,
    'CACHE_REDIS_DB': REDIS_RESULTS_DB,
}

# Use Redis for Celery as well
class CeleryConfig:
    BROKER_URL = f'redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_CELERY_DB}'
    CELERY_RESULT_BACKEND = f'redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_CELERY_DB}'
    CELERY_ANNOTATIONS = {'tasks.add': {'rate_limit': '10/s'}}

CELERY_CONFIG = CeleryConfig

# Disable CORS
ENABLE_CORS = False

# Logging Configuration

LOG_FORMAT = '%(asctime)s:%(levelname)s:%(name)s:%(message)s'
LOG_LEVEL = logging.DEBUG

# Enable time-based log rotation
LOG_DIR = os.path.join(SUPERSET_HOME, "logs")
FILENAME = os.path.join(LOG_DIR, "superset.log")
ENABLE_TIME_ROTATE = True
TIME_ROTATE_LOG_LEVEL = "INFO"
TIME_ROTATE_LOG_FILE = FILENAME
ROLLOVER = 'midnight'
INTERVAL = 1
BACKUP_COUNT = 5

# Feature Flags (optional, but recommended for better performance)
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
}

# Authentication Configuration (using database auth in this example)
AUTH_TYPE = AUTH_DB

# Set a strong SECRET_KEY for security
SECRET_KEY = 'YOUR_SECURE_SECRET_KEY_HERE'
