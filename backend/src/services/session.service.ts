import { MemorySession } from '@openai/agents';

// Manages per-session conversation memory.
// Sessions persist as long as the server runs — cleared only on restart or explicit call.
class SessionService {
  private sessions = new Map<string, MemorySession>();

  getOrCreate(sessionId: string): MemorySession {
    if (!this.sessions.has(sessionId)) {
      this.sessions.set(sessionId, new MemorySession());
    }
    return this.sessions.get(sessionId)!;
  }

  clear(sessionId: string): void {
    this.sessions.delete(sessionId);
  }

  clearAll(): void {
    this.sessions.clear();
  }

  count(): number {
    return this.sessions.size;
  }
}

export const sessionService = new SessionService();
