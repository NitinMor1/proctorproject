const express = require('express');
const router = express.Router();
const Submission = require('../models/Submission');
const Exam = require('../models/Exam');

// Submit Exam (Student)
router.post('/', async (req, res) => {
  try {
    const { student, exam, session, answers, studentFaceImage } = req.body;

    // Check if already submitted
    const existing = await Submission.findOne({ student, exam });
    if (existing) return res.status(400).json({ message: 'Exam already submitted' });

    // Fetch the exam to calculate the score securely on the backend
    const examDoc = await Exam.findById(exam);
    if (!examDoc) return res.status(404).json({ message: 'Exam not found' });

    let score = 0;
    const maxScore = examDoc.questions.length;

    // Iterate through submitted answers and compare to true correct answers in DB
    answers.forEach(submittedAnswer => {
      const q = examDoc.questions.id(submittedAnswer.questionId);
      if (q && q.correctAnswerIndex === submittedAnswer.selectedOptionIndex) {
        score++;
      }
    });

    const newSubmission = new Submission({
      student,
      exam,
      session,
      answers,
      score,
      maxScore,
      studentFaceImage, // Base64 face image from identity verification
    });

    await newSubmission.save();
    res.status(201).json(newSubmission);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Admin: Get all submissions for a specific exam (populated with student names)
router.get('/exam/:examId', async (req, res) => {
  try {
    const submissions = await Submission.find({ exam: req.params.examId })
      .populate('student', 'name email')
      .populate('session')
      .sort({ submittedAt: -1 });
    
    res.json(submissions);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
