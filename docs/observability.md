# Observability & Evaluation

## Metrics
- Task completion rate and time estimation accuracy
- Decision resolution time
- Hyperfocus interruptions
- Agent latency

## Storage
- Firestore: `users/{user}/metrics/{YYYY-MM-DD}/events`

## CLI
- `/metrics overview` prints daily aggregates

## Testing Procedures
- Simulate completion and decisions; compute overview; verify fields

## Known Limitations
- Aggregations are basic averages; expand with dashboards and time windows in future work