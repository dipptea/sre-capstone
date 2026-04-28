# Runbook

Operational reference. Grown as the system grows. Written in own words — copy-pasted commands without context don't help in an incident.

> **Looking for "what's currently running and what it costs"?** That lives in [`INVENTORY.md`](INVENTORY.md), not here. This file is *how to operate*; INVENTORY is *what is provisioned*.

Sections to fill in as we go:

## Deploy from zero

_(Phase 1 — to be written after the first cluster is up. Should describe how a fresh engineer would bring the system up from an empty AWS account, in your own words.)_

## Common operations

_(kubectl shortcuts, Datadog dashboard links, AWS console deep-links)_

## Incident playbooks

_(one section per failure mode, populated during failure-injection phases)_

- [ ] Pod crashloop
- [ ] Node drained / unschedulable
- [ ] Image pull failure
- [ ] DB latency spike
- [ ] Downstream service slow
- [ ] WAF blocking legitimate traffic
- [ ] Datadog agent not reporting

## Useful queries

_(PromQL, Datadog APM filters, log queries — populated as discovered)_
