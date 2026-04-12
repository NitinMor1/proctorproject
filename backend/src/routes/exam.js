const express = require('express');
const router = express.Router();
const Exam = require('../models/Exam');

// Create Exam (Admin)
router.post('/', async (req, res) => {
  try {
    const { title, description, durationMinutes, createdBy, questions } = req.body;
    
    // Simple validation (In a production app, verify if 'createdBy' is actually an Admin based on JWT)
    if (!title || !durationMinutes || !questions || questions.length === 0) {
      return res.status(400).json({ message: 'Title, duration and at least one question are required' });
    }

    // Generate a random 6-character alphanumeric code
    const examCode = Math.random().toString(36).substring(2, 8).toUpperCase();

    const newExam = new Exam({
      title,
      description,
      durationMinutes,
      examCode,
      createdBy,
      questions
    });

    await newExam.save();
    res.status(201).json(newExam);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get all Exams (Admin Dashboard lists them)
router.get('/', async (req, res) => {
  try {
    const exams = await Exam.find().sort({ createdAt: -1 });
    res.json(exams);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get specific Exam by Code (Student enters code to take exam)
router.get('/code/:code', async (req, res) => {
  try {
    const exam = await Exam.findOne({ examCode: req.params.code.toUpperCase() });
    if (!exam) return res.status(404).json({ message: 'Exam not found with that code' });
    res.json(exam);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get specific Exam by ID
router.get('/:id', async (req, res) => {
  try {
    const exam = await Exam.findById(req.params.id);
    if (!exam) return res.status(404).json({ message: 'Exam not found' });
    
    // To prevent cheating, you could filter out the `correctAnswerIndex` here for students
    // but for simplicity right now we'll serve the full object.
    res.json(exam);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Update (Edit) an existing Exam (Admin)
router.put('/:id', async (req, res) => {
  try {
    const { title, description, durationMinutes, questions } = req.body;
    
    // Find and update
    const updatedExam = await Exam.findByIdAndUpdate(
      req.params.id,
      { title, description, durationMinutes, questions },
      { new: true, runValidators: true }
    );
    
    if (!updatedExam) return res.status(404).json({ message: 'Exam not found' });
    
    res.json(updatedExam);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
