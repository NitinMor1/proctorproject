const express = require('express');
const router = express.Router();
const Session = require('../models/Session');
const Violation = require('../models/Violation');

// Create a new exam session
router.post('/start', async (req, res) => {
  try {
    const { student, examId } = req.body;

    // Prevent duplicate active sessions for same student+exam
    const existing = await Session.findOne({ student, examId, status: 'active' });
    if (existing) return res.json(existing); // Return existing active session

    const session = new Session({ student, examId, status: 'active' });
    await session.save();
    res.json(session);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Update integrity score (called periodically from frontend)
router.patch('/:id/score', async (req, res) => {
  try {
    const { score, event } = req.body;
    const session = await Session.findById(req.params.id);
    if (!session) return res.status(404).json({ message: 'Session not found' });

    session.integrityScore = Math.max(0, Math.min(100, score));
    if (event) session.logs.push({ event });
    await session.save();
    res.json(session);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// End session with final cascade calculations
router.patch('/:id/end', async (req, res) => {
  try {
    const session = await Session.findById(req.params.id);
    if (!session) return res.status(404).json({ message: 'Session not found' });

    // Count total violations from DB for accuracy
    const totalViolations = await Violation.countDocuments({ session: session._id });
    session.totalViolations = totalViolations;
    session.endTime = new Date();
    session.status = session.integrityScore < 50 ? 'flagged' : 'completed';
    await session.save();
    res.json(session);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get session by ID (for admin report)
router.get('/:id', async (req, res) => {
  try {
    const session = await Session.findById(req.params.id)
      .populate('student', 'name email')
      .populate('examId', 'title durationMinutes');
    if (!session) return res.status(404).json({ message: 'Session not found' });
    res.json(session);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
