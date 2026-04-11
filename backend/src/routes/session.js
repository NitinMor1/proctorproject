const express = require('express');
const router = express.Router();
const Session = require('../models/Session');

// Create a new exam session
router.post('/start', async (req, res) => {
  try {
    const { student, examId } = req.body;
    const session = new Session({
      student,
      examId,
      status: 'active'
    });
    await session.save();
    res.json(session);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Update integrity score
router.patch('/:id/score', async (req, res) => {
  try {
    const { score, event } = req.body;
    const session = await Session.findById(req.params.id);
    if (!session) return res.status(404).json({ message: 'Session not found' });

    session.integrityScore = score;
    if (event) {
        session.logs.push({ event });
    }
    await session.save();
    res.json(session);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// End session
router.patch('/:id/end', async (req, res) => {
    try {
      const session = await Session.findById(req.params.id);
      if (!session) return res.status(404).json({ message: 'Session not found' });
  
      session.status = session.integrityScore < 50 ? 'flagged' : 'completed';
      session.endTime = Date.now();
      await session.save();
      res.json(session);
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

module.exports = router;
