FROM python:3.12-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir \
    fastmcp>=2.0.0 \
    neo4j>=5.26.0 \
    pydantic>=2.10.1 \
    starlette>=0.28.0

# Clone the mcp-neo4j repo
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/neo4j-contrib/mcp-neo4j.git /mcp-repo

# Copy the mcp-neo4j-memory server
WORKDIR /app
RUN cp -r /mcp-repo/servers/mcp-neo4j-memory/src/mcp_neo4j_memory /app/ && \
    cp /mcp-repo/servers/mcp-neo4j-memory/README.md /app/

# Clean up git
RUN rm -rf /mcp-repo

# Set Python path
ENV PYTHONPATH=/app:$PYTHONPATH

# Expose HTTP port for MCP server
EXPOSE 8000

# Run the MCP server via the installed module's main entry point
CMD ["python", "-c", "from mcp_neo4j_memory import main; main()"]
