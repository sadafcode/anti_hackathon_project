import { Router } from 'express';
import { NLUAgent } from '../agents/nlu.agent';
import { IntentAgent } from '../agents/intent.agent';
import { DiscoveryAgent } from '../agents/discovery.agent';
import { PricingAgent } from '../agents/pricing.agent';
import { BookingAgent } from '../agents/booking.agent';
import { FeedbackAgent } from '../agents/feedback.agent';
import { DisputeAgent } from '../agents/dispute.agent';

const router = Router();

const nluAgent = new NLUAgent();
const intentAgent = new IntentAgent();
const discoveryAgent = new DiscoveryAgent();
const pricingAgent = new PricingAgent();
const bookingAgent = new BookingAgent();
const feedbackAgent = new FeedbackAgent();
const disputeAgent = new DisputeAgent();

// 1. Chat (NLU + Intent)
router.post('/chat', async (req, res) => {
  try {
    const { message, session_id } = req.body;
    if (!message || !session_id) {
       return res.status(400).json({ error: 'message and session_id are required' });
    }

    const nluResult = await nluAgent.parse({ message });
    const intentResult = intentAgent.process({ nlu_result: nluResult, session_id });

    res.json({ nlu: nluResult, intent: intentResult });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// 2. Discovery
router.post('/discovery', (req, res) => {
  try {
    const { intent } = req.body;
    if (!intent) {
        return res.status(400).json({ error: 'intent is required' });
    }
    const discoveryResult = discoveryAgent.discover(intent);
    res.json(discoveryResult);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// 3. Pricing
router.post('/pricing', (req, res) => {
  try {
    const { provider, intent, is_returning_user } = req.body;
    const pricingResult = pricingAgent.calculatePrice({ provider, intent, is_returning_user });
    res.json(pricingResult);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// 4. Booking
router.post('/booking', async (req, res) => {
  try {
    const request = req.body; // BookingRequest
    const bookingResult = await bookingAgent.bookService(request);
    res.json(bookingResult);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// 5. Feedback
router.post('/feedback', async (req, res) => {
  try {
    const request = req.body; // FeedbackInput
    const feedbackResult = await feedbackAgent.processFeedback(request);
    res.json(feedbackResult);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// 6. Dispute
router.post('/dispute', (req, res) => {
  try {
    const request = req.body; // DisputeInput
    const disputeResult = disputeAgent.resolveDispute(request);
    res.json(disputeResult);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// 7. Register Provider
router.post('/provider/register', async (req, res) => {
  try {
    const data = req.body;
    const result = await discoveryAgent.registerProvider(data);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// 8. Pending Bookings for Provider
router.get('/provider/:id/pending-bookings', (req, res) => {
  try {
    const providerId = req.params.id;
    const pendingBookings = bookingAgent.getPendingBookings(providerId);
    res.json(pendingBookings);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// 9. Provider Respond to Booking
router.post('/booking/respond', async (req, res) => {
  try {
    const { booking_id, provider_id, action, reason } = req.body;
    const result = await bookingAgent.respondToBooking(booking_id, provider_id, action, reason);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// 10. Cancel after accept
router.post('/booking/cancel-after-accept', async (req, res) => {
  try {
    const { booking_id } = req.body;
    const result = await bookingAgent.simulateProviderCancellation(booking_id);
    if (!result) {
      return res.status(404).json({ error: 'Booking not found or already cancelled' });
    }
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
