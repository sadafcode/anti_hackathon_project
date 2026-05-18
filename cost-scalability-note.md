# Cost and Scalability Analysis — KhidmatBot

## Current Architecture (Hackathon Scale)

### Tech Stack Costs
| Service | Usage | Cost |
|---------|-------|------|
| OpenAI GPT-4o-mini | Agent reasoning (Discovery, Pricing, Booking, Dispute) | $0.15/1M input tokens, $0.60/1M output tokens |
| Gemini Flash | NLU parsing | Free tier: 15 req/min; Paid: $0.075/1M tokens |
| Firebase Firestore | Provider data, bookings, sessions | Free tier: 50K reads/day, 20K writes/day |
| Firebase Storage | Provider photos | Free tier: 5GB |
| Firebase FCM | Push notifications | Free |
| Google Maps APIs | Distance, directions | $200 credit/month (covers ~40K distance calculations) |
| Express.js server | API hosting | Self-hosted or free tier (Render/Railway) |

---

## Per-Booking Cost Breakdown

A single complete booking flow (chat → NLU → discovery → pricing → booking) uses:

| Agent | Model | Approx Tokens | Cost |
|-------|-------|---------------|------|
| Orchestrator (conversation turns, avg 3) | GPT-4o-mini | ~1,500 tokens | $0.00023 |
| NLU parsing | Gemini Flash | ~800 tokens | $0.00006 |
| Discovery + Ranking | GPT-4o-mini | ~1,200 tokens | $0.00018 |
| Pricing generation | GPT-4o-mini | ~800 tokens | $0.00012 |
| Booking confirmation | GPT-4o-mini | ~600 tokens | $0.00009 |
| **Total per booking** | | **~4,900 tokens** | **~$0.0007** |

**Additional per-booking costs:**
- Firestore: 5–8 reads + 2–3 writes ≈ negligible (free tier covers ~10K bookings/day)
- Maps API: 1 distance calculation ≈ $0.005
- FCM notification: free

**Total cost per completed booking: ~$0.006 (less than 1 rupee)**

---

## Scale Projections

### 1,000 Bookings/Day (City-level pilot)
| Item | Cost/Day | Cost/Month |
|------|----------|------------|
| AI tokens | $0.70 | $21 |
| Maps API | $5.00 | $150 |
| Firebase (paid tier) | $1.00 | $30 |
| Server (Render/Railway) | $0.50 | $15 |
| **Total** | **$7.20** | **$216** |

### 10,000 Bookings/Day (Multi-city Pakistan)
| Item | Cost/Day | Cost/Month |
|------|----------|------------|
| AI tokens | $7.00 | $210 |
| Maps API | $50.00 | $1,500 |
| Firebase | $8.00 | $240 |
| Server (2x instances) | $5.00 | $150 |
| **Total** | **$70** | **$2,100** |

### 100,000 Bookings/Day (National scale)
| Item | Cost/Day | Cost/Month |
|------|----------|------------|
| AI tokens | $70 | $2,100 |
| Maps API (with caching) | $200 | $6,000 |
| Firebase / Cloud Firestore | $60 | $1,800 |
| Cloud Run (auto-scaling) | $40 | $1,200 |
| **Total** | **$370** | **$11,100** |

At 100K bookings/day with avg platform fee of Rs.150/booking:
- **Revenue: Rs.15,000,000/day (~$54,000/day)**
- **AI + infra cost: $370/day**
- **Cost ratio: 0.7% of revenue**

---

## Latency Analysis

### Current (single-threaded, sequential agents)
| Stage | Time |
|-------|------|
| NLU parsing (Gemini Flash) | ~1.2s |
| Provider discovery (GPT-4o-mini + Firestore) | ~1.5s |
| Pricing calculation | ~1.3s |
| Booking creation (Firestore write) | ~0.5s |
| FCM notification dispatch | ~0.3s |
| **Total end-to-end** | **~4.8 seconds** |

### Optimized (parallel where possible)
- Discovery + NLU validation can run in parallel after intent extracted
- Pricing can start as soon as top provider is selected (before full ranking completes)
- FCM notification can be async (doesn't block booking confirmation)

**Optimized total: ~2.5–3.0 seconds**

---

## Scaling Architecture

### Current (Hackathon)
```
Single Express.js server → all agents sequential → Firebase
```

### 10x Scale (Cloud Run)
```
Cloud Run (auto-scale 1–10 instances)
→ Agent calls run concurrently per request
→ Redis cache for provider data (5 min TTL)
→ Firestore with connection pooling
```

### 100x Scale (Microservices)
```
API Gateway (Cloud API Gateway)
→ NLU Service (dedicated Cloud Run instance)
→ Discovery Service (with Redis provider cache)
→ Pricing Service (stateless, highly cacheable)
→ Booking Service (with distributed lock for conflict prevention)
→ Notification Service (async, Cloud Tasks queue)
→ Dispute Service (event-driven)
Shared: Cloud Firestore (regional), Firebase Storage, BigQuery (analytics)
```

### Cost Optimization Strategies

1. **Cache provider rankings** — same area + service type returns same ranked list (5 min cache → 80% cache hit rate estimated)
2. **Batch FCM notifications** — group notifications sent every 30s instead of instantly for non-urgent cases
3. **Gemini Flash over GPT** for NLU — 10x cheaper, adequate for extraction tasks
4. **GPT-4o-mini over GPT-4o** — 15x cheaper, sufficient for structured agent reasoning
5. **Maps API caching** — cache distance calculations between provider coordinates and sector centers (Islamabad has ~50 sectors → limited unique pairs)
6. **Firestore reads reduction** — cache provider list in memory with TTL, only invalidate on new registration or profile update

---

## Infrastructure for Production

| Component | Hackathon | Production (10K/day) |
|-----------|-----------|----------------------|
| Server | Local / Render free | Cloud Run (auto-scale) |
| Database | Firebase free tier | Firestore paid (regional) |
| Cache | None | Redis (Cloud Memorystore) |
| Notifications | Direct FCM | Cloud Tasks queue → FCM |
| Monitoring | Console.log | Cloud Logging + Error Reporting |
| CDN | None | Firebase Hosting (for photos) |
| CI/CD | Manual | GitHub Actions → Cloud Run |

---

## Summary

KhidmatBot is cost-effective at every scale:
- **< $0.01 per booking** (AI + infra combined)
- **< 5 seconds** end-to-end latency (current), < 3 seconds (optimized)
- Architecture scales from hackathon prototype to national deployment without fundamental redesign
- Highest cost driver at scale is Maps API — addressable with sector-level caching
