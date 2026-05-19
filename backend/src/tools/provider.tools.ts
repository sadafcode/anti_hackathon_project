import { tool } from '@openai/agents';
import { z } from 'zod';
import fs from 'fs';
import path from 'path';

const DATA_PATH = path.resolve(__dirname, '../../data/providers.json');

function readProviders(): any[] {
  try {
    const raw = fs.readFileSync(DATA_PATH, 'utf-8').replace(/^﻿/, '');
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

function writeProviders(providers: any[]): void {
  fs.writeFileSync(DATA_PATH, JSON.stringify(providers, null, 2));
}

const CITY_AREAS: Record<string, string[]> = {
  islamabad: ['f-6','f-7','f-8','f-10','f-11','g-6','g-7','g-8','g-9','g-10','g-11','g-13','i-8','i-9','i-10','e-7','e-11','dha islamabad','bahria town islamabad','pwd','gulberg islamabad'],
  rawalpindi: ['satellite town rawalpindi','chaklala','cantt rawalpindi','bahria town rawalpindi','dha rawalpindi','saddar rawalpindi'],
  lahore: ['gulberg','dha lahore phase 1','dha lahore phase 5','model town','johar town','bahria town lahore','garden town','iqbal town','shadman'],
  karachi: ['dha karachi','clifton','gulshan-e-iqbal','north nazimabad','pechs','bahria town karachi'],
  peshawar: ['hayatabad','university town','cantt peshawar'],
  quetta: ['satellite town quetta','cantt quetta','jinnah town'],
};

const NEIGHBORS: Record<string, string[]> = {
  'g-11': ['g-13','g-10'],
  'g-13': ['g-11','i-8','g-10'],
  'g-10': ['g-11','g-13'],
  'f-10': ['f-8'],
  'f-8':  ['f-10','f-7'],
  'f-7':  ['f-8'],
  'i-8':  ['g-13'],
};

function resolveCity(area: string): string | null {
  const a = area.toLowerCase().trim();
  for (const [city, areas] of Object.entries(CITY_AREAS)) {
    if (city === a || areas.includes(a)) return city;
    if (a.includes(city)) return city;
    if (areas.some(known => a.includes(known) || known.includes(a))) return city;
  }
  return null;
}

function areasMatch(providerArea: string, requestedArea: string): boolean {
  const pa = providerArea.toLowerCase().trim();
  const ra = requestedArea.toLowerCase().trim();
  if (pa === ra) return true;
  if (pa.includes(ra) || ra.includes(pa)) return true;
  const pc = resolveCity(pa);
  const rc = resolveCity(ra);
  if (pc && rc && pc === rc) return true;
  if ((NEIGHBORS[ra] || []).includes(pa)) return true;

  // Word-level fuzzy match — handles typos like "shafaisal" matching "shah faisal"
  // A significant word from either side appears as substring in a word from the other side.
  const stopWords = new Set(['colony','town','sector','block','area','phase','road','street','village','mohalla','market','chowk','islamabad','lahore','karachi','rawalpindi','peshawar','quetta','faisalabad','multan','gujranwala','sialkot','hyderabad','abbottabad']);
  const sigWords = (s: string) => s.split(/\s+/).filter(w => w.length >= 4 && !stopWords.has(w));
  const qWords = sigWords(ra);
  const pWords = sigWords(pa);
  if (qWords.length > 0 && pWords.length > 0) {
    // Don't fuzzy-match across known different cities (e.g. Bahria Town Islamabad ≠ Bahria Town Rawalpindi)
    if (pc && rc && pc !== rc) return false;
    const match = qWords.some(qw => pWords.some(pw => qw.includes(pw) || pw.includes(qw)));
    if (match) return true;
  }

  return false;
}

function haversineDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;
  return Number(distance.toFixed(2));
}

export const searchProviders = tool({
  name: 'search_providers',
  description: 'Search providers from the database filtered by service type and area. Returns all matching available providers with their full profiles.',
  parameters: z.object({
    service_type: z.string().describe('Service type e.g. ac_repair, plumber, electrician'),
    area: z.string().describe('Customer area/sector e.g. G-11, F-10, Gulberg'),
    urgency: z.string().nullable().describe('low, medium, high, emergency — or null if not specified'),
    budget_sensitive: z.boolean().nullable(),
    job_complexity: z.string().nullable().describe('basic, intermediate, complex — or null if not specified'),
    customer_lat: z.number().nullable().optional().describe('Customer GPS latitude'),
    customer_lng: z.number().nullable().optional().describe('Customer GPS longitude'),
  }),
  execute: async ({ service_type, area, urgency, budget_sensitive, job_complexity, customer_lat, customer_lng }) => {
    const providers = readProviders();

    const byService = providers.filter((p: any) =>
      (p.service_types || []).some((s: string) => s.toLowerCase() === service_type.toLowerCase())
    );

    if (byService.length === 0) {
      return { found: 0, providers: [], message: `No ${service_type} providers registered on platform.` };
    }

    const hasCoords = customer_lat !== null && customer_lat !== undefined && customer_lng !== null && customer_lng !== undefined;
    
    let available: any[] = [];
    let nearbyCount = 0;
    let radiusUsed: string | number | null = null;

    const isAvailable = (p: any) =>
      (p.capacity_today || 0) > 0 &&
      !(p.risk_score === 'high' && (p.strikes || 0) >= 2);

    if (hasCoords) {
      const providersWithDistance = byService.map((p: any) => {
        const lat2 = p.coordinates?.lat;
        const lng2 = p.coordinates?.lng;
        const dist = (lat2 !== undefined && lng2 !== undefined)
          ? haversineDistance(customer_lat, customer_lng, lat2, lng2)
          : null;
        return { ...p, distance_km: dist };
      });

      const radii = [2, 5, 10, 20];
      let selectedRadius: number | null = null;

      for (const r of radii) {
        const inRadius = providersWithDistance.filter((p: any) => p.distance_km !== null && p.distance_km <= r);
        const availInRadius = inRadius.filter(isAvailable);
        if (availInRadius.length > 0) {
          selectedRadius = r;
          available = availInRadius;
          nearbyCount = inRadius.length;
          break;
        }
      }

      // Always include area-name matched providers (e.g. providers with no GPS coordinates
      // but registered in the requested area). Merge without duplicates.
      const areaMatched = providersWithDistance.filter((p: any) =>
        areasMatch(p.area, area) && isAvailable(p)
      );

      if (selectedRadius !== null) {
        radiusUsed = selectedRadius;
        // Merge area-matched providers that aren't already in the radius results
        const existingIds = new Set(available.map((p: any) => p.id));
        for (const p of areaMatched) {
          if (!existingIds.has(p.id)) available.push(p);
        }
      } else {
        // No GPS results — fall back to area-name match, then city, then all
        if (areaMatched.length > 0) {
          radiusUsed = 'area_name';
          available = areaMatched;
          nearbyCount = areaMatched.length;
        } else {
          radiusUsed = 'city';
          const city = resolveCity(area);
          if (city) {
            const inCity = providersWithDistance.filter((p: any) => resolveCity(p.area) === city);
            available = inCity.filter(isAvailable);
            nearbyCount = inCity.length;
          } else {
            available = providersWithDistance.filter(isAvailable);
            nearbyCount = providersWithDistance.length;
          }
        }
      }
    } else {
      // Current area-name matching fallback
      const nearby = byService.filter((p: any) => areasMatch(p.area, area));
      const pool = nearby.length > 0 ? nearby : byService;

      available = pool.filter(isAvailable).map((p: any) => ({ ...p, distance_km: null }));
      nearbyCount = nearby.length;
      radiusUsed = null;
    }

    return {
      found: available.length,
      total_in_area: nearbyCount,
      radius_used: radiusUsed,
      providers: available.map((p: any) => ({
        id: p.id,
        name: p.name,
        photo_url: p.photo_url || null,
        area: p.area,
        service_types: p.service_types,
        rating: p.rating || 0,
        total_reviews: p.total_reviews || 0,
        review_sentiment: p.review_sentiment || 'unrated',
        experience_years: p.experience_years || 0,
        on_time_score: p.on_time_score || 100,
        cancellation_rate: p.cancellation_rate || 0,
        hourly_rate: p.hourly_rate || 500,
        rate_basic: p.rate_basic || p.hourly_rate || 500,
        rate_intermediate: p.rate_intermediate || (p.hourly_rate ? p.hourly_rate * 1.4 : 700),
        rate_complex: p.rate_complex || (p.hourly_rate ? p.hourly_rate * 2 : 1000),
        capacity_today: p.capacity_today || 0,
        blue_tick: p.blue_tick || false,
        risk_score: p.risk_score || 'low',
        strikes: p.strikes || 0,
        certifications: p.certifications || [],
        tools_available: p.tools_available || [],
        user_preference_score: p.user_preference_score || 0,
        availability: p.availability || {},
        same_area: p.area.toLowerCase().trim() === area.toLowerCase().trim(),
        distance_km: p.distance_km,
      })),
      context: { urgency, budget_sensitive, job_complexity, requested_area: area },
    };
  },
});

export const getProviderById = tool({
  name: 'get_provider_by_id',
  description: 'Get a single provider profile by their ID.',
  parameters: z.object({ provider_id: z.string() }),
  execute: async ({ provider_id }) => {
    const providers = readProviders();
    const p = providers.find((x: any) => x.id === provider_id);
    return p || null;
  },
});

export const updateProviderRating = tool({
  name: 'update_provider_rating',
  description: 'Update provider rating after a completed job. Recalculates running average.',
  parameters: z.object({
    provider_id: z.string(),
    new_stars: z.number().min(1).max(5),
    arrived_on_time: z.boolean(),
  }),
  execute: async ({ provider_id, new_stars, arrived_on_time }) => {
    const providers = readProviders();
    const idx = providers.findIndex((p: any) => p.id === provider_id);
    if (idx === -1) return { success: false, error: 'Provider not found' };

    const old = providers[idx];
    const oldTotal = old.total_reviews || 0;
    const newTotal = oldTotal + 1;
    const newRating = Number(((old.rating * oldTotal + new_stars) / newTotal).toFixed(2));

    let sentiment = 'unrated';
    if (newRating >= 4.5) sentiment = 'positive';
    else if (newRating >= 3.5) sentiment = 'mostly_positive';
    else if (newRating >= 2.5) sentiment = 'mixed';
    else sentiment = 'negative';

    providers[idx].rating = newRating;
    providers[idx].total_reviews = newTotal;
    providers[idx].review_sentiment = sentiment;
    if (!arrived_on_time) {
      providers[idx].on_time_score = Math.max(0, (providers[idx].on_time_score || 100) - 2);
    }

    writeProviders(providers);
    return { success: true, new_rating: newRating, total_reviews: newTotal, review_sentiment: sentiment };
  },
});

export const applyProviderPenalty = tool({
  name: 'apply_provider_penalty',
  description: 'Apply cancellation penalty to provider. Increases cancellation_rate and decreases on_time_score.',
  parameters: z.object({ provider_id: z.string() }),
  execute: async ({ provider_id }) => {
    const providers = readProviders();
    const idx = providers.findIndex((p: any) => p.id === provider_id);
    if (idx === -1) return { success: false };

    providers[idx].cancellation_rate = (providers[idx].cancellation_rate || 0) + 1;
    providers[idx].on_time_score = Math.max(0, (providers[idx].on_time_score || 100) - 10);
    writeProviders(providers);

    return {
      success: true,
      new_cancellation_rate: providers[idx].cancellation_rate,
      new_on_time_score: providers[idx].on_time_score,
    };
  },
});

export const applyProviderStrike = tool({
  name: 'apply_provider_strike',
  description: 'Add a dispute strike to a provider. 3 strikes causes blacklist with high risk_score.',
  parameters: z.object({ provider_id: z.string() }),
  execute: async ({ provider_id }) => {
    const providers = readProviders();
    const idx = providers.findIndex((p: any) => p.id === provider_id);
    if (idx === -1) return { success: false, strikes: 0, blacklisted: false };

    providers[idx].strikes = (providers[idx].strikes || 0) + 1;
    const strikes = providers[idx].strikes;
    const blacklisted = strikes >= 3;
    if (blacklisted) providers[idx].risk_score = 'high';

    writeProviders(providers);
    return { success: true, strikes, blacklisted, provider_name: providers[idx].name };
  },
});

export const registerNewProvider = tool({
  name: 'register_new_provider',
  description: 'Register a new service provider on the platform.',
  parameters: z.object({
    name: z.string(),
    service_types: z.array(z.string()),
    area: z.string(),
    hourly_rate: z.number(),
    rate_basic: z.number().nullable().optional(),
    rate_intermediate: z.number().nullable().optional(),
    rate_complex: z.number().nullable().optional(),
    experience_years: z.number(),
    nic: z.string().nullable(),
    availability: z.record(z.string(), z.array(z.string())).nullable(),
  }),
  execute: async ({ name, service_types, area, hourly_rate, rate_basic, rate_intermediate, rate_complex, experience_years, nic, availability }) => {
    const providers = readProviders();

    // Simple mock NADRA check
    let blue_tick = false;
    let nadra_status = 'no_nic';
    if (nic) {
      const clean = nic.replace(/[-\s]/g, '');
      if (clean.length !== 13 || !/^\d+$/.test(clean)) {
        nadra_status = 'format_invalid';
      } else {
        // Mock: NICs ending in odd digit = verified
        blue_tick = parseInt(clean[12]) % 2 !== 0;
        nadra_status = blue_tick ? 'mock_verified' : 'mock_rejected';
      }
    }

    const newProvider = {
      id: 'PRV-' + Math.random().toString(36).substring(2, 10).toUpperCase(),
      name, area, service_types, hourly_rate,
      rate_basic: rate_basic || hourly_rate,
      rate_intermediate: rate_intermediate || hourly_rate * 1.4,
      rate_complex: rate_complex || hourly_rate * 2.0,
      experience_years, blue_tick,
      rating: 0, total_reviews: 0, review_sentiment: 'unrated',
      on_time_score: 100, cancellation_rate: 0, capacity_today: 3,
      risk_score: 'low', strikes: 0, user_preference_score: 0,
      registered_at: new Date().toISOString(),
      availability: availability || {
        monday: ['09:00','11:00','14:00','16:00'],
        tuesday: ['09:00','11:00','14:00','16:00'],
        wednesday: ['09:00','11:00','14:00','16:00'],
        thursday: ['09:00','11:00','14:00','16:00'],
        friday: ['09:00','11:00','14:00'],
        saturday: ['10:00','12:00'],
        sunday: [],
      },
    };

    providers.push(newProvider);
    writeProviders(providers);

    return { status: 'success', provider: newProvider, nadra_status };
  },
});
