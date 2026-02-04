import logging
import sys

# ASCII colors for console
RESET_COLOR = "\033[0m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
CYAN = "\033[36m"
WHITE = "\033[37m"

class ColoredFormatter(logging.Formatter):
    """Custom formatter to add colors to log levels for better readability."""
    
    FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    
    FORMATS = {
        logging.DEBUG: WHITE + FORMAT + RESET_COLOR,
        logging.INFO: GREEN + FORMAT + RESET_COLOR,
        logging.WARNING: YELLOW + FORMAT + RESET_COLOR,
        logging.ERROR: RED + FORMAT + RESET_COLOR,
        logging.CRITICAL: RED + "\033[1m" + FORMAT + RESET_COLOR,  # Bold Red
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno, self.FORMAT)
        formatter = logging.Formatter(log_fmt, datefmt="%Y-%m-%d %H:%M:%S")
        return formatter.format(record)

def setup_logging(level: int = logging.INFO):
    """
    Sets up the global logging configuration with colored output.
    should be called once at application startup.
    """
    # Get root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)

    # Clear existing handlers to prevent duplicate logs (common with uvicorn/fastapi)
    if root_logger.hasHandlers():
        root_logger.handlers.clear()

    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    
    # Apply custom colored formatter
    console_handler.setFormatter(ColoredFormatter())
    
    # Add handler to root logger
    root_logger.addHandler(console_handler)
    
    # Optional: Adjust third-party loggers if they are too noisy
    # logging.getLogger("uvicorn.access").setLevel(logging.WARNING)

    return root_logger
