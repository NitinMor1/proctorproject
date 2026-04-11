const express = require('express');
const router = express.Router();
const Violation = require('../models/Violation');
const Session = require('../models/Session');

// Log a violation
router.post('/', async (req, res) => {
  try {
    const { session: sessionId, student, type, severity, comment, screenshotUrl } = req.body;
    
    // Create violation
    const violation = new Violation({
      session: sessionId,
      student,
      type,
      severity,
      comment,
      screenshotUrl
    });
    await violation.save();

    // Update session stats
    const session = await Session.findById(sessionId);
    if (session) {
        session.totalViolations += 1;
        // Basic heuristic for score reduction
        const reduction = severity === 'high' ? 10 : (severity === 'medium' ? 5 : 2);
        session.integrityScore = Math.max(0, session.integrityScore - reduction);
        session.logs.push({ event: `Violation: ${type} (${severity})` });
        await session.save();
    }

    res.json({ violation, updatedScore: session.integrityScore });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get violations for a session
router.get('/session/:sessionId', async (req, res) => {
  try {
    const violations = await Violation.find({ session: req.params.sessionId }).sort({ timestamp: 1 });
    res.json(violations);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
