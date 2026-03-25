FROM python:3.10-slim

# Security: Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# OCR removed - payment screenshots verified manually by Xerox Manager
# (Removed tesseract-ocr installation to reduce image size)

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Security: Create non-root user
RUN useradd --create-home --shell /bin/bash appuser

# Create uploads directory with proper permissions
RUN mkdir -p uploads && chown -R appuser:appuser /app

# Copy application code
COPY --chown=appuser:appuser . .

# Security: Switch to non-root user
USER appuser

# Expose the default Hugging Face Spaces port
EXPOSE 7860

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:7860/api/health')" || exit 1

# Run the application
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "7860"]
