# Neo4j + MCP Server Integration

This integration adds a Neo4j graph database and MCP (Model Context Protocol) server to the hubs-compose stack.

## Overview

- **Neo4j**: Graph database running on ports 7474 (HTTP) and 7687 (Bolt).
- **MCP Neo4j Memory**: MCP server providing graph knowledge base tools, running on port 8000.

## Quick Start

### 1. Start the services

```bash
cd hubs-compose
docker compose up -d neo4j mcp-neo4j-memory
```

### 2. Verify Neo4j is running

```bash
# Check Neo4j browser
open http://localhost:7474

# Login with:
# Username: neo4j
# Password: neo4jpassword
```

### 3. Verify MCP server is running

```bash
# Test MCP endpoint
curl http://localhost:8000/mcp/

# Should return MCP protocol info
```

## Configuration

### Neo4j Credentials

- **Username**: `neo4j`
- **Password**: `neo4jpassword` (change in production)
- **Database**: `neo4j` (default)

Update in `docker-compose.yml`:
```yaml
neo4j:
  environment:
    NEO4J_AUTH: neo4j/YOUR_SECURE_PASSWORD
```

### MCP Server Environment Variables

The MCP server (in `docker-compose.yml`) uses:
- `NEO4J_URI`: Connection URL (bolt://neo4j:7687)
- `NEO4J_TRANSPORT`: HTTP mode for remote access
- `NEO4J_MCP_SERVER_HOST`: Binding address (0.0.0.0 for external access)
- `NEO4J_MCP_SERVER_PORT`: HTTP port (8000)

## Available MCP Tools

Once running, the MCP server exposes these tools via HTTP:

### Query Tools
- `read_graph` - Read entire knowledge graph
- `search_nodes` - Search nodes by query
- `find_nodes` - Find nodes by names

### Entity Management
- `create_entities` - Create entities (nodes)
- `delete_entities` - Remove entities
- `add_observations` - Add observations to entities

### Relationship Management
- `create_relations` - Create relationships between entities
- `delete_relations` - Remove relationships

### Observation Management
- `delete_observations` - Remove observations from entities

## Example: Create Entities and Relations

Using curl to call the MCP server:

```bash
# Create entities via HTTP POST to /mcp/
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "create_entities",
      "arguments": {
        "entities": [
          { "name": "Tobias", "type": "person", "observations": ["developer", "lives in Germany"] },
          { "name": "GraphWiz", "type": "company", "observations": ["AI & XR innovation"] }
        ]
      }
    }
  }'
```

## Data Persistence

Neo4j data is stored in Docker volumes:
- `neo4j_data:/var/lib/neo4j/data` - Graph database files
- `neo4j_logs:/var/lib/neo4j/logs` - Log files

Data persists across container restarts.

## Stopping Services

```bash
# Stop Neo4j and MCP server
docker compose down

# To also remove volumes (WARNING: deletes data):
docker compose down -v
```

## Troubleshooting

### MCP server cannot connect to Neo4j

Check logs:
```bash
docker logs mcp-neo4j-memory
```

Ensure Neo4j is running and accepting connections:
```bash
docker logs neo4j
```

### Port already in use

If ports 7474, 7687, or 8000 are in use, update `docker-compose.yml`:
```yaml
neo4j:
  ports:
    - "7475:7474"    # Change host port
    - "7688:7687"
mcp-neo4j-memory:
  ports:
    - "8001:8000"    # Change MCP port
```

### Neo4j initialization slow

First startup creates indices and applies migrations. Wait for logs to show:
```
Started database
```

## References

- [Neo4j Docker Hub](https://hub.docker.com/_/neo4j)
- [MCP Neo4j Server Repository](https://github.com/neo4j-contrib/mcp-neo4j)
- [Neo4j Cypher Documentation](https://neo4j.com/docs/cypher-manual/)

