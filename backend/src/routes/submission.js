const express = require('express');
const router = express.Router();
const Submission = require('../models/Submission');
const Exam = require('../models/Exam');
const Violation = require('../models/Violation');
const Session = require('../models/Session');

// Check if already submitted
router.get('/check', async (req, res) => {
  try {
    const { student, exam } = req.query;
    if (!student || !exam) return res.status(400).json({ message: 'Missing student or exam ID' });
    const existing = await Submission.findOne({ student, exam });
    res.json({ submitted: !!existing });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Submit Exam (Student)
router.post('/', async (req, res) => {
  try {
    const { student, exam, session, answers, studentFaceImage } = req.body;

    const existing = await Submission.findOne({ student, exam });
    if (existing) return res.status(400).json({ message: 'Exam already submitted' });

    const examDoc = await Exam.findById(exam);
    if (!examDoc) return res.status(404).json({ message: 'Exam not found' });

    let score = 0;
    const maxScore = examDoc.questions.length;

    answers.forEach(submittedAnswer => {
      const q = examDoc.questions.id(submittedAnswer.questionId);
      if (q && q.correctAnswerIndex === submittedAnswer.selectedOptionIndex) {
        score++;
      }
    });

    const newSubmission = new Submission({
      student, exam, session, answers, score, maxScore, studentFaceImage,
    });

    await newSubmission.save();
    res.status(201).json(newSubmission);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Admin: Get all submissions for a specific exam
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

// Admin: Full report for a single submission (violation timeline + answer eval)
router.get('/:id/report', async (req, res) => {
  try {
    const submission = await Submission.findById(req.params.id)
      .populate('student', 'name email')
      .populate('exam');

    if (!submission) return res.status(404).json({ message: 'Submission not found' });

    // Get the proctoring session
    const session = submission.session
      ? await Session.findById(submission.session)
      : null;

    // Get all violations for this session
    const violations = session
      ? await Violation.find({ session: session._id }).sort({ timestamp: 1 })
      : [];

    // Evaluate each answer against correct answers
    const exam = submission.exam;
    const evaluatedAnswers = exam.questions.map((q, index) => {
      const studentAnswer = submission.answers.find(
        a => a.questionId.toString() === q._id.toString()
      );
      const selectedIndex = studentAnswer ? studentAnswer.selectedOptionIndex : -1;
      return {
        questionIndex: index,
        questionText: q.questionText,
        options: q.options,
        correctAnswerIndex: q.correctAnswerIndex,
        studentAnswerIndex: selectedIndex,
        isCorrect: selectedIndex === q.correctAnswerIndex,
      };
    });

    res.json({
      submission: {
        _id: submission._id,
        score: submission.score,
        maxScore: submission.maxScore,
        submittedAt: submission.submittedAt,
        studentFaceImage: submission.studentFaceImage,
      },
      student: submission.student,
      exam: {
        _id: exam._id,
        title: exam.title,
        durationMinutes: exam.durationMinutes,
      },
      session: session ? {
        _id: session._id,
        integrityScore: session.integrityScore,
        totalViolations: session.totalViolations,
        violationCounts: session.violationCounts,
        startTime: session.startTime,
        endTime: session.endTime,
        status: session.status,
      } : null,
      violations: violations.map(v => ({
        type: v.type,
        severity: v.severity,
        timestamp: v.timestamp,
        comment: v.comment,
      })),
      evaluatedAnswers,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
