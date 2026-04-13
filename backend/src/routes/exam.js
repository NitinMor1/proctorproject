const express = require('express');
const router = express.Router();
const Exam = require('../models/Exam');

// Create Exam (Admin)
router.post('/', async (req, res) => {
  try {
    const { title, description, durationMinutes, createdBy, questions, proctoringRules } = req.body;

    if (!title || !durationMinutes || !questions || questions.length === 0) {
      return res.status(400).json({ message: 'Title, duration and at least one question are required' });
    }

    const examCode = Math.random().toString(36).substring(2, 8).toUpperCase();

    const newExam = new Exam({
      title,
      description,
      durationMinutes,
      examCode,
      createdBy,
      questions,
      proctoringRules: proctoringRules || {},
      status: 'published',
    });

    await newExam.save();
    res.status(201).json(newExam);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get all Exams
router.get('/', async (req, res) => {
  try {
    const exams = await Exam.find().sort({ createdAt: -1 });
    res.json(exams);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get Exam by Code (Student)
router.get('/code/:code', async (req, res) => {
  try {
    const exam = await Exam.findOne({ examCode: req.params.code.toUpperCase(), status: 'published' });
    if (!exam) return res.status(404).json({ message: 'Exam not found or not published' });
    // Return exam WITHOUT correct answers for students
    const safeExam = exam.toObject();
    safeExam.questions = safeExam.questions.map(q => {
      const { correctAnswerIndex, ...rest } = q;
      return rest;
    });
    res.json(safeExam);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get Exam by ID (Admin - includes correct answers)
router.get('/:id', async (req, res) => {
  try {
    const exam = await Exam.findById(req.params.id);
    if (!exam) return res.status(404).json({ message: 'Exam not found' });
    res.json(exam);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Update Exam (Admin)
router.put('/:id', async (req, res) => {
  try {
    const { title, description, durationMinutes, questions, proctoringRules } = req.body;
    const updatedExam = await Exam.findByIdAndUpdate(
      req.params.id,
      { title, description, durationMinutes, questions, proctoringRules },
      { new: true, runValidators: true }
    );
    if (!updatedExam) return res.status(404).json({ message: 'Exam not found' });
    res.json(updatedExam);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Toggle Publish / Draft (Admin)
router.patch('/:id/status', async (req, res) => {
  try {
    const { status } = req.body; // 'published' or 'draft'
    if (!['published', 'draft'].includes(status)) {
      return res.status(400).json({ message: 'Status must be published or draft' });
    }
    const exam = await Exam.findByIdAndUpdate(req.params.id, { status }, { new: true });
    if (!exam) return res.status(404).json({ message: 'Exam not found' });
    res.json(exam);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Delete Exam (Admin)
router.delete('/:id', async (req, res) => {
  try {
    const exam = await Exam.findByIdAndDelete(req.params.id);
    if (!exam) return res.status(404).json({ message: 'Exam not found' });
    res.json({ message: 'Exam deleted successfully' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
